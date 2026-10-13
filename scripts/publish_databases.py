#!/usr/bin/env python3
"""Build the GitHub Release assets the app downloads on first launch.

The APK does not need to carry ~230 MiB of SQLite files. This script writes one
gzip-compressed file per database plus the manifest into ``dist/``; upload them
to a GitHub Release and the client fetches them from
``https://github.com/<owner>/<repo>/releases/latest/download/<file>``:

    python3 scripts/publish_databases.py
    gh release create databases-v1 dist/*.gz dist/database-manifest.json \\
        --title "Corpus v1" --notes "SQLite collections for the Shia library app"

Every download is verified against the SHA-256 recorded in the manifest, so a
corrupted or tampered file is rejected before the app opens it.
"""
from __future__ import annotations

import argparse
import gzip
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from database_specs import MANIFEST_PATH, ROOT  # noqa: E402
from prepare_databases import collect_databases, verify_against_manifest, build_records  # noqa: E402


def compress(source: Path, destination: Path, level: int = 6) -> int:
    with source.open("rb") as raw, gzip.open(destination, "wb", compresslevel=level) as packed:
        shutil.copyfileobj(raw, packed, length=1024 * 1024)
    return destination.stat().st_size


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    parser.add_argument("--level", type=int, default=6)
    args = parser.parse_args()

    if not MANIFEST_PATH.exists():
        raise SystemExit(
            f"{MANIFEST_PATH} is missing. Run: python3 scripts/prepare_databases.py --write-manifest"
        )

    args.output.mkdir(parents=True, exist_ok=True)
    total_raw = 0
    total_packed = 0
    with collect_databases() as collected:
        records = build_records(collected)
        verify_against_manifest(records)
        by_name = {record["name"]: record for record in records}
        for spec, path in collected:
            record = by_name[spec.name]
            destination = args.output / f"{spec.name}.gz"
            packed = compress(path, destination, args.level)
            total_raw += record["size_bytes"]
            total_packed += packed
            print(
                f"{spec.name}: {record['size_bytes']:,} -> {packed:,} bytes "
                f"({100 - packed * 100 // max(record['size_bytes'], 1)}% smaller)"
            )

    shutil.copyfile(MANIFEST_PATH, args.output / "database-manifest.json")
    print(
        f"\n{len(records)} files in {args.output.resolve()}: "
        f"{total_raw:,} -> {total_packed:,} bytes"
    )
    print(
        "\nUpload them with:\n"
        f"  gh release create databases-v1 {args.output}/*.gz "
        f"{args.output}/database-manifest.json \\\n"
        '      --title "Corpus v1" --notes "SQLite collections for the Shia library app"'
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
