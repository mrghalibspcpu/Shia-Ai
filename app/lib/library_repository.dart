import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'text_utils.dart';

export 'text_utils.dart' show normalizeArabicUrdu, compactDisplayText, looksLikeGeminiApiKey;

const int _searchIndexVersion = 3;
const int _indexPageSize = 400;

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
        await _createSearchDocsTable(db);
        await db.execute('CREATE TABLE search_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );
    await _ensureSearchDocsSchema(_searchDatabase!);
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

  Future<void> _ensureSearchDocsSchema(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'search_docs'",
    );
    if (tables.isEmpty) {
      await _createSearchDocsTable(db);
      return;
    }
    final columns = await db.rawQuery('PRAGMA table_info(search_docs)');
    final names = columns.map((row) => row['name']?.toString()).toSet();
    if (!names.contains('norm_text')) {
      await db.execute('ALTER TABLE search_docs ADD COLUMN norm_text TEXT');
    }
  }

  Future<void> _createSearchDocsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS search_docs (
        id INTEGER PRIMARY KEY,
        book TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        section_id TEXT,
        page_no TEXT,
        chapter_title TEXT NOT NULL,
        section_title TEXT NOT NULL,
        norm_text TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS search_docs_book_record ON search_docs(book, record_id)');
  }

  Future<void> _buildSearchIndex(void Function(double, String) onProgress) async {
    final index = _searchDatabase!;
    await index.execute('DROP TABLE IF EXISTS search_docs');
    await _createSearchDocsTable(index);
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
          final normalized = [
            normalizeArabicUrdu(chapter),
            normalizeArabicUrdu(section),
            normalizeArabicUrdu(arabic),
            normalizeArabicUrdu(urdu),
          ];
          batch.insert('search_docs', {
            'id': id,
            'book': book.key,
            'record_id': recordId,
            'section_id': sectionId == null || sectionId.isEmpty ? null : sectionId,
            'page_no': page == null || page.isEmpty ? null : page,
            'chapter_title': chapter,
            'section_title': section,
            'norm_text': normalized.where((part) => part.isNotEmpty).join(' '),
          });
          if (_ftsAvailable && normalized.any((part) => part.isNotEmpty)) {
            batch.rawInsert(
              'INSERT INTO search_fts(rowid, chapter_title, section_title, arabic, urdu) '
              'VALUES (?, ?, ?, ?, ?)',
              [id, ...normalized],
            );
          }
        }
        await batch.commit(noResult: true);
        completed += rows.length;
        final progress = 0.25 + (0.75 * completed / totalRows);
        onProgress(progress.clamp(0.25, 0.99).toDouble(), 'متن کی تلاش تیار ہو رہی ہے — $completed / $totalRows');
      }
    }

    await index.insert('search_meta', {'key': 'index_version', 'value': '$_searchIndexVersion'});
    await index.update(
      'search_meta',
      {'value': '1'},
      where: 'key = ?',
      whereArgs: const ['ready'],
    );
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
    } catch (_) {}
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE search_fts USING fts4(
          chapter_title, section_title, arabic, urdu,
          content='', tokenize=unicode61
        )
      ''');
      _ftsEngine = 'fts4';
      _ftsAvailable = true;
      return;
    } catch (_) {}
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE search_fts USING fts4(
          chapter_title, section_title, arabic, urdu,
          content=''
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
    final tokens = searchTokens(query);
    if (tokens.isEmpty) return [];
    final selectedLanguage = const {'arabic', 'urdu'}.contains(language) ? language : 'all';
    final fts4 = _ftsEngine == 'fts4';

    List<Map<String, Object?>> docs = [];
    if (_ftsAvailable) {
      for (final prefix in const [true, false]) {
        final strict = buildFtsQuery(tokens, fts4: fts4, prefix: prefix, andMode: true);
        if (strict.isNotEmpty) docs = await _searchFts(strict, limit, bookKey);
        if (docs.isNotEmpty) break;
        final broad = buildFtsQuery(tokens, fts4: fts4, prefix: prefix, andMode: false);
        if (broad.isNotEmpty && broad != strict) docs = await _searchFts(broad, limit, bookKey);
        if (docs.isNotEmpty) break;
      }
    }
    if (docs.isEmpty) {
      docs = await _searchNormalizedLike(tokens, limit, bookKey);
    }
    if (docs.isEmpty && tokens.length > 2) {
      final distinctive = [...tokens]..sort((a, b) => b.length.compareTo(a.length));
      docs = await _searchNormalizedLike(distinctive.take(2).toList(), limit, bookKey);
    }
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
      final hitBookKey = (doc['book'] ?? '').toString();
      final book = BookDefinition.byKey(hitBookKey);
      final id = _asInt(doc['record_id']);
      if (book == null || id == null) continue;
      final passage = passageCache[hitBookKey]?[id];
      if (passage == null) continue;
      if (selectedLanguage == 'arabic' && passage.arabic.trim().isEmpty) continue;
      if (selectedLanguage == 'urdu' && passage.urdu.trim().isEmpty) continue;
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
        citation: formatCitation(
          bookTitle: book.titleUrdu,
          chapterTitle: chapter,
          sectionTitle: section,
          recordId: passage.recordId,
          page: passage.page,
        ),
      ));
    }
    return hits.take(limit).toList();
  }

  Future<List<Map<String, Object?>>> _searchFts(String expression, int limit, String? bookKey) async {
    if (expression.isEmpty || _searchDatabase == null) return [];
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
      return [];
    }
  }

  Future<List<Map<String, Object?>>> _searchNormalizedLike(
    List<String> tokens,
    int limit,
    String? bookKey,
  ) async {
    if (_searchDatabase == null || tokens.isEmpty) return [];
    final conditions = <String>[];
    final args = <Object?>[];
    for (final token in tokens) {
      conditions.add('COALESCE(d.norm_text, \'\') LIKE ?');
      args.add(likeNeedle(token));
    }
    if (bookKey != null) {
      conditions.add('d.book = ?');
      args.add(bookKey);
    }
    args.add(limit);
    try {
      return await _searchDatabase!.rawQuery('''
        SELECT d.*
        FROM search_docs AS d
        WHERE ${conditions.join(' AND ')}
        ORDER BY d.id
        LIMIT ?
      ''', args);
    } catch (_) {
      return [];
    }
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

  Future<List<(BookDefinition, Passage, String)>> getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final output = <(BookDefinition, Passage, String)>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('note:')) continue;
      final parts = key.split(':');
      if (parts.length < 3) continue;
      final book = BookDefinition.byKey(parts[1]);
      final recordId = int.tryParse(parts.sublist(2).join(':'));
      final note = prefs.getString(key);
      if (book == null || recordId == null || note == null || note.trim().isEmpty) continue;
      final passage = await getPassageById(book, recordId);
      if (passage != null) output.add((book, passage, note));
    }
    return output;
  }

  Future<void> saveLastRead({
    required String bookKey,
    required int recordId,
    int? sectionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_read', '$bookKey:$recordId:${sectionId ?? ''}');
  }

  Future<ReaderTarget?> getLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('last_read');
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final recordId = int.tryParse(parts[1]) ?? 0;
    if (BookDefinition.byKey(parts.first) == null || recordId <= 0) return null;
    return ReaderTarget(
      book: parts.first,
      recordId: recordId,
      sectionId: parts.length > 2 ? int.tryParse(parts[2]) : null,
    );
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
}

int? _asInt(Object? value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
