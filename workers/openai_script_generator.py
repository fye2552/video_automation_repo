#!/usr/bin/env python3
"""Generate an OpenAI-compatible script response outside the n8n task runner."""

from __future__ import annotations

import argparse
import json
import os
import socket
import ssl
import sys
import time
import http.client
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_URL = "https://aihubcc.cc/v1/chat/completions"
DEFAULT_MODEL = "gpt-5.5"
PER_ATTEMPT_TIMEOUT_SECONDS = 180
RETRY_DELAYS = [5, 15, 30, 60, 120]
RETRY_STATUS_CODES = {408, 429, 500, 502, 503, 504}
RETRY_TEXT = (
    "socket hang up",
    "econnreset",
    "connection reset",
    "remote end closed",
    "remotedisconnected",
    "etimedout",
    "timeout",
    "timed out",
    "tls",
    "ssl",
    "unexpected eof",
    "rate limit",
    "rate_limit",
    "too many requests",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class EventLogger:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def write(self, event: str, **fields: Any) -> None:
        record = {"timestamp": utc_now(), "event": event, **fields}
        with self.path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False, default=str) + "\n")


def body_summary(raw: str, limit: int = 1200) -> dict[str, Any]:
    text = str(raw or "")
    if len(text) <= limit * 2:
        return {"length": len(text), "head": text, "tail": text}
    return {"length": len(text), "head": text[:limit], "tail": text[-limit:]}


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError("input JSON must contain an object")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    os.replace(temporary, path)


def should_retry(status: int | None, message: str) -> bool:
    if status in RETRY_STATUS_CODES:
        return True
    lowered = str(message or "").lower()
    return any(token in lowered for token in RETRY_TEXT)


def merge_sse(raw: str) -> dict[str, Any]:
    contents: dict[int, list[str]] = {}
    roles: dict[int, str] = {}
    finish_reasons: dict[int, Any] = {}
    saw_data = False

    for line in raw.splitlines():
        line = line.strip()
        if not line.startswith("data:"):
            continue
        saw_data = True
        payload = line[5:].strip()
        if not payload or payload == "[DONE]":
            continue
        try:
            event = json.loads(payload)
        except json.JSONDecodeError:
            continue
        for choice in event.get("choices") or []:
            index = int(choice.get("index", 0))
            delta = choice.get("delta") or {}
            message = choice.get("message") or {}
            role = delta.get("role") or message.get("role")
            if role:
                roles[index] = str(role)
            content = delta.get("content")
            if content is None:
                content = message.get("content")
            if isinstance(content, str):
                contents.setdefault(index, []).append(content)
            if choice.get("finish_reason") is not None:
                finish_reasons[index] = choice.get("finish_reason")

    if not saw_data or not contents:
        raise ValueError("response is neither OpenAI JSON nor parseable SSE data")

    choices = []
    for index in sorted(contents):
        choices.append(
            {
                "index": index,
                "message": {
                    "role": roles.get(index, "assistant"),
                    "content": "".join(contents[index]),
                },
                "finish_reason": finish_reasons.get(index),
            }
        )
    return {"choices": choices}


def parse_openai_response(raw: str) -> dict[str, Any]:
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        parsed = None
    if isinstance(parsed, dict) and isinstance(parsed.get("choices"), list):
        return parsed
    return merge_sse(raw)


def read_response_text(response: Any, charset: str) -> tuple[str, bool]:
    chunks: list[bytes] = []
    incomplete = False
    while True:
        try:
            chunk = response.read(8192)
        except http.client.IncompleteRead as error:
            partial = error.partial or b""
            if partial:
                chunks.append(partial)
            incomplete = True
            break
        if not chunk:
            break
        chunks.append(chunk)
    return b"".join(chunks).decode(charset, errors="replace"), incomplete


def post_json(url: str, api_key: str, body: dict[str, Any], timeout: float) -> tuple[int, str]:
    encoded = json.dumps(body, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=encoded,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "User-Agent": "n8n-video-openai-generator/1.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            charset = response.headers.get_content_charset() or "utf-8"
            text, incomplete = read_response_text(response, charset)
            if incomplete and not text.strip():
                raise http.client.IncompleteRead(b"")
            return int(response.status), text
    except urllib.error.HTTPError as error:
        charset = error.headers.get_content_charset() or "utf-8"
        text, _ = read_response_text(error, charset)
        return int(error.code), text


def generate(args: argparse.Namespace) -> int:
    input_path = Path(args.input).resolve()
    output_path = Path(args.output).resolve()
    logger = EventLogger(Path(args.log).resolve())
    started = time.monotonic()
    deadline = started + max(1, int(args.timeout_seconds))
    last_status: int | None = None
    last_body = ""
    last_error = ""

    try:
        config = read_json(input_path)
        api_key_env = str(config.get("api_key_env") or "OPENAI_API_KEY")
        api_key = str(os.environ.get(api_key_env) or "").strip()
        openai_url = str(
            config.get("openai_url")
            or os.environ.get("OPENAI_CHAT_COMPLETIONS_URL")
            or DEFAULT_URL
        ).strip()
        model = str(config.get("model") or os.environ.get("OPENAI_MODEL") or DEFAULT_MODEL).strip()
        messages = config.get("messages")
        if not api_key:
            raise ValueError(f"{api_key_env} environment variable is required")
        if not openai_url:
            raise ValueError("OpenAI-compatible URL is required")
        if not isinstance(messages, list) or not messages:
            raise ValueError("messages must be a non-empty array")

        extra = config.get("request_body_extra") or {}
        if not isinstance(extra, dict):
            raise ValueError("request_body_extra must be an object")
        body = {
            "model": model,
            "messages": messages,
            "multi_agent": True,
            "service_tier": "fast",
            "stream": False,
            "max_tokens": 4096,
            **extra,
        }
        body["model"] = model
        body["messages"] = messages

        logger.write(
            "started",
            started_at=utc_now(),
            openai_url=openai_url,
            model=model,
            timeout_seconds=args.timeout_seconds,
            max_retries=args.max_retries,
        )

        total_attempts = max(0, int(args.max_retries)) + 1
        for attempt in range(1, total_attempts + 1):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("overall OpenAI generation timeout reached")
            request_timeout = min(PER_ATTEMPT_TIMEOUT_SECONDS, max(10, remaining))
            logger.write(
                "attempt",
                attempt=attempt,
                remaining_seconds=round(remaining, 3),
                per_attempt_timeout_seconds=round(request_timeout, 3),
            )
            try:
                last_status, last_body = post_json(
                    openai_url,
                    api_key,
                    body,
                    request_timeout,
                )
                logger.write(
                    "http_response",
                    attempt=attempt,
                    http_status=last_status,
                    response_summary=body_summary(last_body),
                )
                if 200 <= last_status < 300:
                    response = parse_openai_response(last_body)
                    if not response.get("choices"):
                        raise ValueError("OpenAI-compatible response is missing choices")
                    write_json(output_path, response)
                    logger.write("final_success", attempt=attempt, http_status=last_status)
                    return 0
                last_error = f"HTTP {last_status}"
                retryable = should_retry(last_status, last_body)
            except (
                urllib.error.URLError,
                TimeoutError,
                socket.timeout,
                ConnectionResetError,
                ssl.SSLError,
                OSError,
            ) as error:
                last_error = f"{type(error).__name__}: {error}"
                retryable = should_retry(None, last_error)
                logger.write("request_error", attempt=attempt, error=last_error)

            if not retryable or attempt >= total_attempts:
                break
            delay = RETRY_DELAYS[min(attempt - 1, len(RETRY_DELAYS) - 1)]
            remaining = deadline - time.monotonic()
            if remaining <= delay:
                last_error = "overall timeout would be exceeded before next retry"
                break
            logger.write("retry_wait", attempt=attempt, delay_seconds=delay)
            time.sleep(delay)

        failure = {
            "ok": False,
            "error": last_error or "OpenAI-compatible request failed",
            "last_status": last_status,
            "last_body": last_body[-20000:],
            "failure_layer": "OpenAI",
        }
        write_json(output_path, failure)
        logger.write(
            "final_failure",
            error=failure["error"],
            last_status=last_status,
            response_summary=body_summary(last_body),
        )
        return 1
    except Exception as error:  # Ensure n8n always receives an output JSON.
        failure = {
            "ok": False,
            "error": f"{type(error).__name__}: {error}",
            "last_status": last_status,
            "last_body": last_body[-20000:],
            "failure_layer": "OpenAI",
        }
        write_json(output_path, failure)
        logger.write("final_failure", error=failure["error"], last_status=last_status)
        return 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--timeout-seconds", type=int, default=1800)
    parser.add_argument("--max-retries", type=int, default=5)
    return parser.parse_args()


if __name__ == "__main__":
    sys.exit(generate(parse_args()))
