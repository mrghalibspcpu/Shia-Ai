#!/usr/bin/env python3
"""Normalise the standalone collections so they match the original 14-book corpus.

``assets/quran.db``, ``assets/mafatihdb-v4.db`` and ``assets/nahjul_balagha_v2.db``
arrive from their source apps with different page sizes, no indexes, and
occasionally leftover free pages. This rewrites each file in place so that every
database the app ships shares one configuration:

* SQLite ``page_size`` of 1024 (the setting used by all 14 hadith books),
* UTF-8 text encoding,
* the reader indexes the Flutter client needs, prefixed ``shia_``,
* fresh statistics (``ANALYZE``) and no free pages (``VACUUM``),
* the legacy ``android_metadata`` locale row the other books carry.

Row data is never edited — only the container settings and indexes change.
"""
from __future__ import annotations

import argparse
import os
import shutil
import sqlite3
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from database_specs import EXTRA_DATABASES, TARGET_PAGE_SIZE, DatabaseSpec  # noqa: E402


class NormalizeError(RuntimeError):
    """Raised when a database cannot be rebuilt safely."""


def _row_counts(connection: sqlite3.Connection, spec: DatabaseSpec) -> dict[str, int]:
    return {
        table: int(connection.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0])
        for table in spec.tables
    }


def _table_fingerprint(connection: sqlite3.Connection, spec: DatabaseSpec) -> list[tuple]:
    """Cheap content fingerprint so we can prove the rebuild changed no rows."""
    fingerprint: list[tuple] = []
    for table in spec.tables:
        columns = [row[1] for row in connection.execute(f'PRAGMA table_info("{table}")')]
        digest = connection.execute(
            f'SELECT COUNT(*), SUM(LENGTH(CAST("{columns[0]}" AS TEXT))) FROM "{table}"'
        ).fetchone()
        fingerprint.append((table, tuple(columns), tuple(digest)))
    return fingerprint


def normalize_database(spec: DatabaseSpec, *, apply_changes: bool) -> dict[str, object]:
    path = spec.asset_path
    if not path.is_file():
        raise NormalizeError(f"{path} is missing")

    source = sqlite3.connect(f"file:{path.resolve().as_posix()}?mode=ro", uri=True)
    try:
        quick = source.execute("PRAGMA quick_check").fetchone()
        if not quick or quick[0] != "ok":
            raise NormalizeError(f"{spec.name} failed quick_check before rebuild: {quick}")
        before = _row_counts(source, spec)
        fingerprint = _table_fingerprint(source, spec)
        original_page_size = int(source.execute("PRAGMA page_size").fetchone()[0])
        original_indexes = {
            row[0]
            for row in source.execute("SELECT name FROM sqlite_master WHERE type = 'index'")
        }
    finally:
        source.close()

    missing = [
        statement
        for statement in spec.indexes
        if statement.split("shia_", 1)[1].split(" ")[0] not in original_indexes
    ]
    already_consistent = (
        original_page_size == TARGET_PAGE_SIZE
        and not missing
        and path.stat().st_size > 0
    )

    report: dict[str, object] = {
        "name": spec.name,
        "before_bytes": path.stat().st_size,
        "before_page_size": original_page_size,
        "missing_indexes": len(missing),
        "rows": before,
        "changed": False,
    }
    if not apply_changes:
        report["changed"] = not already_consistent
        return report
    if already_consistent:
        return report

    temp_dir = Path(tempfile.mkdtemp(prefix=".shia-normalize-", dir=path.parent))
    rebuilt = temp_dir / spec.name
    try:
        connection = sqlite3.connect(path.resolve().as_posix())
        try:
            connection.execute(f"PRAGMA page_size={TARGET_PAGE_SIZE}")
            connection.execute("VACUUM INTO ?", (str(rebuilt),))
        finally:
            connection.close()

        target = sqlite3.connect(rebuilt.resolve().as_posix())
        try:
            for statement in spec.indexes:
                target.execute(statement)
            target.execute(
                "CREATE TABLE IF NOT EXISTS android_metadata (locale TEXT DEFAULT 'ur_PK')"
            )
            target.execute(
                "INSERT INTO android_metadata(locale) SELECT 'ur_PK' "
                "WHERE NOT EXISTS (SELECT 1 FROM android_metadata WHERE locale = 'ur_PK')"
            )
            target.execute("ANALYZE")
            target.commit()

            integrity = target.execute("PRAGMA integrity_check").fetchone()
            if not integrity or integrity[0] != "ok":
                raise NormalizeError(f"{spec.name} failed integrity_check after rebuild: {integrity}")
            if _row_counts(target, spec) != before:
                raise NormalizeError(f"{spec.name} lost or gained rows during rebuild")
            if _table_fingerprint(target, spec) != fingerprint:
                raise NormalizeError(f"{spec.name} content fingerprint changed during rebuild")
            encoding = str(target.execute("PRAGMA encoding").fetchone()[0]).lower()
            if encoding != "utf-8":
                raise NormalizeError(f"{spec.name} is not UTF-8 after rebuild: {encoding}")
        finally:
            target.close()

        os.replace(rebuilt, path)
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

    report["after_bytes"] = path.stat().st_size
    report["changed"] = True
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would change without touching the files",
    )
    args = parser.parse_args()

    try:
        for spec in EXTRA_DATABASES:
            if spec.source in {"sahifa", "fatwa"}:
                print(f"{spec.name}: preserving the uploaded runtime database")
                continue
            report = normalize_database(spec, apply_changes=not args.dry_run)
            rows = ", ".join(f"{table}={count}" for table, count in report["rows"].items())  # type: ignore[union-attr]
            verb = "needs rebuild" if report["changed"] else "already consistent"
            print(
                f"{report['name']}: page_size {report['before_page_size']} -> {TARGET_PAGE_SIZE}, "
                f"{report['missing_indexes']} missing indexes, {report['before_bytes']:,} bytes "
                f"({'dry-run: ' if args.dry_run else ''}{verb}); {rows}"
            )
            if report["changed"] and not args.dry_run:
                print(f"  rebuilt -> {report['after_bytes']:,} bytes")
    except NormalizeError as exc:
        parser.error(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
