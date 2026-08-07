import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


DEFAULT_TASK_ID_PATHS = [
    "id", "task_id", "taskId",
    "data.id", "data.task_id", "data.taskId",
    "data.task.id", "data.task.task_id", "data.task.taskId",
    "result.id", "result.task_id", "result.taskId",
    "response.id", "response.task_id", "response.taskId",
]

DEFAULT_STATUS_PATHS = [
    "status", "state",
    "data.status", "data.state",
    "data.task.status", "data.task.state",
    "result.status", "result.state",
    "response.status", "response.state",
]

DEFAULT_VIDEO_URL_PATHS = [
    "video_url", "output_url", "url",
    "data.video_url", "data.output_url", "data.url",
    "data.task.video_url", "data.task.output_url", "data.task.url",
    "result.video_url", "result.output_url", "result.url",
    "response.video_url", "response.output_url", "response.url",
]

SUCCESS_STATUSES = {"completed", "succeeded", "success", "done"}
FAILED_STATUSES = {"failed", "error", "cancelled", "canceled"}


def load_dotenv(path="E:/n8n-video-gemini/.env"):
    env_path = Path(path)
    if not env_path.exists():
        return
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


load_dotenv()


def env(name, default=""):
    return os.environ.get(name, default).strip()


def _join_url(base_url, path):
    base = str(base_url or "").strip().rstrip("/")
    path_value = str(path or "").strip()
    if not base:
        raise RuntimeError("MOYIN_API_BASE_URL is not configured.")
    if not path_value:
        raise RuntimeError("Moyin API path is not configured.")
    if not path_value.startswith("/"):
        path_value = "/" + path_value
    if base.lower().endswith("/v1") and path_value.lower().startswith("/v1/"):
        path_value = path_value[3:]
    return base + path_value


def _get_by_path(obj, path):
    current = obj
    for part in str(path).split("."):
        if current is None:
            return None
        if isinstance(current, dict):
            current = current.get(part)
        else:
            return None
    return current


def _first_path(obj, paths):
    for path in paths:
        value = _get_by_path(obj, path)
        if value is not None and str(value).strip():
            return value
    return None


def _json_request(method, full_url, body=None, timeout=120):
    api_key = env("MOYIN_API_KEY")
    if not api_key:
        raise RuntimeError("MOYIN_API_KEY is not configured.")

    data = None
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")

    request = urllib.request.Request(full_url, data=data, headers=headers, method=method.upper())
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            text = response.read().decode("utf-8", errors="replace")
            try:
                payload = json.loads(text)
            except json.JSONDecodeError:
                payload = {"raw": text}
            return {"status_code": response.status, "body": payload, "raw": text, "full_url": full_url}
    except urllib.error.HTTPError as error:
        text = error.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(text)
        except json.JSONDecodeError:
            payload = {"raw": text}
        raise RuntimeError(f"Moyin HTTP {error.code} at {full_url}: {text}") from error


def create_video(prompt_image, prompt_text, duration=None, ratio=None):
    create_path = env("MOYIN_CREATE_PATH")
    if not create_path:
        raise RuntimeError("MOYIN_CREATE_PATH is not configured. Please set it after confirming Moyin API docs.")

    base_url = env("MOYIN_API_BASE_URL", "https://demo.moyinai.com/api/v1")
    full_url = _join_url(base_url, create_path)
    body = {
        "promptImage": prompt_image,
        "promptText": prompt_text,
        "model": env("MOYIN_VIDEO_MODEL", "veo-omni-flash"),
        "size": env("MOYIN_VIDEO_SIZE", "720x1280"),
    }
    if duration is not None:
        body["duration"] = duration
    if ratio is not None:
        body["ratio"] = ratio
    return _json_request("POST", full_url, body=body, timeout=int(env("MOYIN_TIMEOUT_SECONDS", "900")))["body"]


def query_task(task_id):
    query_template = env("MOYIN_QUERY_PATH_TEMPLATE")
    if not query_template:
        raise RuntimeError("MOYIN_QUERY_PATH_TEMPLATE is not configured. Please set it after confirming Moyin API docs.")

    base_url = env("MOYIN_API_BASE_URL", "https://demo.moyinai.com/api/v1")
    escaped = urllib.parse.quote(str(task_id), safe="")
    query_path = query_template.replace("{task_id}", escaped)
    full_url = _join_url(base_url, query_path)
    return _json_request("GET", full_url, timeout=120)["body"]


def extract_task_id(response):
    return _first_path(response, DEFAULT_TASK_ID_PATHS)


def extract_status(response):
    value = _first_path(response, DEFAULT_STATUS_PATHS)
    return str(value).strip() if value is not None else ""


def extract_video_url(response):
    value = _first_path(response, DEFAULT_VIDEO_URL_PATHS)
    return str(value).strip() if value is not None else ""


def is_success_status(status):
    return str(status or "").strip().lower() in SUCCESS_STATUSES


def is_failed_status(status):
    return str(status or "").strip().lower() in FAILED_STATUSES
