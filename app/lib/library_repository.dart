import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

const int _searchIndexVersion = 2;
const int _indexPageSize = 400;

String normalizeArabicUrdu(String value) {
  var text = value.toLowerCase();
  text = text.replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF\u0640]'), '');
  text = text.replaceAll(RegExp(r'[\u0609-\u060D\u061B-\u061F\u066A-\u066D\u06D4\uFD3E\uFD3F]'), ' ');
  const variants = <String, String>{
    'آ': 'ا',
    'أ': 'ا',
    'إ': 'ا',
    'ٱ': 'ا',
    'ك': 'ک',
    'ي': 'ی',
    'ى': 'ی',
  };
  variants.forEach((from, to) => text = text.replaceAll(from, to));
  text = text.replaceAll(
    RegExp(r'[^a-z0-9\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFEFF]+'),
    ' ',
  );
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

class LibraryRepository {
  LibraryRepository();

  final Map<String, Database> _bookDatabases = {};
  Database? _searchDatabase;
  bool _ftsAvailable = false;
  String? _ftsEngine;
  bool _initialized = false;
  late String _databaseDirectory;

  bool get isInitialized => _initialized;
  bool get hasFastSearch => _ftsAvailable;

  Future<void> initialize({required void Function(double progress, String message) onProgress}) async {
    if (_initialized) return;
    final appDatabasePath = await getDatabasesPath();
    _databaseDirectory = p.join(appDatabasePath, 'shia_library');
    await Directory(_databaseDirectory).create(recursive: true);

    for (var i = 0; i < BookDefinition.all.length; i++) {
      final book = BookDefinition.all[i];
      final outputPath = p.join(_databaseDirectory, book.fileName);
      final output = File(outputPath);
      if (!await output.exists() || await output.length() == 0) {
        onProgress(i / BookDefinition.all.length * 0.25, 'کتب تیار ہو رہی ہیں — ${book.titleUrdu}');
        try {
          final data = await rootBundle.load('assets/databases/${book.fileName}');
          final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await output.writeAsBytes(bytes, flush: true);
        } on FlutterError catch (_) {
          throw StateError(
            'Database asset ${book.fileName} is missing. Run '
            '`python3 scripts/prepare_databases.py --output app/assets/databases` before building.',
          );
        }
      }
    }

    for (final book in BookDefinition.all) {
      await _ensureReaderIndexes(book);
    }

    final searchPath = p.join(_databaseDirectory, 'shia-search.sqlite');
    _searchDatabase = await openDatabase(
      searchPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE search_docs (
            id INTEGER PRIMARY KEY,
            book TEXT NOT NULL,
            record_id INTEGER NOT NULL,
            section_id TEXT,
            page_no TEXT,
            chapter_title TEXT NOT NULL,
            section_title TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX search_docs_book_record ON search_docs(book, record_id)');
        await db.execute('CREATE TABLE search_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );

    await _createFtsTable(_searchDatabase!, ifNotExists: true);

    final versionRows = await _searchDatabase!.query(
      'search_meta',
      where: 'key = ?',
      whereArgs: const ['index_version'],
      limit: 1,
    );
    final readyRows = await _searchDatabase!.query(
      'search_meta',
      where: 'key = ?',
      whereArgs: const ['ready'],
      limit: 1,
    );
    final versionMatches = versionRows.isNotEmpty &&
        versionRows.first['value']?.toString() == '$_searchIndexVersion';
    final isReady = readyRows.isNotEmpty && readyRows.first['value']?.toString() == '1';
    if (!versionMatches || !isReady) {
      await _buildSearchIndex(onProgress);
    }
    _initialized = true;
  }

  Future<void> _buildSearchIndex(void Function(double, String) onProgress) async {
    final index = _searchDatabase!;
    await index.delete('search_docs');
    await _createFtsTable(index);
    await index.delete('search_meta');
    await index.insert('search_meta', {'key': 'ready', 'value': '0'});

    var totalRows = 0;
    final sourceDatabases = <String, Database>{};
    for (final book in BookDefinition.all) {
      final source = await _openBook(book);
      sourceDatabases[book.key] = source;
      final countRows = await source.rawQuery('SELECT COUNT(*) AS count FROM Parags');
      totalRows += (countRows.first['count'] as int?) ?? 0;
    }
    if (totalRows == 0) throw StateError('No paragraph records were found in the bundled books.');

    var completed = 0;
    var nextId = 1;
    for (var bookNumber = 0; bookNumber < BookDefinition.all.length; bookNumber++) {
      final book = BookDefinition.all[bookNumber];
      final source = sourceDatabases[book.key]!;
      final countRows = await source.rawQuery('SELECT COUNT(*) AS count FROM Parags');
      final bookRows = (countRows.first['count'] as int?) ?? 0;
      for (var offset = 0; offset < bookRows; offset += _indexPageSize) {
        final rows = await source.rawQuery('''
          SELECT p.ID AS record_id, p.txt AS arabic, p.Secid AS section_id,
                 p.paganum AS page_no, p.mean AS urdu,
                 COALESCE(s.title, '') AS section_title,
                 COALESCE(c.title, '') AS chapter_title
          FROM Parags AS p
          LEFT JOIN Sections AS s ON s.Secid = p.Secid
          LEFT JOIN Chaps AS c ON c.cid = s.Chapid
          ORDER BY p.rowid
          LIMIT ? OFFSET ?
        ''', [_indexPageSize, offset]);

        final batch = index.batch();
        for (final row in rows) {
          final recordId = _asInt(row['record_id']);
          if (recordId == null) continue;
          final chapter = (row['chapter_title'] ?? '').toString();
          final section = (row['section_title'] ?? '').toString();
          final arabic = (row['arabic'] ?? '').toString();
          final urdu = (row['urdu'] ?? '').toString();
          final sectionId = row['section_id']?.toString();
          final page = row['page_no']?.toString();
          final id = nextId++;
          batch.insert('search_docs', {
            'id': id,
            'book': book.key,
            'record_id': recordId,
            'section_id': sectionId == null || sectionId.isEmpty ? null : sectionId,
            'page_no': page == null || page.isEmpty ? null : page,
            'chapter_title': chapter,
            'section_title': section,
          });
          if (_ftsAvailable) {
            final normalized = [
              normalizeArabicUrdu(chapter),
              normalizeArabicUrdu(section),
              normalizeArabicUrdu(arabic),
              normalizeArabicUrdu(urdu),
            ];
            if (normalized.any((part) => part.isNotEmpty)) {
              batch.rawInsert(
                'INSERT INTO search_fts(rowid, chapter_title, section_title, arabic, urdu) '
                'VALUES (?, ?, ?, ?, ?)',
                [id, ...normalized],
              );
            }
          }
        }
        await batch.commit(noResult: true);
        completed += rows.length;
        final progress = 0.25 + (0.75 * completed / totalRows);
        onProgress(progress.clamp(0.25, 0.99).toDouble(), 'متن کی تلاش تیار ہو رہی ہے — $completed / $totalRows');
      }
    }

    await index.insert('search_meta', {'key': 'index_version', 'value': '$_searchIndexVersion'});
    await index.insert('search_meta', {'key': 'ready', 'value': '1'});
    onProgress(1, 'کتب تیار ہیں');
  }

  Future<void> _ensureReaderIndexes(BookDefinition book) async {
    final database = await openDatabase(p.join(_databaseDirectory, book.fileName));
    try {
      await database.execute('CREATE INDEX IF NOT EXISTS shia_parags_record ON Parags(ID)');
      await database.execute('CREATE INDEX IF NOT EXISTS shia_parags_section ON Parags(Secid)');
      await database.execute('CREATE INDEX IF NOT EXISTS shia_sections_chapter ON Sections(Chapid)');
      await database.execute('CREATE INDEX IF NOT EXISTS shia_sections_record ON Sections(Secid)');
      await database.execute('CREATE INDEX IF NOT EXISTS shia_chapters_record ON Chaps(cid)');
    } finally {
      await database.close();
    }
  }

  Future<void> _createFtsTable(Database db, {bool ifNotExists = false}) async {
    if (ifNotExists) {
      final existing = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'search_fts' LIMIT 1",
      );
      if (existing.isNotEmpty) {
        final definition = (existing.first['sql'] ?? '').toString().toLowerCase();
        if (definition.contains('using fts5')) {
          _ftsEngine = 'fts5';
          _ftsAvailable = true;
          return;
        }
        if (definition.contains('using fts4')) {
          _ftsEngine = 'fts4';
          _ftsAvailable = true;
          return;
        }
        await db.execute('DROP TABLE search_fts');
      }
    } else {
      await db.execute('DROP TABLE IF EXISTS search_fts');
    }

    try {
      await db.execute('''
        CREATE VIRTUAL TABLE search_fts USING fts5(
          chapter_title, section_title, arabic, urdu,
          content='', tokenize='unicode61 remove_diacritics 0'
        )
      ''');
      _ftsEngine = 'fts5';
      _ftsAvailable = true;
      return;
    } catch (_) {
      // Android's system SQLite may expose FTS4 but omit the newer FTS5 module.
    }
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE search_fts USING fts4(
          chapter_title, section_title, arabic, urdu,
          content='', tokenize=unicode61
        )
      ''');
      _ftsEngine = 'fts4';
      _ftsAvailable = true;
    } catch (_) {
      _ftsEngine = null;
      _ftsAvailable = false;
    }
  }

  Future<Database> _openBook(BookDefinition book) async {
    final cached = _bookDatabases[book.key];
    if (cached != null && cached.isOpen) return cached;
    final path = p.join(_databaseDirectory, book.fileName);
    final database = await openDatabase(path, readOnly: true, singleInstance: false);
    _bookDatabases[book.key] = database;
    return database;
  }

  Future<List<Map<String, Object?>>> getChapters(BookDefinition book) async {
    final db = await _openBook(book);
    return db.rawQuery('SELECT ID, cid, title FROM Chaps ORDER BY cid');
  }

  Future<List<Map<String, Object?>>> getSections(BookDefinition book, int chapterId) async {
    final db = await _openBook(book);
    return db.rawQuery(
      'SELECT ID, title, Chapid, Secid FROM Sections WHERE Chapid = ? ORDER BY Secid',
      [chapterId],
    );
  }

  Future<List<Passage>> getSectionPassages(BookDefinition book, int sectionId) async {
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT p.ID AS record_id, p.txt AS arabic, p.Secid AS section_id,
             p.paganum AS page_no, p.mean AS urdu,
             COALESCE(s.title, '') AS section_title,
             COALESCE(c.title, '') AS chapter_title
      FROM Parags AS p
      LEFT JOIN Sections AS s ON s.Secid = p.Secid
      LEFT JOIN Chaps AS c ON c.cid = s.Chapid
      WHERE p.Secid = ?
      ORDER BY p.rowid
    ''', [sectionId]);
    return rows.map(Passage.fromMap).toList();
  }

  Future<Passage?> getPassageById(BookDefinition book, int recordId) async {
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT p.ID AS record_id, p.txt AS arabic, p.Secid AS section_id,
             p.paganum AS page_no, p.mean AS urdu,
             COALESCE(s.title, '') AS section_title,
             COALESCE(c.title, '') AS chapter_title
      FROM Parags AS p
      LEFT JOIN Sections AS s ON s.Secid = p.Secid
      LEFT JOIN Chaps AS c ON c.cid = s.Chapid
      WHERE p.ID = ?
      LIMIT 1
    ''', [recordId]);
    return rows.isEmpty ? null : Passage.fromMap(rows.first);
  }

  Future<List<SearchHit>> search(
    String query, {
    int limit = 40,
    String? bookKey,
    String language = 'all',
  }) async {
    final normalized = normalizeArabicUrdu(query);
    final tokens = normalized.split(' ').where((token) => token.isNotEmpty).toSet().take(12).toList();
    if (tokens.isEmpty) return [];
    final selectedLanguage = const {'arabic', 'urdu'}.contains(language) ? language : 'all';

    List<Map<String, Object?>> docs = [];
    if (_ftsAvailable) {
      final columns = selectedLanguage == 'all'
          ? const ['chapter_title', 'section_title', 'arabic', 'urdu']
          : ['chapter_title', 'section_title', selectedLanguage];
      final fts4 = _ftsEngine == 'fts4';
      final tokenClauses = tokens.map((token) {
        final term = fts4 ? token : '"${token.replaceAll('"', '""')}"';
        final separator = fts4 ? ':' : ' : ';
        return '(${columns.map((column) => '$column$separator$term').join(' OR ')})';
      }).toList();
      final strict = tokenClauses.join(' AND ');
      final broad = tokenClauses.join(' OR ');
      docs = await _searchFts(strict, limit, bookKey);
      if (_ftsAvailable && docs.isEmpty && broad != strict) docs = await _searchFts(broad, limit, bookKey);
    }
    if (!_ftsAvailable) docs = await _searchWithoutFts(tokens, limit, bookKey, selectedLanguage);
    if (docs.isEmpty) return [];

    final grouped = <String, List<Map<String, Object?>>>{};
    for (final doc in docs) {
      final key = (doc['book'] ?? '').toString();
      grouped.putIfAbsent(key, () => []).add(doc);
    }
    final passageCache = <String, Map<int, Passage>>{};
    for (final entry in grouped.entries) {
      final book = BookDefinition.byKey(entry.key);
      if (book == null) continue;
      final ids = entry.value.map((doc) => _asInt(doc['record_id'])).whereType<int>().toList();
      if (ids.isEmpty) continue;
      final db = await _openBook(book);
      final placeholders = List.filled(ids.length, '?').join(',');
      final textRows = await db.rawQuery('''
        SELECT p.ID AS record_id, p.txt AS arabic, p.Secid AS section_id,
               p.paganum AS page_no, p.mean AS urdu,
               COALESCE(s.title, '') AS section_title,
               COALESCE(c.title, '') AS chapter_title
        FROM Parags AS p
        LEFT JOIN Sections AS s ON s.Secid = p.Secid
        LEFT JOIN Chaps AS c ON c.cid = s.Chapid
        WHERE p.ID IN ($placeholders)
      ''', ids);
      final passages = <int, Passage>{};
      for (final row in textRows) {
        final id = _asInt(row['record_id']);
        if (id != null) passages[id] = Passage.fromMap(row);
      }
      passageCache[entry.key] = passages;
    }

    final hits = <SearchHit>[];
    for (final doc in docs) {
      final bookKey = (doc['book'] ?? '').toString();
      final book = BookDefinition.byKey(bookKey);
      final id = _asInt(doc['record_id']);
      if (book == null || id == null) continue;
      final passage = passageCache[bookKey]?[id];
      if (passage == null) continue;
      if (language == 'arabic' && passage.arabic.trim().isEmpty) continue;
      if (language == 'urdu' && passage.urdu.trim().isEmpty) continue;
      final chapter = passage.chapterTitle.isNotEmpty ? passage.chapterTitle : (doc['chapter_title'] ?? '').toString();
      final section = passage.sectionTitle.isNotEmpty ? passage.sectionTitle : (doc['section_title'] ?? '').toString();
      hits.add(SearchHit(
        book: book,
        passage: Passage(
          recordId: passage.recordId,
          sectionId: passage.sectionId,
          page: passage.page,
          arabic: passage.arabic,
          urdu: passage.urdu,
          chapterTitle: chapter,
          sectionTitle: section,
        ),
        citation: _citation(book, chapter, section, passage),
      ));
    }
    return hits.take(limit).toList();
  }

  Future<List<Map<String, Object?>>> _searchFts(String expression, int limit, String? bookKey) async {
    final whereBook = bookKey == null ? '' : ' AND d.book = ?';
    final args = <Object?>[expression];
    if (bookKey != null) args.add(bookKey);
    args.add(limit);
    final rank = _ftsEngine == 'fts5' ? 'bm25(search_fts, 0.35, 0.6, 1.2, 1.2)' : 'd.id';
    try {
      return await _searchDatabase!.rawQuery('''
        SELECT d.*, $rank AS rank
        FROM search_fts
        JOIN search_docs AS d ON d.id = search_fts.rowid
        WHERE search_fts MATCH ?$whereBook
        ORDER BY rank
        LIMIT ?
      ''', args);
    } catch (_) {
      _ftsAvailable = false;
      return [];
    }
  }

  Future<List<Map<String, Object?>>> _searchWithoutFts(
    List<String> tokens,
    int limit,
    String? bookKey,
    String language,
  ) async {
    final output = <Map<String, Object?>>[];
    for (final book in BookDefinition.all) {
      if (bookKey != null && book.key != bookKey) continue;
      final db = await _openBook(book);
      final columns = switch (language) {
        'arabic' => ['p.txt', 's.title', 'c.title'],
        'urdu' => ['p.mean', 's.title', 'c.title'],
        _ => ['p.txt', 'p.mean', 's.title', 'c.title'],
      };
      final conditions = <String>[];
      final args = <Object?>[];
      for (final token in tokens) {
        conditions.add('(${columns.map((column) => "COALESCE($column, '') LIKE ?").join(' OR ')})');
        final like = '%$token%';
        args.addAll(List<Object?>.filled(columns.length, like));
      }
      final rows = await db.rawQuery('''
        SELECT p.ID AS record_id, p.Secid AS section_id, p.paganum AS page_no,
               COALESCE(s.title, '') AS section_title,
               COALESCE(c.title, '') AS chapter_title,
               p.txt AS arabic, p.mean AS urdu
        FROM Parags AS p
        LEFT JOIN Sections AS s ON s.Secid = p.Secid
        LEFT JOIN Chaps AS c ON c.cid = s.Chapid
        WHERE ${conditions.join(' AND ')}
        LIMIT ?
      ''', [...args, limit]);
      for (final row in rows) {
        output.add({...row, 'book': book.key, 'database': book.fileName});
        if (output.length >= limit) return output;
      }
    }
    return output;
  }

  Future<bool> isBookmarked(String bookKey, int recordId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('bookmarks')?.contains('$bookKey:$recordId') ?? false;
  }

  Future<void> toggleBookmark(String bookKey, int recordId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bookmarks') ?? <String>[];
    final key = '$bookKey:$recordId';
    if (bookmarks.contains(key)) {
      bookmarks.remove(key);
    } else {
      bookmarks.add(key);
    }
    await prefs.setStringList('bookmarks', bookmarks);
  }

  Future<List<ReaderTarget>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('bookmarks') ?? <String>[];
    return values.map((value) {
      final parts = value.split(':');
      return ReaderTarget(book: parts.first, recordId: int.tryParse(parts.last) ?? 0);
    }).where((target) => target.recordId > 0).toList();
  }

  Future<String?> getNote(String bookKey, int recordId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('note:$bookKey:$recordId');
  }

  Future<void> saveNote(String bookKey, int recordId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'note:$bookKey:$recordId';
    if (text.trim().isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, text.trim());
    }
  }

  Future<void> close() async {
    for (final db in _bookDatabases.values) {
      await db.close();
    }
    _bookDatabases.clear();
    await _searchDatabase?.close();
    _searchDatabase = null;
    _initialized = false;
  }

  static String _citation(BookDefinition book, String chapter, String section, Passage passage) {
    final parts = <String>[book.titleUrdu];
    if (chapter.isNotEmpty) parts.add(chapter);
    if (section.isNotEmpty) parts.add(section);
    parts.add('حدیث نمبر ${passage.recordId}');
    if (passage.page != null) parts.add('صفحہ ${passage.page}');
    return parts.join(' · ');
  }
}

int? _asInt(Object? value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
