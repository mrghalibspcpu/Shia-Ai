"""Regression tests for the offline Dart guard (``scripts/check_dart.py``)."""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from unittest import TestCase

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "check_dart.py"


def load_guard():
    spec = importlib.util.spec_from_file_location("check_dart", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class CheckDartTests(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.guard = load_guard()

    def test_every_dart_file_passes_the_guard(self) -> None:
        paths = self.guard.dart_files()
        self.assertGreater(len(paths), 0, "no Dart files discovered")
        for path in paths:
            self.assertEqual(
                self.guard.check_unused_imports([path]),
                0,
                f"{path.name} imports something it never uses",
            )
            self.assertEqual(self.guard.check_forbidden([path]), 0, path.name)
            self.assertEqual(self.guard.check_balance([path]), 0, path.name)
            self.assertEqual(self.guard.check_imports([path]), 0, path.name)

    def test_unused_import_guard_actually_detects(self) -> None:
        """Inject a dead import and confirm the guard flags it."""
        target = ROOT / "app" / "lib" / "screens" / "settings_screen.dart"
        original = target.read_text(encoding="utf-8")
        self.assertIn("import '../data_packages.dart';", original)
        try:
            target.write_text(
                original.replace(
                    "import '../data_packages.dart';",
                    "import '../data_packages.dart';\nimport '../text_utils.dart';",
                    1,
                ),
                encoding="utf-8",
            )
            self.assertEqual(self.guard.check_unused_imports([target]), 1)
        finally:
            target.write_text(original, encoding="utf-8")
        self.assertEqual(self.guard.check_unused_imports([target]), 0)

    def test_forbidden_guard_detects_a_reintroduced_ai_symbol(self) -> None:
        target = ROOT / "app" / "lib" / "screens" / "settings_screen.dart"
        original = target.read_text(encoding="utf-8")
        try:
            # A comment is noise on purpose; the guard must catch real code.
            target.write_text(original + "\nfinal Object? _revived = GeminiClient;\n", encoding="utf-8")
            self.assertEqual(self.guard.check_forbidden([target]), 1)
            target.write_text(original + "\n// GeminiClient\n", encoding="utf-8")
            self.assertEqual(
                self.guard.check_forbidden([target]), 0, "comments should not trip the guard"
            )
        finally:
            target.write_text(original, encoding="utf-8")

    def test_interpolated_usage_is_not_treated_as_dead(self) -> None:
        source = "import '../data_packages.dart';\n" "final label = '${formatBytes(9)}';\n"
        self.assertIn("formatBytes", self.guard.identifiers_in(source))

    def test_exported_names_include_reexports(self) -> None:
        names = self.guard.exported_names(ROOT / "app" / "lib" / "library_repository.dart")
        self.assertIn("LibraryRepository", names)
        # `export 'text_utils.dart' show ...` must stay visible to importers.
        self.assertIn("expandSearchQueries", names)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(0)
