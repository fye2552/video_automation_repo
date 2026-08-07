import importlib.util
import unittest
from pathlib import Path


WORKER_PATH = Path(__file__).parents[1] / "workers" / "moyin_worker.py"
SPEC = importlib.util.spec_from_file_location("moyin_worker", WORKER_PATH)
assert SPEC and SPEC.loader
MOYIN_WORKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOYIN_WORKER)


class DownloadCandidateTests(unittest.TestCase):
    def test_original_create_task_id_is_preferred_for_api_content(self):
        payload = {
            "video_url": "/v1/videos/vid-internal/content",
            "data": [{"url": "https://download.example/v1/videos/task-upstream/content"}],
        }

        candidates = MOYIN_WORKER.build_download_candidates(
            payload,
            [],
            "https://api.example/v1",
            "task-create",
        )

        self.assertEqual(
            candidates[0],
            ("https://api.example/v1/videos/task-create/content", True, "api_task_content"),
        )
        self.assertEqual(
            candidates[1],
            ("https://download.example/v1/videos/task-upstream/content", False, "response_video_url"),
        )

    def test_task_id_is_url_encoded(self):
        candidates = MOYIN_WORKER.build_download_candidates(
            {},
            [],
            "https://api.example/v1/",
            "task id/unsafe",
        )

        self.assertEqual(
            candidates,
            [("https://api.example/v1/videos/task%20id%2Funsafe/content", True, "api_task_content")],
        )


if __name__ == "__main__":
    unittest.main()
