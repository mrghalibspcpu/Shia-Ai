#!/usr/bin/env python3
"""Run corpus-level smoke checks for bilingual search and reader citations."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from shia_ai.search import DEFAULT_DATABASE_DIR, DEFAULT_INDEX_PATH, SearchIndex, normalize_text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database-dir", type=Path, default=DEFAULT_DATABASE_DIR)
    parser.add_argument("--index", type=Path, default=DEFAULT_INDEX_PATH)
    args = parser.parse_args()
    with SearchIndex(args.database_dir, args.index) as index:
        checks = (
            ("الشيخ السعيد", "arabic"),
            ("امیرالمومنین علیہ السلام", "urdu"),
        )
        for query, expected_field in checks:
            results = index.search(query, limit=5)
            if not results:
                raise SystemExit(f"No results for corpus smoke query: {query}")
            normalized_terms = normalize_text(query).split()
            matching = [
                result
                for result in results
                if all(
                    token in normalize_text(getattr(result, expected_field))
                    for token in normalized_terms
                )
            ]
            # Search terms may be split between the Arabic source and Urdu
            # translation in one row, so also verify the combined record text.
            if not matching:
                matching = [
                    result
                    for result in results
                    if all(
                        token in normalize_text(result.arabic + " " + result.urdu)
                        for token in normalized_terms
                    )
                ]
            if not matching:
                raise SystemExit(f"Search returned no source-text match for: {query}")
            best = matching[0]
            print(f"PASS {expected_field}: {query}")
            print(f"  {best.citation}")
            print(f"  Check target: {best.reader_target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
