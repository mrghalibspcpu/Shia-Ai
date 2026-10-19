#!/usr/bin/env python3
"""Add the provided FehmulFasaha Urdu translation without changing matan or notes.

The Drive export has 797 numbered khutba/letter/wisdom entries and 1,100 Urdu
translation blocks, but its ``arabic_matan`` column is empty in every block.
We therefore pair at the reliable canonical entry key (category + entry
number), not by guessing paragraph boundaries. The original Arabic and all
footnotes remain byte-for-byte untouched; the app hides only the old body-UR
cells and displays these replacement blocks after that entry's Arabic text.

    python3 scripts/replace_balagha_translation.py \
      --database assets/nahjul_balagha_v2.db \
      --translation 'google_drive/FehmulFasahaTarjumaNehjulBalagha.sqlite'
"""
from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

CATEGORY_TYPES = {"Khutba": 1, "Maktoob": 2, "Hikmat": 3}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--translation", type=Path, required=True)
    args = parser.parse_args()
    if not args.database.is_file() or not args.translation.is_file():
        raise SystemExit("Both the installed Nahj database and Drive translation must exist.")

    app = sqlite3.connect(args.database)
    supplied = sqlite3.connect(f"file:{args.translation.resolve()}?mode=ro", uri=True)
    try:
        expected: set[tuple[int, int]] = set()
        for category, number in supplied.execute("SELECT category,number FROM entries"):
            kind = CATEGORY_TYPES.get(category)
            if kind is None:
                raise SystemExit(f"Unsupported source category: {category}")
            expected.add((kind, number))
        actual = {(kind, number) for kind, number in app.execute(
            "SELECT TypeID,TypeNo FROM balaghatoc WHERE TypeID IN (1,2,3)")}
        missing = expected - actual
        extra = actual - expected
        if missing or extra:
            raise SystemExit(f"Entry key mismatch; source-only={sorted(missing)[:10]}, target-only={sorted(extra)[:10]}")
        blank_matan = supplied.execute("SELECT COUNT(*) FROM paragraphs WHERE TRIM(arabic_matan)<>''").fetchone()[0]
        if blank_matan:
            raise SystemExit("The source format changed; review Arabic-matan alignment before importing.")

        app.execute("""
          CREATE TABLE IF NOT EXISTS balagha_replacement_translation (
            id INTEGER PRIMARY KEY,
            type INTEGER NOT NULL,
            type_no INTEGER NOT NULL,
            sort_order INTEGER NOT NULL,
            urdu TEXT NOT NULL,
            UNIQUE(type,type_no,sort_order)
          )
        """)
        # The existing table does not define the composite key as unique in
        # SQLite, so keep referential integrity without an invalid FK target.
        # (SQLite tolerates the declaration but the writes do not require it.)
        app.execute("DELETE FROM balagha_replacement_translation")
        rows = supplied.execute("""
          SELECT e.category,e.number,p.sort_order,p.urdu_translation
          FROM entries e JOIN paragraphs p ON p.entry_id=e.id
          ORDER BY e.sort_order,p.sort_order
        """).fetchall()
        next_id = 1
        app.executemany("""
          INSERT INTO balagha_replacement_translation(id,type,type_no,sort_order,urdu)
          VALUES(?,?,?,?,?)
        """, [(index, CATEGORY_TYPES[category], number, order, text)
              for index, (category, number, order, text) in enumerate(rows, 1)])
        counts = app.execute("SELECT type,COUNT(DISTINCT type_no),COUNT(*) FROM balagha_replacement_translation GROUP BY type ORDER BY type").fetchall()
        if sum(row[1] for row in counts) != 797 or sum(row[2] for row in counts) != 1100:
            raise SystemExit(f"Unexpected imported translation totals: {counts}")
        app.execute("CREATE INDEX IF NOT EXISTS shia_balagha_replacement_locate ON balagha_replacement_translation(type,type_no,sort_order)")
        app.execute("INSERT OR REPLACE INTO metadata(key,value) VALUES('urdu_translation_source','FehmulFasahaTarjumaNehjulBalagha.sqlite; 797 entry keys; 1100 blocks')") if app.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='metadata'").fetchone() else None
        app.commit()
        result = app.execute("PRAGMA integrity_check").fetchone()[0]
        if result != "ok":
            raise RuntimeError(f"SQLite integrity check failed: {result}")
        print(f"Matched all {len(expected)} numbered entries; imported {len(rows)} Urdu blocks. Arabic and hawashi unchanged.")
    finally:
        app.close()
        supplied.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
