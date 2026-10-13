from __future__ import annotations

import json
import unittest
from io import BytesIO
from unittest.mock import patch
from urllib.error import HTTPError

from shia_ai.gemini import generate_grounded_answer
from shia_ai.search import Passage


class _FakeResponse:
    def __init__(self, payload: dict) -> None:
        self._payload = json.dumps(payload).encode("utf-8")

    def read(self) -> bytes:
        return self._payload

    def __enter__(self) -> "_FakeResponse":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        return None


class GeminiClientTests(unittest.TestCase):
    def test_falls_back_to_next_model_on_http_404(self) -> None:
        passage = Passage(
            source_id="alkafi:1",
            database="alkafi.db",
            book="alkafi",
            paragraph_id=1,
            section_id=7,
            page_no=1,
            chapter_title="باب",
            section_title="فصل",
            arabic="قال الإمام",
            urdu="امام نے فرمایا",
            relevance=1.0,
        )
        calls: list[str] = []

        def fake_urlopen(request, timeout=0):
            calls.append(request.full_url)
            if "gemini-2.5-flash" in request.full_url:
                raise HTTPError(request.full_url, 404, "not found", hdrs=None, fp=BytesIO(b"{}"))
            return _FakeResponse(
                {"candidates": [{"content": {"parts": [{"text": "جواب [R1]"}]}}]}
            )

        with patch.dict("os.environ", {"GEMINI_API_KEY": "test-key", "GEMINI_MODEL": "gemini-2.5-flash"}):
            with patch("shia_ai.gemini.urlopen", side_effect=fake_urlopen):
                answer = generate_grounded_answer("سوال", [passage])
        self.assertIn("[R1]", answer)
        self.assertGreaterEqual(len(calls), 2)
        self.assertIn("gemini-2.5-flash", calls[0])


if __name__ == "__main__":
    unittest.main()
