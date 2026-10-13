#!/usr/bin/env python3
r"""Run the Flutter client's own SQL against the real databases.

The Dart repository builds every query by hand and CI images that only ship
Python have no Dart VM to compile it. This script closes that gap: it extracts
each statement verbatim from ``app/lib/library_repository.dart`` (so the check
fails as soon as the Dart and the schema drift apart) and executes it against the
shipped SQLite files. It then rebuilds a miniature copy of the on-device search
index — including the FTS5 mirror — and proves a bilingual query finds records.

    python3 scripts/verify_client_sql.py                    # unpack bundle + extras
    python3 scripts/verify_client_sql.py --database-dir assets/databases
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from database_specs import BY_NAME  # noqa: E402
from prepare_databases import collect_databases  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = ROOT / "app" / "lib" / "library_repository.dart"
TRIPLE = "'" * 3

failures: list[str] = []


def check(label: str, condition: bool, detail: str = "") -> None:
    print(f"{'PASS' if condition else 'FAIL'} {label}{f' — {detail}' if detail else ''}")
    if not condition:
        failures.append(label)


def _string_literals(source: str):
    """Yield every string literal in a Dart file, in order.

    Triple-quoted SQL blocks contain single quotes (``COALESCE(x, '')``), so the
    scan has to consume a whole literal at a time instead of hunting for the
    nearest delimiter.
    """
    i = 0
    length = len(source)
    while i < length:
        char = source[i]
        if char == "/" and source.startswith("//", i):
            newline = source.find("\n", i)
            i = length if newline == -1 else newline + 1
            continue
        if char == "/" and source.startswith("/*", i):
            end = source.find("*/", i)
            i = length if end == -1 else end + 2
            continue
        if char in ("'", '"'):
            if source.startswith(char * 3, i):
                end = source.find(char * 3, i + 3)
                if end == -1:
                    return
                yield source[i + 3:end]
                i = end + 3
                continue
            cursor = i + 1
            closed = -1
            while cursor < length:
                if source[cursor] == "\\":
                    cursor += 2
                    continue
                if source[cursor] == char:
                    closed = cursor
                    break
                if source[cursor] == "\n":
                    break
                cursor += 1
            if closed == -1:
                i += 1
                continue
            yield source[i + 1:closed]
            i = closed + 1
            continue
        i += 1


def extract_query(fragment: str) -> str:
    """Return the Dart string literal that contains `fragment`, verbatim."""
    source = REPOSITORY.read_text(encoding="utf-8")
    for literal in _string_literals(source):
        if fragment in literal:
            return literal.strip()
    raise KeyError(f"statement not found in {REPOSITORY.name}: {fragment[:60]!r}")


def run(connection: sqlite3.Connection, fragment: str, params: tuple = ()) -> list:
    query = extract_query(fragment)
    try:
        return connection.execute(query, params).fetchall()
    except sqlite3.Error as exc:
        check(f"query near {fragment[:48]!r} executes", False, str(exc))
        return []


def hadith(connection: sqlite3.Connection) -> None:
    rows = run(
        connection,
        "WHERE LENGTH(COALESCE(p.txt, '')) > 0 OR LENGTH(COALESCE(p.mean, '')) > 0",
        (400, 0),
    )
    check("hadith: index query returns bilingual rows", len(rows) > 0, f"{len(rows)} rows in page 1")
    if not rows:
        return
    first = run(connection, "WHERE p.ID = ?", (rows[0][0],))
    check("hadith: record lookup by ID", len(first) == 1)
    sections = run(connection, "WHERE p.Secid = ?", (rows[0][2],))
    check("hadith: section passages load", len(sections) > 0, f"{len(sections)} records")
    chapters = run(connection, "SELECT ID, cid, title FROM Chaps ORDER BY cid")
    check("hadith: chapter list", len(chapters) > 0, f"{len(chapters)} chapters")


def quran(connection: sqlite3.Connection) -> None:
    surahs = run(connection, "SELECT Id, Name, Nozol, Verse, revel FROM ChapterProperty ORDER BY Id")
    check("quran: surah list", len(surahs) == 114, f"{len(surahs)}")
    verses = run(connection, "WHERE q.chapter = ?", (2,))
    check("quran: al-Baqarah verses", len(verses) == 286, f"{len(verses)}")
    juz = run(connection, "WHERE q.juz = ?", (30,))
    check("quran: juz 30 verses", len(juz) > 500, f"{len(juz)}")
    page = run(connection, "WHERE q.page = ?", (1,))
    check("quran: mushaf page 1", len(page) == 7, f"{len(page)}")
    index = run(connection, "FROM (SELECT juz, MIN(ID) AS first_id FROM Quran GROUP BY juz) AS j")
    check("quran: juz index", len(index) == 30, f"{len(index)}")
    record = run(connection, "WHERE q.ID = ?", (1,))
    check("quran: verse lookup by ID", len(record) == 1 and bool(record[0][2]))


def dua(connection: sqlite3.Connection) -> None:
    categories = run(connection, "FROM M_items GROUP BY M_cat_id ORDER BY M_cat_id")
    check("mafatih: six chapters", len(categories) == 6, f"{len(categories)}")
    items = run(connection, "WHERE m.M_cat_id = ?", (2,))
    check("mafatih: chapter items with line counts", len(items) > 0, f"{len(items)} items")
    featured = run(connection, "WHERE m.M_montakhab = 1 AND m.M_type = 1", (12,))
    check("mafatih: featured supplications", len(featured) > 0, f"{len(featured)}")
    leaf = next((row for row in items if row[3] == 1), None)
    check("mafatih: chapter contains readable items", leaf is not None)
    if leaf is None:
        return
    item = run(
        connection,
        "SELECT rowid AS row_id, _id, M_name, M_cat_id FROM M_items WHERE rowid = ?",
        (leaf[0],),
    )
    check("mafatih: item lookup by rowid", len(item) == 1)
    if not item:
        return
    lines = run(connection, "FROM Lines WHERE L_M_id = ?", (item[0][1],))
    check("mafatih: supplication lines", len(lines) > 0, f"{len(lines)} lines")
    indexed = run(connection, "SELECT m.rowid AS record_id, m.M_name AS section_title", (400, 0))
    check(
        "mafatih: GROUP_CONCAT index query",
        len(indexed) > 0 and bool(indexed[0][4]),
        f"{len(indexed[0][4] or '')} characters of Arabic text for the first item",
    )


def balagha(connection: sqlite3.Connection) -> None:
    sections = run(connection, "FROM balaghatoc AS t\n      GROUP BY t.TypeID ORDER BY t.TypeID")
    check("balagha: five divisions", len(sections) == 5, f"{len(sections)}")
    entries = run(connection, "WHERE t.TypeID = ?", (1,))
    check("balagha: khutba entries", len(entries) == 238, f"{len(entries)}")
    prose = run(connection, "FROM balaghatext_hawashi WHERE Type = 5 AND TypeNo = ?", (1,))
    check("balagha: introduction prose", len(prose) > 10, f"{len(prose)} paragraphs")
    main = run(connection, "WHERE x.Type = ? AND x.TypeNo = ?", (1, 3))
    check("balagha: khutba 3 paragraphs", len(main) > 10, f"{len(main)}")
    footnotes = run(connection, "WHERE Type = ? AND TypeNo = ? AND ParaNo IS NOT NULL", (1, 3))
    check("balagha: footnotes for khutba 3", len(footnotes) > 0, f"{len(footnotes)}")
    intro = run(connection, "FROM balaghatext_muqadamat WHERE Type = ?", (1,))
    check("balagha: section introduction", len(intro) > 10, f"{len(intro)}")
    lookup = run(connection, "WHERE x.ID = ?", (44,))
    check("balagha: paragraph lookup by ID", len(lookup) == 1)
    # Introductions are keyed by negative ids, resolved back through hawashi.
    prose_ids = run(connection, "FROM balaghatext_hawashi WHERE Type = 5 AND TypeNo = ?", (1,))
    prose_id = prose_ids[0][0] if prose_ids else 0
    # The client stores recordId = -hawashiID and binds `-recordId` back.
    resolved = run(connection, "WHERE h.Type = 5 AND h.ID = ?", (prose_id,))
    check(
        "balagha: introduction resolves from a negative id",
        len(resolved) == 1 and bool(resolved[0][1]),
        f"recordId {-prose_id} -> {len(resolved)} row, "
        f"{len(str(resolved[0][1])) if resolved else 0} characters",
    )
    # Negating a hawashi id can only be safe if both id spaces are positive.
    lowest = connection.execute(
        "SELECT (SELECT MIN(ID) FROM balaghatext), (SELECT MIN(ID) FROM balaghatext_hawashi)"
    ).fetchone()
    check(
        "balagha: paragraph and footnote id spaces are positive",
        lowest is not None and min(lowest[0], lowest[1]) > 0,
        f"min balaghatext.ID={lowest[0]}, min hawashi.ID={lowest[1]}",
    )


def build_index(paths: dict[str, Path]) -> sqlite3.Connection:
    """Recreate the on-device search index (search_docs + FTS5) in memory."""
    index = sqlite3.connect(":memory:")
    index.execute(
        extract_query("CREATE TABLE IF NOT EXISTS search_docs").replace(
            "CREATE TABLE IF NOT EXISTS", "CREATE TABLE"
        )
    )
    index.execute(
        "CREATE VIRTUAL TABLE search_fts USING fts5("
        "chapter_title, section_title, arabic, urdu, content='', "
        "tokenize='unicode61 remove_diacritics 0')"
    )
    fragments = {
        "alkafi": "WHERE LENGTH(COALESCE(p.txt, '')) > 0 OR LENGTH(COALESCE(p.mean, '')) > 0",
        "quran": "FROM Quran AS q\n          LEFT JOIN ChapterProperty AS cp ON cp.Id = q.chapter\n          ORDER BY q.ID",
        "mafatih": "SELECT m.rowid AS record_id, m.M_name AS section_title",
        "nahjul_balagha": "SELECT x.ID AS record_id, x.AR AS arabic, x.UR AS urdu, x.ParaNo AS page_no",
    }
    total = 0
    for source_key, fragment in fragments.items():
        query = extract_query(fragment)
        connection = sqlite3.connect(f"file:{paths[source_key]}?mode=ro", uri=True)
        try:
            cursor = connection.execute(query, (100000, 0))
            columns = [description[0] for description in cursor.description]
            rows = cursor.fetchall()
        finally:
            connection.close()
        for row in rows:
            total += 1
            record = dict(zip(columns, row))
            arabic = str(record.get("arabic") or "")
            urdu = str(record.get("urdu") or "")
            title = str(record.get("section_title") or record.get("surah_name") or "")
            index.execute(
                "INSERT INTO search_docs (id, book, record_id, chapter_title, section_title, "
                "container_type, container_id, norm_text) VALUES (?,?,?,?,?,?,?,?)",
                (
                    total,
                    source_key,
                    record.get("record_id"),
                    title,
                    title,
                    record.get("container_type"),
                    record.get("container_id"),
                    f"{arabic} {urdu}".lower(),
                ),
            )
            index.execute(
                "INSERT INTO search_fts(rowid, chapter_title, section_title, arabic, urdu) "
                "VALUES (?,?,?,?,?)",
                (total, title, title, arabic, urdu),
            )
    check("index: rows written from all four sources", total > 1000, f"{total} rows")
    return index


def search_probe(index: sqlite3.Connection) -> None:
    probes = (
        ('"الحسين"*', "Arabic hadith term"),
        ('"نماز"*', "Urdu term"),
    )
    for expression, label in probes:
        rows = index.execute(
            "SELECT d.book, d.record_id FROM search_fts "
            "JOIN search_docs AS d ON d.id = search_fts.rowid "
            "WHERE search_fts MATCH ? ORDER BY bm25(search_fts) LIMIT 5",
            (expression,),
        ).fetchall()
        check(f"search: FTS5 finds {label}", len(rows) > 0, f"{len(rows)} hits, first: {rows[:2]}")


def run_checks(paths: dict[str, Path]) -> None:
    needed = ("alkafi", "quran", "mafatih", "nahjul_balagha")
    missing = [key for key in needed if key not in paths]
    if missing:
        raise SystemExit(f"Missing databases for client SQL check: {missing}")

    for key, checks in (
        ("alkafi", hadith),
        ("quran", quran),
        ("mafatih", dua),
        ("nahjul_balagha", balagha),
    ):
        connection = sqlite3.connect(f"file:{paths[key]}?mode=ro", uri=True)
        try:
            checks(connection)
        finally:
            connection.close()

    index = build_index(paths)
    search_probe(index)
    index.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database-dir", type=Path, default=None)
    args = parser.parse_args()

    if not REPOSITORY.is_file():
        raise SystemExit(f"{REPOSITORY} not found")

    if args.database_dir:
        paths = {
            spec.key: args.database_dir / spec.name
            for spec in BY_NAME.values()
            if (args.database_dir / spec.name).is_file()
        }
        run_checks(paths)
    else:
        with collect_databases() as collected:
            run_checks({spec.key: path for spec, path in collected})

    if failures:
        raise SystemExit(f"{len(failures)} client SQL check(s) failed: {', '.join(failures)}")
    print("All client SQL checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
