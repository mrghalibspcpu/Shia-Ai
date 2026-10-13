"""Unit tests for the corpus packaging tools (no Flutter or network needed)."""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from database_specs import (  # noqa: E402
    DATABASES,
    EXTRA_DATABASES,
    MANIFEST_PATH,
    TARGET_PAGE_SIZE,
)
import prepare_databases  # noqa: E402


class DatabaseSpecTests(unittest.TestCase):
    def test_catalogue_covers_seventeen_databases(self):
        self.assertEqual(len(DATABASES), 17)
        self.assertEqual(len([spec for spec in DATABASES if spec.source == "hadith"]), 14)
        self.assertEqual(len(EXTRA_DATABASES), 3)

    def test_keys_and_file_names_are_unique(self):
        keys = [spec.key for spec in DATABASES]
        names = [spec.name for spec in DATABASES]
        self.assertEqual(len(set(keys)), len(keys))
        self.assertEqual(len(set(names)), len(names))

    def test_new_collections_declare_reader_indexes(self):
        for spec in EXTRA_DATABASES:
            with self.subTest(spec.name):
                self.assertTrue(spec.indexes, f"{spec.name} has no reader indexes")
                for statement in spec.indexes:
                    self.assertIn("shia_", statement)
                    self.assertIn("IF NOT EXISTS", statement)

    def test_page_size_matches_the_original_corpus(self):
        self.assertEqual(TARGET_PAGE_SIZE, 1024)


class HadithOrphanBaselineTests(unittest.TestCase):
    """Four books carry paragraphs whose section id has no Sections row.

    They are part of the original data, not damage: the client reads paragraphs
    with a LEFT JOIN, so all 20 stay searchable. ``scripts/verify_corpus.py``
    compares the live count against this baseline, so pin it here too.
    """

    def test_baseline_is_pinned_to_twenty_rows(self) -> None:
        from verify_corpus import KNOWN_SECTION_ORPHANS

        self.assertEqual(
            KNOWN_SECTION_ORPHANS,
            {"hidaya": 6, "imam": 1, "manlahyahzur": 3, "wasail": 10},
        )
        self.assertEqual(sum(KNOWN_SECTION_ORPHANS.values()), 20)

    def test_client_keeps_orphans_readable(self) -> None:
        """The indexed hadith query must be a LEFT JOIN, not an inner join."""
        repository = (ROOT / "app" / "lib" / "library_repository.dart").read_text(
            encoding="utf-8"
        )
        for statement in (
            "FROM Parags AS p\n          LEFT JOIN Sections AS s ON s.Secid = p.Secid",
            "chapter: chapter.isEmpty ? book.titleUrdu : chapter",
        ):
            self.assertIn(statement, repository)


class ManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    def test_manifest_is_version_two_and_complete(self):
        self.assertEqual(self.manifest["format_version"], 2)
        self.assertEqual(self.manifest["database_count"], 17)
        self.assertEqual(len(self.manifest["databases"]), 17)

    def test_every_entry_carries_a_digest_and_titles(self):
        for entry in self.manifest["databases"]:
            with self.subTest(entry["name"]):
                self.assertEqual(len(entry["sha256"]), 64)
                self.assertGreater(entry["size_bytes"], 0)
                self.assertTrue(entry["title_urdu"])
                self.assertTrue(entry["title_latin"])
                self.assertTrue(entry["records"])

    def test_totals_match_the_known_corpus(self):
        totals = self.manifest["totals"]
        self.assertEqual(totals["hadith_records"], 96513)
        self.assertEqual(totals["sections"], 17855)
        self.assertEqual(totals["chapters"], 845)
        self.assertEqual(totals["quran_verses"], 6236)
        self.assertEqual(totals["quran_surahs"], 114)
        self.assertEqual(totals["dua_items"], 677)
        self.assertEqual(totals["balagha_paragraphs"], 3742)

    def test_download_settings_are_absolute_https_urls(self):
        download = self.manifest["download"]
        self.assertEqual(download["extension"], ".db.gz")
        for url in download["base_urls"]:
            with self.subTest(url):
                self.assertTrue(url.startswith("https://"))
                self.assertTrue(url.endswith("/"))

    def test_app_bundle_carries_the_same_manifest(self):
        bundled = ROOT / "app" / "assets" / "database-manifest.json"
        self.assertTrue(bundled.is_file(), "run prepare_databases.py --write-manifest")
        self.assertEqual(
            json.loads(bundled.read_text(encoding="utf-8")),
            self.manifest,
        )


class ValidationTests(unittest.TestCase):
    """The three standalone collections are checked in, so validate them here."""

    def test_standalone_databases_open_and_match_their_spec(self):
        for spec in EXTRA_DATABASES:
            with self.subTest(spec.name):
                self.assertTrue(spec.asset_path.is_file())
                counts = prepare_databases.validate_database(spec.asset_path, spec)
                self.assertEqual(set(counts), set(spec.tables))
                for table, count in counts.items():
                    self.assertGreater(count, 0, f"{spec.name}.{table} is empty")

    def test_standalone_databases_use_the_shared_page_size(self):
        import sqlite3

        for spec in EXTRA_DATABASES:
            with self.subTest(spec.name):
                connection = sqlite3.connect(
                    f"file:{spec.asset_path.resolve().as_posix()}?mode=ro", uri=True
                )
                try:
                    self.assertEqual(
                        connection.execute("PRAGMA page_size").fetchone()[0], TARGET_PAGE_SIZE
                    )
                    self.assertEqual(
                        str(connection.execute("PRAGMA encoding").fetchone()[0]).lower(), "utf-8"
                    )
                    self.assertEqual(connection.execute("PRAGMA quick_check").fetchone()[0], "ok")
                    indexes = {
                        row[0]
                        for row in connection.execute(
                            "SELECT name FROM sqlite_master WHERE type = 'index'"
                        )
                    }
                    for statement in spec.indexes:
                        name = statement.split("shia_", 1)[1].split(" ")[0]
                        self.assertIn(f"shia_{name}", indexes)
                finally:
                    connection.close()

    def test_manifest_accepts_the_files_on_disk(self):
        with prepare_databases.collect_databases(include_bundle=False) as collected:
            records = prepare_databases.build_records(collected)
        self.assertEqual(len(records), len(EXTRA_DATABASES))
        prepare_databases.verify_against_manifest(records)

    def test_manifest_rejects_a_wrong_checksum(self):
        tampered = [
            {
                "name": "quran.db",
                "records": {"Quran": 6236},
                "sha256": "0" * 64,
            }
        ]
        with self.assertRaises(prepare_databases.DatabaseBundleError):
            prepare_databases.verify_against_manifest(tampered)

    def test_manifest_rejects_an_unknown_database(self):
        with self.assertRaises(prepare_databases.DatabaseBundleError):
            prepare_databases.verify_against_manifest(
                [{"name": "not-a-book.db", "records": {}, "sha256": "0" * 64}]
            )


if __name__ == "__main__":
    unittest.main()
