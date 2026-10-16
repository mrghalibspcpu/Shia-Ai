"""The CI annotation builder: it must name every failing test, and only those.

The CI job for this app cannot be rerun on a whim (a Flutter build takes
minutes), so the one annotation it produces has to be worth reading: the names
and the broken expectations, not the last four hundred lines of a log that
GitHub would cut in the middle anyway.
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from flutter_test_digest import MAX_DETAIL, annotate, digest  # noqa: E402

LOG = """\
00:00 +0: loading /w/app/test/compass_math_test.dart
00:01 +3 -1: /w/app/test/compass_math_test.dart: the filter smooths across north [E]
  Expected: 5.0
    Actual: 355.0
  package:matcher                                     expect
  test/compass_math_test.dart 88:7                    main.<fn>.<fn>
00:01 +4 -1: /w/app/test/compass_math_test.dart: it keeps the turn short
00:02 +90 -2: /w/app/test/prayer_engine_test.dart: justPrayed fires after a prayer [E]
  Expected: PrayerMarker:<PrayerMarker.dhuhr>
    Actual: <null>
  test/prayer_engine_test.dart 353:7                  main.<fn>.<fn>
00:02 +113 -2: Some tests failed.
"""


# A widget test's real cause sits *above* its failure line: `flutter test`
# prints the exception first, then `[E]` with "See exception logs above."
WIDGET_LOG = """\
00:03 +200: /w/app/test/ui_layout_test.dart: the dashboard fits
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _WidgetTypeFinder:<zero widgets with icon IconData(U+0E3AC) (lock)>
   Which: means none were found but one was expected
When the exception was thrown, this was the stack:
#0      fail (package:matcher/src/expect/expect.dart:160:31)
#1      main.<anonymous closure> (file:///w/app/test/ui_layout_test.dart:255:5)
════════════════════════════════════════════════════════════════════════════════════════════════════
00:03 +200 -1: /w/app/test/ui_layout_test.dart: the tasbeeh dial locks its reset button [E]
  Test failed. See exception logs above.
  The test description was: the tasbeeh dial locks its reset button
00:03 +201 -1: Some tests failed.
"""


def annotate_text(text: str) -> str:
    """annotate() reads a file; this keeps the real code path under test."""
    with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as handle:
        handle.write(text)
        path = handle.name
    try:
        return annotate(path)
    finally:
        Path(path).unlink()


class DigestTest(unittest.TestCase):
    def test_every_failure_is_named_with_its_expectation(self) -> None:
        detail = digest(LOG)
        self.assertIn("compass_math_test.dart: the filter smooths across north [E]", detail)
        self.assertIn("Expected: 5.0", detail)
        self.assertIn("Actual: 355.0", detail)
        self.assertIn("prayer_engine_test.dart: justPrayed fires after a prayer [E]", detail)
        self.assertIn("Actual: <null>", detail)

    def test_passing_tests_are_not_in_the_digest(self) -> None:
        detail = digest(LOG)
        self.assertNotIn("it keeps the turn short", detail)
        self.assertNotIn("loading /w/app/test/", detail)

    def test_the_counters_prefix_is_stripped_from_each_failure(self) -> None:
        detail = digest(LOG)
        for line in detail.splitlines():
            self.assertFalse(line.startswith("00:"), line)
        # …and the run's own summary line is kept, without its timestamp.
        self.assertIn("+113 -2: Some tests failed.", detail)

    def test_the_annotation_is_escaped_for_a_workflow_command(self) -> None:
        annotation = annotate_text(LOG)
        self.assertTrue(annotation.startswith("::error title=Flutter tests failed (2)::"))
        self.assertNotIn("\n", annotation)
        self.assertIn("%0A", annotation)

    def test_a_log_without_failures_still_produces_a_valid_annotation(self) -> None:
        annotation = annotate_text("00:01 +113: All tests passed!\n")
        self.assertIn("(0)", annotation)
        self.assertIn("no failure blocks", annotation)
        self.assertIn("All tests passed!", annotation)

    def test_a_long_log_is_truncated_with_a_marker(self) -> None:
        many = "\n".join(
            f"00:01 +{index} -{index}: /w/app/test/x_test.dart: case {index} [E]\n"
            "  Expected: 1\n    Actual: 2\n  package:matcher expect"
            for index in range(200)
        )
        detail = digest(many)
        self.assertLessEqual(len(detail), MAX_DETAIL)
        self.assertTrue(detail.endswith("…"))

    def test_an_empty_log_is_not_an_error(self) -> None:
        self.assertIn("no failure blocks", digest(""))

    def test_the_exception_above_a_widget_failure_is_read(self) -> None:
        detail = digest(WIDGET_LOG)
        self.assertIn("the tasbeeh dial locks its reset button [E]", detail)
        self.assertIn("The following TestFailure was thrown running a test:", detail)
        self.assertIn("zero widgets with icon", detail)
        self.assertIn("Which: means none were found but one was expected", detail)
        # The stack frames are noise in an annotation GitHub cuts at 4 KB.
        self.assertNotIn("#0      fail", detail)

    def test_the_exception_block_does_not_look_like_a_second_failure(self) -> None:
        self.assertTrue(annotate_text(WIDGET_LOG).startswith("::error title=Flutter tests failed (1)::"))


if __name__ == "__main__":
    unittest.main()
