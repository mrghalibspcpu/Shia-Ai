"""Local, citation-preserving search over the recovered Arabic/Urdu databases."""
from __future__ import annotations

import hashlib
import os
import re
import sqlite3
import tempfile
import threading
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlencode

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATABASE_DIR = ROOT / "assets" / "databases"
DEFAULT_INDEX_PATH = ROOT / ".cache" / "shia-ai" / "search-index.sqlite3"
INDEX_VERSION = "2"

# Normalize common Arabic/Persian/Urdu glyph variants without transliterating
# or conflating distinct words. Diacritics and tatweel are removed separately.
_VARIANTS = str.maketrans(
    {
        "آ": "ا",
        "أ": "ا",
        "إ": "ا",
        "ٱ": "ا",
        "ك": "ک",
        "ي": "ی",
        "ى": "ی",
    }
)
_TOKEN_RE = re.compile(r"[\w]+", re.UNICODE)


@dataclass(frozen=True)
class Passage:
    source_id: str
    database: str
    book: str
    paragraph_id: int | str
    section_id: int | str | None
    page_no: int | str | None
    chapter_title: str
    section_title: str
    arabic: str
    urdu: str
    relevance: float

    @property
    def reader_target(self) -> dict[str, int | str | None]:
        return {
            "book": self.book,
            "record_id": self.paragraph_id,
            "section_id": self.section_id,
            "page": self.page_no,
        }

    @property
    def check_url(self) -> str:
        query = urlencode(
            {
                "book": self.book,
                "record_id": self.paragraph_id,
                "section_id": self.section_id if self.section_id is not None else "",
                "page": self.page_no if self.page_no is not None else "",
            }
        )
        # This is the app deep-link contract; the Flutter client still needs to
        # register the scheme and route it to its native reader.
        return f"shiaai://reader?{query}"

    @property
    def citation(self) -> str:
        parts = [self.database]
        if self.chapter_title:
            parts.append(self.chapter_title)
        if self.section_title:
            parts.append(self.section_title)
        parts.append(f"record {self.paragraph_id}")
        if self.page_no not in (None, ""):
            parts.append(f"page {self.page_no}")
        return " · ".join(parts)

    def as_dict(self) -> dict:
        return {
            "source_id": self.source_id,
            "database": self.database,
            "book": self.book,
            "paragraph_id": self.paragraph_id,
            "section_id": self.section_id,
            "page_no": self.page_no,
            "chapter_title": self.chapter_title,
            "section_title": self.section_title,
            "arabic": self.arabic,
            "urdu": self.urdu,
            "citation": self.citation,
            "reader_target": self.reader_target,
            "check_url": self.check_url,
            "relevance": self.relevance,
        }


def normalize_text(value: str | None) -> str:
    """Fold Arabic/Urdu spelling variants for matching, preserving source text."""
    text = unicodedata.normalize("NFKC", value or "").translate(_VARIANTS)
    output: list[str] = []
    for char in text:
        if char == "ـ" or unicodedata.category(char).startswith("M"):
            continue
        if char.isalnum() or char == "_":
            output.append(char)
        else:
            output.append(" ")
    return " ".join("".join(output).split())


def _source_signature(database_files: list[Path]) -> str:
    digest = hashlib.sha256()
    for path in database_files:
        digest.update(path.name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(str(path.stat().st_size).encode("ascii"))
        digest.update(b"\0")
        file_digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                file_digest.update(chunk)
        digest.update(file_digest.digest())
    return digest.hexdigest()


def _as_locator(value):
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return str(value)


class SearchIndex:
    """Build/cache an FTS5 index without modifying the original SQLite files."""

    def __init__(
        self,
        database_dir: Path | str = DEFAULT_DATABASE_DIR,
        index_path: Path | str = DEFAULT_INDEX_PATH,
    ) -> None:
        self.database_dir = Path(database_dir).resolve()
        self.index_path = Path(index_path).resolve()
        self._lock = threading.RLock()
        self._connection: sqlite3.Connection | None = None
        database_files = sorted(self.database_dir.glob("*.db"), key=lambda p: p.name.lower())
        if not database_files:
            raise FileNotFoundError(
                f"No SQLite databases found in {self.database_dir}. "
                "Run `python3 scripts/prepare_databases.py` first."
            )
        self._database_files = database_files
        self._signature = _source_signature(database_files)
        self.index_path.parent.mkdir(parents=True, exist_ok=True)
        if not self._cache_is_current():
            self._build_index()
        self._connection = sqlite3.connect(self.index_path, check_same_thread=False)
        self._connection.row_factory = sqlite3.Row

    def _cache_is_current(self) -> bool:
        if not self.index_path.is_file():
            return False
        try:
            with sqlite3.connect(f"file:{self.index_path}?mode=ro", uri=True) as connection:
                version = connection.execute("PRAGMA user_version").fetchone()[0]
                source = connection.execute(
                    "SELECT value FROM metadata WHERE key = 'source_signature'"
                ).fetchone()
                return version == int(INDEX_VERSION) and source and source[0] == self._signature
        except sqlite3.DatabaseError:
            return False

    def _build_index(self) -> None:
        temp_dir = self.index_path.parent
        fd, temp_name = tempfile.mkstemp(prefix="search-index-", suffix=".sqlite3", dir=temp_dir)
        os.close(fd)
        temp_path = Path(temp_name)
        connection = sqlite3.connect(temp_path)
        try:
            connection.execute("PRAGMA journal_mode=OFF")
            connection.execute("PRAGMA synchronous=OFF")
            connection.execute("PRAGMA temp_store=MEMORY")
            connection.executescript(
                """
                CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
                CREATE TABLE passages (
                    doc_id INTEGER PRIMARY KEY,
                    book TEXT NOT NULL,
                    database TEXT NOT NULL,
                    paragraph_id TEXT NOT NULL,
                    section_id TEXT,
                    page_no TEXT,
                    chapter_title TEXT NOT NULL,
                    section_title TEXT NOT NULL,
                    arabic TEXT NOT NULL,
                    urdu TEXT NOT NULL
                );
                CREATE VIRTUAL TABLE passages_fts USING fts5(
                    chapter_title, section_title, arabic, urdu,
                    tokenize = 'unicode61 remove_diacritics 0'
                );
                """
            )
            connection.execute("PRAGMA user_version = 1")
            connection.execute(
                "INSERT INTO metadata(key, value) VALUES('source_signature', ?)",
                (self._signature,),
            )
            connection.commit()

            document_insert = """INSERT INTO passages(
                doc_id, book, database, paragraph_id, section_id, page_no,
                chapter_title, section_title, arabic, urdu
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""
            fts_insert = """INSERT INTO passages_fts(
                rowid, chapter_title, section_title, arabic, urdu
            ) VALUES (?, ?, ?, ?, ?)"""
            next_id = 1
            batch_docs: list[tuple] = []
            batch_fts: list[tuple] = []

            for database_path in self._database_files:
                source_uri = f"file:{database_path.as_posix()}?mode=ro"
                with sqlite3.connect(source_uri, uri=True) as source:
                    source.row_factory = sqlite3.Row
                    rows = source.execute(
                        """
                        SELECT p.ID AS paragraph_id,
                               p.txt AS arabic,
                               p.Secid AS section_id,
                               p.paganum AS page_no,
                               p.mean AS urdu,
                               s.title AS section_title,
                               c.title AS chapter_title
                        FROM Parags AS p
                        LEFT JOIN Sections AS s ON s.Secid = p.Secid
                        LEFT JOIN Chaps AS c ON c.cid = s.Chapid
                        ORDER BY p.rowid
                        """
                    )
                    book = database_path.stem.lower()
                    database_name = database_path.name
                    for row in rows:
                        arabic = str(row["arabic"] or "")
                        urdu = str(row["urdu"] or "")
                        chapter = str(row["chapter_title"] or "")
                        section = str(row["section_title"] or "")
                        # Keep empty introductory rows in the reader data table
                        # but avoid adding an entirely empty FTS document.
                        batch_docs.append(
                            (
                                next_id,
                                book,
                                database_name,
                                str(row["paragraph_id"]),
                                None if row["section_id"] in (None, "") else str(row["section_id"]),
                                None if row["page_no"] in (None, "") else str(row["page_no"]),
                                chapter,
                                section,
                                arabic,
                                urdu,
                            )
                        )
                        normalized = (
                            normalize_text(chapter),
                            normalize_text(section),
                            normalize_text(arabic),
                            normalize_text(urdu),
                        )
                        if any(normalized):
                            batch_fts.append((next_id, *normalized))
                        next_id += 1
                        if len(batch_docs) >= 1000:
                            connection.executemany(document_insert, batch_docs)
                            connection.executemany(fts_insert, batch_fts)
                            connection.commit()
                            batch_docs.clear()
                            batch_fts.clear()
            if batch_docs:
                connection.executemany(document_insert, batch_docs)
                if batch_fts:
                    connection.executemany(fts_insert, batch_fts)
                connection.commit()

            connection.execute("CREATE INDEX passages_book_record ON passages(book, paragraph_id)")
            connection.commit()
            connection.close()
            os.replace(temp_path, self.index_path)
        except Exception:
            connection.close()
            temp_path.unlink(missing_ok=True)
            raise

    def get_passage(self, book: str, paragraph_id: int | str) -> Passage | None:
        """Fetch one exact reader record from the persistent local corpus index."""
        book_key = str(book).strip().lower()
        record_key = str(paragraph_id).strip()
        if not book_key or not record_key or len(record_key) > 64:
            return None
        with self._lock:
            assert self._connection is not None
            row = self._connection.execute(
                """
                SELECT p.*, 0.0 AS rank
                FROM passages AS p
                WHERE p.book = ? AND p.paragraph_id = ?
                ORDER BY p.doc_id
                LIMIT 1
                """,
                (book_key, record_key),
            ).fetchone()
        return self._passage(row) if row is not None else None

    def search(self, query: str, limit: int = 8) -> list[Passage]:
        normalized = normalize_text(query[:500] if isinstance(query, str) else "")
        tokens = list(dict.fromkeys(_TOKEN_RE.findall(normalized)))
        if not tokens:
            return []
        limit = max(1, min(int(limit), 30))
        quoted = [f'"{token.replace(chr(34), chr(34) * 2)}"' for token in tokens]
        strict_query = " AND ".join(quoted)
        broad_query = " OR ".join(quoted)
        with self._lock:
            assert self._connection is not None
            rows = self._run_query(strict_query, limit)
            if not rows and broad_query != strict_query:
                rows = self._run_query(broad_query, limit)
        return [self._passage(row) for row in rows]

    def _run_query(self, expression: str, limit: int) -> list[sqlite3.Row]:
        assert self._connection is not None
        try:
            return self._connection.execute(
                """
                SELECT p.*,
                       bm25(passages_fts, 0.35, 0.6, 1.25, 1.25) AS rank
                FROM passages_fts
                JOIN passages AS p ON p.doc_id = passages_fts.rowid
                WHERE passages_fts MATCH ?
                ORDER BY rank, p.book, p.paragraph_id
                LIMIT ?
                """,
                (expression, limit),
            ).fetchall()
        except sqlite3.OperationalError as exc:
            # Invalid FTS expressions are treated as no matches; caller text is
            # never interpolated into SQL.
            if "fts5" in str(exc).lower() or "syntax" in str(exc).lower():
                return []
            raise

    @staticmethod
    def _passage(row: sqlite3.Row) -> Passage:
        paragraph_id = _as_locator(row["paragraph_id"])
        if paragraph_id is None:
            paragraph_id = str(row["paragraph_id"])
        section_id = _as_locator(row["section_id"])
        page_no = _as_locator(row["page_no"])
        return Passage(
            source_id=f"{row['book']}:{paragraph_id}",
            database=row["database"],
            book=row["book"],
            paragraph_id=paragraph_id,
            section_id=section_id,
            page_no=page_no,
            chapter_title=row["chapter_title"],
            section_title=row["section_title"],
            arabic=row["arabic"],
            urdu=row["urdu"],
            relevance=max(0.0, -float(row["rank"])),
        )

    def close(self) -> None:
        with self._lock:
            if self._connection is not None:
                self._connection.close()
                self._connection = None

    def __enter__(self) -> "SearchIndex":
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        self.close()
