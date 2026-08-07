#!/usr/bin/env python3
"""Poll Moyin video tasks from a local job.json and save completed videos.

This worker is intentionally local-only:
- no n8n callback
- no GitHub writes
- no API key persisted to disk
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import socket
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


DYNAMIC_SEGMENT_RE = re.compile(r"[^a-z0-9_-]+")
DYNAMIC_SEGMENT_ALLOWED = re.compile(r"^[a-z0-9_-]+$")
MP4_FILE_ALLOWED = re.compile(r"^[a-z0-9_-]+\.mp4$")
DEFAULT_FAILED_STATUSES = {"failed", "error", "cancelled", "canceled"}
DEFAULT_SUCCESS_STATUSES = {"completed", "succeeded", "success", "done", "finished"}


def sanitize_assembly_plan(job: dict[str, Any], output_dir: Path) -> dict[str, Any] | None:
    """Allow only the fixed silent A/B 20-second assembly contract."""
    raw = job.get("assembly_plan")
    if not raw:
        return None
    if not isinstance(raw, dict):
        raise ValueError("assembly_plan must be an object")
    if raw.get("input_order") != ["video_A", "video_B", "video_A"]:
        raise ValueError("assembly_plan input_order must be [video_A, video_B, video_A]")
    if raw.get("source_ranges") != ["0-5", "0-10", "5-10"]:
        raise ValueError("assembly_plan source_ranges must be [0-5, 0-10, 5-10]")
    if int(raw.get("output_duration_seconds") or 0) != 20:
        raise ValueError("assembly_plan output_duration_seconds must be 20")
    if raw.get("video_only") is not False or raw.get("preserve_source_audio") is not True or raw.get("ffmpeg_required_after_download") is not True:
        raise ValueError("assembly_plan must preserve source audio and require FFmpeg")
    if raw.get("output_file_name") != "final_20s.mp4":
        raise ValueError("assembly_plan output_file_name must be final_20s.mp4")
    return {
        "output_file": str(output_dir / "final_20s.mp4"),
        "output_duration_seconds": 20,
    }


def assemble_silent_ab20(job: dict[str, Any], scenes_state: dict[str, dict[str, Any]]) -> dict[str, Any] | None:
    """Re-encode and concatenate A[0-5] + B[0-10] + A[5-10] with source ambience."""
    plan = job.get("assembly_plan")
    if not plan:
        return None
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("FFmpeg is required for silent A/B 20-second assembly but was not found in PATH")
    ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        raise RuntimeError("FFprobe is required to verify source audio but was not found in PATH")
    video_a = Path(scenes_state["video_a"]["output_file"])
    video_b = Path(scenes_state["video_b"]["output_file"])
    output_file = Path(plan["output_file"])
    if not video_a.is_file() or not video_b.is_file():
        raise RuntimeError("silent A/B assembly requires downloaded video_a.mp4 and video_b.mp4")
    for source in (video_a, video_b):
        probe = subprocess.run(
            [ffprobe, "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=codec_type", "-of", "csv=p=0", str(source)],
            capture_output=True,
            text=True,
            check=False,
        )
        if probe.returncode != 0 or "audio" not in probe.stdout.lower():
            raise RuntimeError(f"{source.name} has no audio stream; refusing to create a silent final_20s.mp4")
    filter_graph = (
        "[0:v]trim=start=0:end=5,setpts=PTS-STARTPTS[v0];"
        "[1:v]trim=start=0:end=10,setpts=PTS-STARTPTS[v1];"
        "[0:v]trim=start=5:end=10,setpts=PTS-STARTPTS[v2];"
        "[0:a]atrim=start=0:end=5,asetpts=PTS-STARTPTS,aresample=48000,aformat=channel_layouts=stereo[a0];"
        "[1:a]atrim=start=0:end=10,asetpts=PTS-STARTPTS,aresample=48000,aformat=channel_layouts=stereo[a1];"
        "[0:a]atrim=start=5:end=10,asetpts=PTS-STARTPTS,aresample=48000,aformat=channel_layouts=stereo[a2];"
        "[v0][a0][v1][a1][v2][a2]concat=n=3:v=1:a=1[concat_v][a];"
        "[concat_v]format=yuv420p[v]"
    )
    command = [
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(video_a), "-i", str(video_b),
        "-filter_complex", filter_graph,
        "-map", "[v]", "-map", "[a]", "-c:a", "aac", "-b:a", "128k", "-r", "30",
        "-movflags", "+faststart", str(output_file),
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0 or not output_file.is_file() or output_file.stat().st_size == 0:
        message = (result.stderr or result.stdout or "unknown FFmpeg error").strip()
        raise RuntimeError(f"FFmpeg silent A/B assembly failed: {message[-2000:]}")
    return {
        "status": "completed",
        "output_file": str(output_file),
        "duration_seconds": 20,
        "source_audio_preserved": True,
    }


def slugify(value: Any, fallback: str = "item") -> str:
    text = str(value or fallback).strip().lower()
    text = DYNAMIC_SEGMENT_RE.sub("-", text)
    text = text.strip(".-_")
    return text[:120] or fallback


def reject_unsafe_path(path_value: Any, label: str, required_root: str | None = None, kind: str = "dir") -> Path:
    raw = str(path_value or "")
    if not raw:
        raise ValueError(f"{label} is required")
    if "\x00" in raw or any(ch in raw for ch in [";", "|", "&", "`", "$", "<", ">"]):
        raise ValueError(f"{label} contains unsafe shell characters")

    path = Path(raw)
    parts = path.parts
    if ".." in parts:
        raise ValueError(f"{label} must not contain '..'")
    if required_root:
        root = Path(required_root).resolve()
        resolved = path.resolve()
        try:
            relative = resolved.relative_to(root)
        except ValueError as error:
            raise ValueError(f"{label} must be under {required_root}") from error
        rel_parts = relative.parts
        if not rel_parts:
            raise ValueError(f"{label} must include a slugified child path under {required_root}")
        if kind == "dir":
            check_parts = rel_parts
            file_part = None
        elif kind == "mp4":
            check_parts = rel_parts[:-1]
            file_part = rel_parts[-1]
            if not MP4_FILE_ALLOWED.match(file_part):
                raise ValueError(f"{label} file name must look like slug.mp4")
        elif kind == "job_json":
            check_parts = rel_parts[:-1]
            file_part = rel_parts[-1]
            if file_part != "job.json":
                raise ValueError(f"{label} file name must be job.json")
        else:
            raise ValueError(f"unsupported path validation kind: {kind}")
        for part in check_parts:
            if not DYNAMIC_SEGMENT_ALLOWED.match(part):
                raise ValueError(f"{label} contains non-slug path segment: {part}")
    return path


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    tmp_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp_path.replace(path)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def moyin_base_url(job: dict[str, Any] | None = None) -> str:
    configured = ((job or {}).get("moyin_api") or {}).get("base_url")
    if configured:
        return str(configured).strip().rstrip("/")
    base = os.environ.get("MOYIN_API_BASE_URL", "").strip()
    if not base:
        base = "https://<MOYIN_API_BASE_URL>"
    return base.rstrip("/")


def moyin_query_path(job: dict[str, Any], task_id: str) -> str:
    job_api = job.get("moyin_api") or {}
    template = str(job_api.get("query_path_template") or "").strip()
    if not template:
        template = os.environ.get("MOYIN_QUERY_PATH_TEMPLATE", "").strip()
    if not template:
        template = "/videos/{task_id}"
    path = template.replace("{task_id}", task_id)
    if not path.startswith("/"):
        path = "/" + path
    return path

def request_json(url: str, api_key: str, timeout: int = 60) -> dict[str, Any]:
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {api_key}", "Accept": "application/json", "User-Agent": "n8n-video-worker/1.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return json.loads(response.read().decode(charset))


def resolve_download_url(video_url: str, base_url: str) -> tuple[str, bool]:
    """Return a download URL and whether it is an API endpoint that needs auth.

    Legacy Moyin responses use externally hosted signed URLs, which must not receive
    the API bearer token. AIHUB may instead return a relative /v1/videos/{id}/content
    path, which has to be resolved against the API host and does require the token.
    """
    raw_url = str(video_url or "").strip()
    if not raw_url:
        raise ValueError("video_url is empty")

    parsed = urllib.parse.urlparse(raw_url)
    if parsed.scheme in {"http", "https"}:
        base = urllib.parse.urlparse(base_url)
        is_api_content_url = (
            parsed.netloc.lower() == base.netloc.lower()
            and parsed.path.startswith("/v1/videos/")
            and parsed.path.endswith("/content")
        )
        return raw_url, is_api_content_url
    if parsed.scheme or parsed.netloc:
        raise ValueError(f"unsupported video_url: {raw_url}")

    base = urllib.parse.urlparse(base_url)
    if not base.scheme or not base.netloc:
        raise ValueError(f"invalid Moyin API base_url: {base_url}")
    return urllib.parse.urljoin(f"{base.scheme}://{base.netloc}/", raw_url), True


def build_download_candidates(
    payload: dict[str, Any],
    video_url_paths: list[str],
    base_url: str,
    task_id: str,
) -> list[tuple[str, bool, str]]:
    """Build safe download fallbacks, preferring the original API task ID.

    AIHUB completion responses can expose an internal video ID in ``video_url``
    and an upstream task ID in ``data[0].url``. Neither is downloadable through
    the customer's API key. The create-task ID remains valid at the API content
    endpoint, so construct that URL locally before considering response URLs.
    """
    base = urllib.parse.urlparse(base_url)
    if not base.scheme or not base.netloc:
        raise ValueError(f"invalid Moyin API base_url: {base_url}")

    base_path = base.path.rstrip("/")
    encoded_task_id = urllib.parse.quote(str(task_id), safe="")
    api_content_path = f"{base_path}/videos/{encoded_task_id}/content"
    api_content_url = urllib.parse.urlunparse((base.scheme, base.netloc, api_content_path, "", "", ""))
    candidates = [(api_content_url, True, "api_task_content")]

    response_url = extract_video_url(payload, video_url_paths)
    if response_url:
        resolved_url, requires_api_auth = resolve_download_url(response_url, base_url)
        if resolved_url != api_content_url:
            candidates.append((resolved_url, requires_api_auth, "response_video_url"))
    return candidates


def download_file(url: str, output_file: Path, api_key: str | None = None, timeout: int = 300) -> None:
    # External temporary signed URLs must not receive the API bearer token.
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    request = urllib.request.Request(
        url,
        headers=headers,
    )
    output_file.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = output_file.with_suffix(output_file.suffix + ".part")
    
    last_error = None
    for attempt in range(1, 4):
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                with tmp_path.open("wb") as handle:
                    while True:
                        chunk = response.read(1024 * 1024)
                        if not chunk:
                            break
                        handle.write(chunk)
            tmp_path.replace(output_file)
            return
        except Exception as error:
            last_error = error
            if attempt < 3:
                time.sleep(2)
    raise last_error


def get_by_path(payload: dict[str, Any], path: str) -> Any:
    current: Any = payload
    for key in str(path).split("."):
        if isinstance(current, dict):
            current = current.get(key)
        elif isinstance(current, list) and key.isdigit():
            index = int(key)
            if index < 0 or index >= len(current):
                return None
            current = current[index]
        else:
            return None
        if current is None:
            return None
    return current


def first_by_paths(payload: dict[str, Any], paths: list[str]) -> Any:
    for path in paths:
        value = get_by_path(payload, path)
        if value is not None and str(value).strip():
            return value
    return None


def extract_video_url(payload: dict[str, Any], paths: list[str] | None = None) -> str:
    # AIHUB can expose a stale relative video_url alongside the real signed URL
    # in data[0].url. Prefer a complete HTTP(S) URL so downloads work for both
    # AIHUB and legacy Moyin responses.
    priority_paths = ["video_url", "result.video_url", "result.resultUrls.0", "data.0.url"]
    configured_paths = list(paths or [])
    remaining_paths = [path for path in configured_paths if path not in priority_paths]
    candidates = []
    for path in priority_paths + remaining_paths:
        value = get_by_path(payload, path)
        if value is not None and str(value).strip():
            candidates.append(str(value).strip())
    for value in candidates:
        if urllib.parse.urlparse(value).scheme in {"http", "https"}:
            return value
    return candidates[0] if candidates else ""


def extract_status(payload: dict[str, Any], paths: list[str] | None = None) -> str:
    default_paths = ["status", "state", "data.status", "data.state", "result.status", "result.state"]
    return str(first_by_paths(payload, paths or default_paths) or "").lower()


def local_jobs_root() -> str:
    return os.environ.get("N8N_LOCAL_JOBS_DIR", "E:/n8n-video-gemini/video_jobs")


def local_output_root() -> str:
    return os.environ.get("N8N_LOCAL_OUTPUT_DIR", "E:/n8n-video-gemini/video_output")

def sanitize_job(job: dict[str, Any]) -> dict[str, Any]:
    safe_job = dict(job)
    safe_job["job_id"] = slugify(job.get("job_id"), "job")
    safe_job["script_id"] = slugify(job.get("script_id"), "script")
    safe_job["product_id"] = slugify(job.get("product_id"), "product")

    status_dir = reject_unsafe_path(job.get("status_dir"), "status_dir", local_jobs_root())
    output_dir = reject_unsafe_path(job.get("output_dir"), "output_dir", local_output_root())
    safe_job["status_dir"] = str(status_dir)
    safe_job["output_dir"] = str(output_dir)
    safe_job["assembly_plan"] = sanitize_assembly_plan(job, output_dir)

    scenes = []
    for index, scene in enumerate(job.get("scenes") or [], start=1):
        safe_scene = dict(scene)
        safe_scene["scene_id"] = slugify(scene.get("scene_id"), f"scene-{index}")
        safe_scene["output_file"] = str(reject_unsafe_path(scene.get("output_file"), "scene.output_file", local_output_root(), "mp4"))
        if not str(scene.get("moyin_task_id") or "").strip():
            raise ValueError(f"scene {safe_scene['scene_id']} missing moyin_task_id")
        scenes.append(safe_scene)
    if not scenes:
        raise ValueError("job.scenes must contain at least one scene")
    if safe_job["assembly_plan"] and {scene["scene_id"] for scene in scenes} != {"video_a", "video_b"}:
        raise ValueError("silent A/B assembly requires exactly video_A and video_B scenes")
    safe_job["scenes"] = scenes
    safe_job["max_runtime_seconds"] = int(job.get("max_runtime_seconds") or 7200)
    safe_job["poll_interval_seconds"] = int(job.get("poll_interval_seconds") or 60)
    return safe_job


def status_payload(job: dict[str, Any], scenes_state: dict[str, dict[str, Any]], status: str) -> dict[str, Any]:
    payload = {
        "job_id": job["job_id"],
        "script_id": job["script_id"],
        "product_id": job["product_id"],
        "active_skill": job.get("active_skill"),
        "github_url": job.get("github_url"),
        "product_folder": job.get("product_folder"),
        "skill_path": job.get("skill_path"),
        "status": status,
        "updated_at": int(time.time()),
        "scenes": list(scenes_state.values()),
    }
    last_errors = [state.get("last_error") for state in scenes_state.values() if state.get("last_error")]
    if last_errors:
        payload["last_error"] = last_errors[-1]
    return payload


def fail_and_exit(status_dir: Path, job: dict[str, Any], scenes_state: dict[str, dict[str, Any]], reason: str, code: int = 1) -> int:
    payload = status_payload(job, scenes_state, "failed")
    payload["error"] = reason
    atomic_write_json(status_dir / "status.json", payload)
    atomic_write_json(status_dir / "failed.json", payload)
    return code


def run(job_path: Path) -> int:
    job = sanitize_job(read_json(job_path))
    api_key = os.environ.get("MOYIN_API_KEY", "").strip()
    status_dir = Path(job["status_dir"])
    output_dir = Path(job["output_dir"])
    status_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    scenes_state = {
        scene["scene_id"]: {
            "scene_id": scene["scene_id"],
            "moyin_task_id": scene["moyin_task_id"],
            "status": "queued",
            "output_file": scene["output_file"],
        }
        for scene in job["scenes"]
    }
    atomic_write_json(status_dir / "status.json", status_payload(job, scenes_state, "running"))

    if not api_key:
        return fail_and_exit(status_dir, job, scenes_state, "MOYIN_API_KEY environment variable is required")

    timeout_seconds = int(os.environ.get("MOYIN_TIMEOUT_SECONDS") or job["max_runtime_seconds"])
    deadline = time.time() + timeout_seconds
    poll_interval = max(1, int(os.environ.get("MOYIN_POLL_INTERVAL_SECONDS") or 8))
    base_url = moyin_base_url(job)
    moyin_api = job.get("moyin_api") or {}
    status_paths = list(moyin_api.get("status_paths") or [])
    video_url_paths = list(moyin_api.get("video_url_paths") or [])
    success_statuses = {str(s).lower() for s in (moyin_api.get("success_statuses") or DEFAULT_SUCCESS_STATUSES)}
    failed_statuses = {str(s).lower() for s in (moyin_api.get("failed_statuses") or DEFAULT_FAILED_STATUSES)}

    while True:
        if time.time() > deadline:
            payload = status_payload(job, scenes_state, "timeout")
            payload["error"] = f"MOYIN_TIMEOUT_SECONDS exceeded ({timeout_seconds}s)"
            atomic_write_json(status_dir / "status.json", payload)
            atomic_write_json(status_dir / "failed.json", payload)
            return 1

        all_done = True
        for scene in job["scenes"]:
            scene_id = scene["scene_id"]
            state = scenes_state[scene_id]
            if state["status"] == "completed":
                continue

            all_done = False
            task_id = scene["moyin_task_id"]
            try:
                payload = request_json(f"{base_url}{moyin_query_path(job, task_id)}", api_key)
            except (
                urllib.error.URLError,
                ssl.SSLError,
                socket.timeout,
                TimeoutError,
                ConnectionResetError,
                json.JSONDecodeError,
            ) as error:
                state["status"] = "poll_error"
                state["last_error"] = str(error)
                state["last_error_at"] = int(time.time())
                atomic_write_json(status_dir / "status.json", status_payload(job, scenes_state, "running"))
                continue

            state.pop("last_error", None)
            state.pop("last_error_at", None)
            remote_status = extract_status(payload, status_paths)
            state["remote_status"] = remote_status
            state["last_response_at"] = int(time.time())

            if remote_status in failed_statuses:
                state["status"] = remote_status
                state["error"] = payload.get("error") or payload.get("message") or "Moyin task failed"
                return fail_and_exit(status_dir, job, scenes_state, f"scene {scene_id} failed: {state['error']}")

            if remote_status in success_statuses:
                download_errors = []
                for download_url, requires_api_auth, source in build_download_candidates(
                    payload,
                    video_url_paths,
                    base_url,
                    task_id,
                ):
                    try:
                        download_file(
                            download_url,
                            Path(scene["output_file"]),
                            api_key=api_key if requires_api_auth else None,
                        )
                        state["download_source"] = source
                        break
                    except (urllib.error.URLError, TimeoutError, OSError, ValueError) as error:
                        download_errors.append(f"{source}: {error}")
                else:
                    error = "; ".join(download_errors) or "no download URL candidates"
                    state["status"] = "download_error"
                    state["error"] = error
                    return fail_and_exit(status_dir, job, scenes_state, f"scene {scene_id} download failed: {error}")
                state["status"] = "completed"
                state["video_url_seen"] = True
                state["completed_at"] = int(time.time())
                atomic_write_json(status_dir / "status.json", status_payload(job, scenes_state, "running"))
            else:
                state["status"] = remote_status or "processing"
                atomic_write_json(status_dir / "status.json", status_payload(job, scenes_state, "running"))

        if all_done:
            try:
                assembly = assemble_silent_ab20(job, scenes_state)
            except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                return fail_and_exit(status_dir, job, scenes_state, str(error))
            payload = status_payload(job, scenes_state, "completed")
            if assembly:
                payload["assembly"] = assembly
            atomic_write_json(status_dir / "status.json", payload)
            atomic_write_json(status_dir / "done.json", payload)
            try:
                (status_dir / "failed.json").unlink()
            except FileNotFoundError:
                pass
            return 0

        time.sleep(poll_interval)


def main() -> int:
    parser = argparse.ArgumentParser(description="Poll Moyin tasks and save videos locally.")
    parser.add_argument("--job", required=True, help="Path to local video_jobs/{job_id}/job.json")
    args = parser.parse_args()
    try:
        job_path = reject_unsafe_path(args.job, "job", local_jobs_root(), "job_json")
        return run(job_path)
    except Exception as error:  # Keep worker self-contained and log-friendly.
        sys.stderr.write(f"moyin_worker failed: {error}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())





