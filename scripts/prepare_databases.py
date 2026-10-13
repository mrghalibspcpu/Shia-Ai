#!/usr/bin/env python3
"""Safely unpack and validate the Shia Ahadith SQLite bundle.

The APK ships each database as an asset. Keeping the source bundle compressed
avoids committing ~190 MB of expanded SQLite files; build/development steps can
materialize the original files into assets/databases/ with this script.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BUNDLE = ROOT / "assets" / "shia-databases.zip"
DEFAULT_OUTPUT = ROOT / "assets" / "databases"
MANIFEST_PATH = ROOT / "assets" / "database-manifest.json"

EXPECTED_DATABASES = {
    "Tahzeeb.db",
    "alkafi.db",
    "alkhisal.db",
    "hakam.db",
    "hidaya.db",
    "hikmatprophet.db",
    "imam.db",
    "kamaledeen.db",
    "maniakbar.db",
    "manlahyahzur.db",
    "mezan.db",
    "swab.db",
    "towheed.db",
    "wasail.db",
}
REQUIRED_COLUMNS = {
    "Parags": {"ID", "txt", "Secid", "paganum", "mean"},
    "Sections": {"ID", "title", "Chapid", "Secid"},
    "Chaps": {"ID", "cid", "title", "bookid"},
}


class DatabaseBundleError(RuntimeError):
    """Raised when a bundle is incomplete, unsafe, or contains invalid SQLite."""


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_database(path: Path) -> dict[str, int | str]:
    """Check SQLite integrity and return the known table row counts."""
    uri = f"file:{path.resolve().as_posix()}?mode=ro"
    try:
        with sqlite3.connect(uri, uri=True) as connection:
            check = connection.execute("PRAGMA quick_check").fetchone()
            if not check or check[0] != "ok":
                raise DatabaseBundleError(f"SQLite quick_check failed for {path.name}: {check}")

            tables = {
                row[0]
                for row in connection.execute(
                    "SELECT name FROM sqlite_master WHERE type = 'table'"
                )
            }
            counts: dict[str, int | str] = {"name": path.name}
            for table, expected_columns in REQUIRED_COLUMNS.items():
                if table not in tables:
                    raise DatabaseBundleError(f"{path.name} is missing table {table!r}")
                actual_columns = {
                    row[1] for row in connection.execute(f'PRAGMA table_info("{table}")')
                }
                missing = expected_columns - actual_columns
                if missing:
                    raise DatabaseBundleError(
                        f"{path.name}.{table} is missing columns: {sorted(missing)}"
                    )
                counts[table] = int(connection.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0])
            return counts
    except sqlite3.DatabaseError as exc:
        raise DatabaseBundleError(f"Could not open {path.name} as SQLite: {exc}") from exc


def unpack_databases(bundle: Path = DEFAULT_BUNDLE, output_dir: Path = DEFAULT_OUTPUT) -> list[dict]:
    """Extract expected files to a staging directory, validate, then install them."""
    bundle = bundle.resolve()
    output_dir = output_dir.resolve()
    if not bundle.is_file():
        raise DatabaseBundleError(f"Database bundle not found: {bundle}")

    try:
        archive = zipfile.ZipFile(bundle)
    except (OSError, zipfile.BadZipFile) as exc:
        raise DatabaseBundleError(f"Invalid database ZIP bundle: {exc}") from exc

    with archive:
        infos = [info for info in archive.infolist() if not info.is_dir()]
        names = [PurePosixPath(info.filename).name for info in infos]
        if len(infos) != len(EXPECTED_DATABASES) or set(names) != EXPECTED_DATABASES:
            raise DatabaseBundleError(
                "Bundle contents do not match the verified database set. "
                f"Expected {sorted(EXPECTED_DATABASES)}, found {sorted(names)}"
            )
        # Require flat, known names; do not trust archive paths.
        for info in infos:
            name = PurePosixPath(info.filename).name
            if PurePosixPath(info.filename).name != info.filename or name not in EXPECTED_DATABASES:
                raise DatabaseBundleError(f"Unsafe or unexpected archive path: {info.filename!r}")
            if info.file_size > 100 * 1024 * 1024:
                raise DatabaseBundleError(f"Unexpectedly large database entry: {name}")

        output_dir.parent.mkdir(parents=True, exist_ok=True)
        stage = Path(tempfile.mkdtemp(prefix=".shia-databases-", dir=output_dir.parent))
        try:
            records: list[dict] = []
            for info in infos:
                name = PurePosixPath(info.filename).name
                staged = stage / name
                with archive.open(info, "r") as source, staged.open("wb") as target:
                    shutil.copyfileobj(source, target, length=1024 * 1024)
                record = validate_database(staged)
                record["size_bytes"] = staged.stat().st_size
                record["sha256"] = _sha256(staged)
                records.append(record)

            expected_manifest = {}
            if MANIFEST_PATH.exists():
                expected_manifest = {
                    row["name"]: row
                    for row in json.loads(MANIFEST_PATH.read_text(encoding="utf-8")).get(
                        "databases", []
                    )
                }
            for record in records:
                expected = expected_manifest.get(record["name"])
                if expected and record["sha256"] != expected.get("sha256"):
                    raise DatabaseBundleError(f"Checksum mismatch for {record['name']}")
                if expected:
                    for table in REQUIRED_COLUMNS:
                        if record[table] != expected.get(table):
                            raise DatabaseBundleError(
                                f"Unexpected {table} row count in {record['name']}: "
                                f"{record[table]} != {expected.get(table)}"
                            )

            output_dir.mkdir(parents=True, exist_ok=True)
            for record in records:
                name = record["name"]
                destination = output_dir / name
                if destination.exists() and _sha256(destination) == record["sha256"]:
                    continue
                os.replace(stage / name, destination)
            return sorted(records, key=lambda row: str(row["name"]).lower())
        finally:
            shutil.rmtree(stage, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, default=DEFAULT_BUNDLE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    try:
        records = unpack_databases(args.bundle, args.output)
    except DatabaseBundleError as exc:
        parser.error(str(exc))
    for record in records:
        print(
            f"{record['name']}: {record['Parags']} paragraphs, "
            f"{record['Sections']} sections, {record['Chaps']} chapters "
            f"({record['size_bytes']:,} bytes; SHA-256 {record['sha256'][:12]}…)"
        )
    print(f"Validated {len(records)} SQLite databases in {args.output.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
