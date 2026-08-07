#!/usr/bin/env python3
"""Scan local video_jobs/inbox for Moyin jobs and run local workers.

This watcher does not call back n8n, does not write GitHub, and does not persist
API keys. It exits after being idle for the configured timeout.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

ALLOWED_SEGMENT_CHARS = set("abcdefghijklmnopqrstuvwxyz0123456789_-")
CLAIM_LOCK_STALE_SECONDS = 600


def log(message: str) -> None:
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}", flush=True)


def slug_segment(value: str, field: str) -> str:
    text = str(value or "").strip().lower()
    if not text or any(ch not in ALLOWED_SEGMENT_CHARS for ch in text):
        raise ValueError(f"Invalid {field}: {value!r}; only a-z, 0-9, _, - are allowed")
    if ".." in text or "/" in text or "\\" in text:
        raise ValueError(f"Invalid {field}: path traversal is not allowed")
    return text


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError(f"Job file must contain a JSON object: {path}")
    return payload


def atomic_lock(lock_path: Path) -> int | None:
    fd: int | None = None
    try:
        fd = os.open(str(lock_path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        return None

    try:
        os.write(fd, f"pid={os.getpid()}\ncreated_at={int(time.time())}\n".encode("utf-8"))
        os.fsync(fd)
        log(f"lock created: {lock_path}")
        return fd
    except Exception:
        if fd is not None:
            try:
                os.close(fd)
            except OSError:
                pass
        try:
            lock_path.unlink()
            log(f"lock released after creation failure: {lock_path}")
        except FileNotFoundError:
            pass
        raise


def release_lock(fd: int | None, lock_path: Path) -> None:
    if fd is not None:
        try:
            os.close(fd)
        except OSError:
            pass
    try:
        lock_path.unlink()
        log(f"lock released: {lock_path}")
    except FileNotFoundError:
        pass
    except PermissionError as error:
        log(f"lock release deferred by Windows file sharing: {lock_path}: {error}")


def read_lock_pid(lock_path: Path) -> int | None:
    try:
        for line in lock_path.read_text(encoding="utf-8-sig").splitlines():
            if line.startswith("pid="):
                return int(line.split("=", 1)[1].strip())
    except (OSError, ValueError):
        return None
    return None


def process_is_running(pid: int | None) -> bool:
    if not pid or pid <= 0:
        return False
    if pid == os.getpid():
        return True

    if os.name == "nt":
        try:
            result = subprocess.run(
                ["tasklist", "/FI", f"PID eq {pid}", "/FO", "CSV", "/NH"],
                capture_output=True,
                text=True,
                check=False,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
            return f'"{pid}"' in result.stdout
        except OSError:
            return True

    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def remove_stale_claim_locks(inbox_dir: Path, stale_seconds: int = CLAIM_LOCK_STALE_SECONDS) -> None:
    now = time.time()
    for lock_path in inbox_dir.glob("*.claim.lock"):
        try:
            age = now - lock_path.stat().st_mtime
        except FileNotFoundError:
            continue
        if age < stale_seconds:
            continue

        pid = read_lock_pid(lock_path)
        if process_is_running(pid):
            log(f"stale-age claim lock retained because pid is running: {lock_path} pid={pid}")
            continue

        try:
            lock_path.unlink()
            log(f"stale claim lock deleted: {lock_path} age_seconds={int(age)} pid={pid}")
        except FileNotFoundError:
            pass
        except PermissionError as error:
            log(f"stale claim lock could not be deleted yet: {lock_path}: {error}")


def same_root(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def prepare_job(inbox_file: Path, jobs_dir: Path, output_root: Path) -> tuple[Path, Path, Path] | None:
    lock_path = inbox_file.with_suffix(inbox_file.suffix + ".claim.lock")
    fd = atomic_lock(lock_path)
    if fd is None:
        return None

    try:
        job = load_json(inbox_file)
        job_id = slug_segment(job.get("job_id", inbox_file.stem), "job_id")
        product_id = slug_segment(job.get("product_id", "product"), "product_id")

        job_dir = jobs_dir / job_id
        output_dir = output_root / product_id / job_id
        job_json = job_dir / "job.json"
        running_lock = job_dir / ".running.lock"
        worker_log = job_dir / "worker.log"

        if (job_dir / "done.json").exists() or (job_dir / "failed.json").exists() or running_lock.exists():
            log(f"job already completed or running; claim skipped: {job_id}")
            return None

        if not same_root(job_dir, jobs_dir):
            raise ValueError(f"Resolved job_dir escapes jobs_dir: {job_dir}")
        if not same_root(output_dir, output_root):
            raise ValueError(f"Resolved output_dir escapes output root: {output_dir}")

        job_dir.mkdir(parents=True, exist_ok=True)
        output_dir.mkdir(parents=True, exist_ok=True)

        job["status_dir"] = str(job_dir).replace("\\", "/")
        job["output_dir"] = str(output_dir).replace("\\", "/")
        for scene in job.get("scenes", []):
            scene_id = slug_segment(scene.get("scene_id", "scene"), "scene_id")
            scene["scene_id"] = scene_id
            scene["output_file"] = str(output_dir / f"{scene_id}.mp4").replace("\\", "/")

        tmp_job = job_dir / "job.json.tmp"
        with tmp_job.open("w", encoding="utf-8", newline="\n") as handle:
            json.dump(job, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        os.replace(tmp_job, job_json)

        try:
            inbox_file.unlink()
        except FileNotFoundError:
            pass

        return job_json, running_lock, worker_log
    finally:
        release_lock(fd, lock_path)


def reap_finished(processes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    alive: list[dict[str, Any]] = []
    for entry in processes:
        process = entry["process"]
        if process.poll() is None:
            alive.append(entry)
            continue

        log_handle = entry.get("log_handle")
        if log_handle:
            try:
                log_handle.close()
            except OSError:
                pass

        running_lock = entry.get("running_lock")
        if running_lock:
            release_lock(None, running_lock)

        log(f"worker exited: job={entry.get('job_json')} code={process.returncode}")
    return alive


def main() -> int:
    parser = argparse.ArgumentParser(description="Watch Moyin job inbox and run local workers.")
    parser.add_argument("--jobs-dir", default="E:/n8n-video-gemini/video_jobs")
    parser.add_argument("--worker", default="E:/n8n-video-gemini/workers/moyin_worker.py")
    parser.add_argument("--max-parallel", type=int, default=2)
    parser.add_argument("--scan-interval-seconds", type=int, default=5)
    parser.add_argument("--idle-timeout-seconds", type=int, default=1800)
    args = parser.parse_args()

    jobs_dir = Path(args.jobs_dir or os.environ.get("N8N_LOCAL_JOBS_DIR", "E:/n8n-video-gemini/video_jobs"))
    inbox_dir = jobs_dir / "inbox"
    output_root = Path(os.environ.get("N8N_LOCAL_OUTPUT_DIR", "E:/n8n-video-gemini/video_output"))
    worker = Path(args.worker or "E:/n8n-video-gemini/workers/moyin_worker.py")

    jobs_dir.mkdir(parents=True, exist_ok=True)
    inbox_dir.mkdir(parents=True, exist_ok=True)
    output_root.mkdir(parents=True, exist_ok=True)

    if not worker.exists():
        raise FileNotFoundError(f"Worker not found: {worker}")

    active: list[dict[str, Any]] = []
    last_activity = time.time()

    while True:
        remove_stale_claim_locks(inbox_dir)
        active = reap_finished(active)
        started = 0

        for inbox_file in sorted(inbox_dir.glob("*.json")):
            if len(active) >= max(1, args.max_parallel):
                break
            try:
                prepared = prepare_job(inbox_file, jobs_dir, output_root)
                if not prepared:
                    continue
                job_json, running_lock, worker_log = prepared

                running_fd = atomic_lock(running_lock)
                if running_fd is None:
                    continue
                os.close(running_fd)

                command = [sys.executable, str(worker), "--job", str(job_json)]
                log_handle = worker_log.open("a", encoding="utf-8", newline="\n")
                try:
                    process = subprocess.Popen(command, stdout=log_handle, stderr=subprocess.STDOUT)
                except Exception:
                    log_handle.close()
                    release_lock(None, running_lock)
                    raise

                active.append({
                    "process": process,
                    "log_handle": log_handle,
                    "running_lock": running_lock,
                    "job_json": job_json,
                })
                started += 1
                last_activity = time.time()
                log(f"started worker: pid={process.pid} job={job_json} log={worker_log}")
            except Exception as error:  # noqa: BLE001 - watcher must keep scanning other jobs.
                print(f"failed to claim {inbox_file}: {error}", file=sys.stderr, flush=True)

        if started:
            continue

        if not active and (time.time() - last_activity) >= max(1, args.idle_timeout_seconds):
            log("idle timeout reached; worker_watcher exiting")
            return 0

        time.sleep(max(1, args.scan_interval_seconds))


if __name__ == "__main__":
    raise SystemExit(main())