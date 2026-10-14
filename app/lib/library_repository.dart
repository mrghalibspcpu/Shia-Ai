import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'text_utils.dart';

export 'text_utils.dart'
    show
        compactDisplayText,
        expandSearchQueries,
        searchTokens,
        normalizeArabicUrdu,
        relevanceScore;

const int _searchIndexVersion = 5;
const int _indexPageSize = 400;

/// Reads every collection the app can ship: the 14 hadith books, the Quran,
/// Mafatih al-Jinan, and Nahj al-Balagha.
///
/// Databases may be bundled in the APK, downloaded on demand, or a mix of both.
/// Whatever is present on disk is indexed for full-text search; books that are
/// not installed yet are simply reported as unavailable so the UI can offer a
/// download instead of crashing.
class LibraryRepository {
  LibraryRepository();

  final Map<String, Database> _bookDatabases = {};
  final Set<String> _installed = {};
  Database? _searchDatabase;
  bool _ftsAvailable = false;
  String? _ftsEngine;
  bool _initialized = false;
  String _databaseDirectory = '';

  bool get isInitialized => _initialized;
  bool get hasFastSearch => _ftsAvailable;
  bool get hasAnyBook => _installed.isNotEmpty;
  List<BookDefinition> get installedBooks =>
      BookDefinition.all.where((book) => _installed.contains(book.key)).toList();

  bool isInstalled(BookDefinition book) => _installed.contains(book.key);

  String get dataDirectory => _databaseDirectory;

  Directory get dataDirectoryHandle => Directory(_databaseDirectory);

  Future<void> initialize({
    required void Function(double progress, String message) onProgress,
  }) async {
    if (_initialized) return;
    final appDatabasePath = await getDatabasesPath();
    _databaseDirectory = p.join(appDatabasePath, 'shia_library');
    await Directory(_databaseDirectory).create(recursive: true);

    for (var i = 0; i < BookDefinition.all.length; i++) {
      final book = BookDefinition.all[i];
      final installed = await _ensureLocalCopy(book, i, onProgress);
      if (installed) _installed.add(book.key);
    }

    for (final book in installedBooks.toList()) {
      try {
        await _ensureReaderIndexes(book);
      } catch (_) {
        _installed.remove(book.key);
      }
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
    await _refreshSearchIndex(onProgress);
    _initialized = true;
  }

  /// Copies a bundled asset into app storage when the file is not there yet.
  ///
  /// Returns true when the database is usable. A missing asset is not an error:
  /// the book stays available for download from the data screen.
  Future<bool> _ensureLocalCopy(
    BookDefinition book,
    int index,
    void Function(double, String) onProgress,
  ) async {
    final outputPath = p.join(_databaseDirectory, book.fileName);
    final output = File(outputPath);
    if (await output.exists() && await output.length() > 0) return true;

    onProgress(
      index / BookDefinition.all.length * 0.2,
      'کتب تیار ہو رہی ہیں — ${book.titleUrdu}',
    );
    try {
      final data = await rootBundle.load('assets/databases/${book.fileName}');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      if (bytes.isEmpty) return false;
      await output.writeAsBytes(bytes, flush: true);
      return true;
    } on FlutterError catch (_) {
      // Not bundled with this APK; the download manager can fetch it later.
      return false;
    }
  }

  /// Re-checks the disk after the installer finished and indexes what is new.
  Future<void> refreshAfterInstall({
    void Function(double progress, String message)? onProgress,
  }) async {
    if (!_initialized) {
      await initialize(onProgress: onProgress ?? (_, __) {});
      return;
    }
    for (final book in BookDefinition.all) {
      if (_installed.contains(book.key)) continue;
      final file = File(p.join(_databaseDirectory, book.fileName));
      if (await file.exists() && await file.length() > 0) {
        _installed.add(book.key);
        try {
          await _ensureReaderIndexes(book);
        } catch (_) {
          _installed.remove(book.key);
        }
      }
    }
    await _refreshSearchIndex(onProgress ?? (_, __) {});
  }

  /// Drops and rebuilds the local search index (used by the settings screen).
  Future<void> rebuildSearchIndex({
    required void Function(double progress, String message) onProgress,
  }) async {
    for (final db in _bookDatabases.values) {
      await db.close();
    }
    _bookDatabases.clear();
    await _searchDatabase?.close();
    _searchDatabase = null;
    _initialized = false;
    final file = File(p.join(_databaseDirectory, 'shia-search.sqlite'));
    if (await file.exists()) await file.delete();
    await initialize(onProgress: onProgress);
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
    for (final name in ['norm_arabic', 'norm_urdu']) {
      if (!names.contains(name)) await db.execute('ALTER TABLE search_docs ADD COLUMN $name TEXT');
    }
    if (!names.contains('norm_text')) {
      await db.execute('ALTER TABLE search_docs ADD COLUMN norm_text TEXT');
    }
    if (!names.contains('container_type')) {
      await db.execute('ALTER TABLE search_docs ADD COLUMN container_type INTEGER');
    }
    if (!names.contains('container_id')) {
      await db.execute('ALTER TABLE search_docs ADD COLUMN container_id INTEGER');
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
        container_type INTEGER,
        container_id INTEGER,
        norm_arabic TEXT,
        norm_urdu TEXT,
        norm_text TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS search_docs_book_record ON search_docs(book, record_id)',
    );
  }

  Future<void> _refreshSearchIndex(void Function(double, String) onProgress) async {
    final index = _searchDatabase;
    if (index == null) return;

    final versionRows = await index.query(
      'search_meta',
      where: 'key = ?',
      whereArgs: const ['index_version'],
      limit: 1,
    );
    final readyRows = await index.query(
      'search_meta',
      where: 'key = ?',
      whereArgs: const ['ready'],
      limit: 1,
    );
    final versionMatches =
        versionRows.isNotEmpty && versionRows.first['value']?.toString() == '$_searchIndexVersion';
    final isReady = readyRows.isNotEmpty && readyRows.first['value']?.toString() == '1';

    if (!versionMatches || !isReady || _installed.isEmpty) {
      await _rebuildSearchIndex(onProgress);
      return;
    }

    // Additive path: only books that were installed since the last launch.
    for (final book in installedBooks) {
      if (await _isBookIndexed(book.key)) continue;
      await _indexBook(book, await _nextSearchId(), onProgress, total: null, completed: 0);
    }
  }

  Future<bool> _isBookIndexed(String bookKey) async {
    final rows = await _searchDatabase!.query(
      'search_meta',
      where: 'key = ?',
      whereArgs: ['indexed:$bookKey'],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['value']?.toString() == '1';
  }

  Future<int> _nextSearchId() async {
    final rows = await _searchDatabase!.rawQuery('SELECT COALESCE(MAX(id), 0) AS top FROM search_docs');
    return (rows.first['top'] as int? ?? 0) + 1;
  }

  Future<void> _rebuildSearchIndex(void Function(double, String) onProgress) async {
    final index = _searchDatabase!;
    await index.execute('DROP TABLE IF EXISTS search_docs');
    await _createSearchDocsTable(index);
    await _createFtsTable(index);
    await index.delete('search_meta');
    await index.insert('search_meta', {'key': 'ready', 'value': '0'});

    if (_installed.isEmpty) {
      await index.insert('search_meta', {'key': 'index_version', 'value': '$_searchIndexVersion'});
      await index.update('search_meta', {'value': '1'}, where: 'key = ?', whereArgs: const ['ready']);
      onProgress(1, 'کتب کا انتظار ہے');
      return;
    }

    var totalRows = 0;
    final counts = <String, int>{};
    for (final book in installedBooks) {
      final count = await _countIndexableRows(book);
      counts[book.key] = count;
      totalRows += count;
    }

    var nextId = 1;
    var completed = 0;
    for (final book in installedBooks) {
      final added = await _indexBook(book, nextId, onProgress, total: totalRows, completed: completed);
      nextId += added;
      completed += counts[book.key] ?? 0;
    }

    await index.insert('search_meta', {'key': 'index_version', 'value': '$_searchIndexVersion'});
    await index.update('search_meta', {'value': '1'}, where: 'key = ?', whereArgs: const ['ready']);
    onProgress(1, 'کتب تیار ہیں');
  }

  /// Row count that the indexer will actually walk (blank placeholders skipped).
  Future<int> _countIndexableRows(BookDefinition book, {Database? database}) async {
    final source = database ?? await _openBook(book);
    final statement = book.source == CorpusSource.hadith
        ? 'SELECT COUNT(*) AS count FROM Parags '
              'WHERE LENGTH(COALESCE(txt, \'\')) > 0 OR LENGTH(COALESCE(mean, \'\')) > 0'
        : book.source == CorpusSource.balagha
            ? 'SELECT (SELECT COUNT(*) FROM balaghatext) + '
                '(SELECT COUNT(*) FROM balaghatext_hawashi) + '
                '(SELECT COUNT(*) FROM balaghatext_muqadamat) AS count'
            : 'SELECT COUNT(*) AS count FROM ${_sourceTable(book)}';
    final rows = await source.rawQuery(statement);
    return (rows.first['count'] as int?) ?? 0;
  }

  String _sourceTable(BookDefinition book) => switch (book.source) {
        CorpusSource.hadith => 'Parags',
        CorpusSource.quran => 'Quran',
        CorpusSource.dua => 'M_items',
        CorpusSource.balagha => 'balaghatext',
        CorpusSource.sahifa => 'saheefa_data',
        CorpusSource.fatwa => 'question_answers',
      };

  /// Copies one book into `search_docs` (and the FTS mirror) starting at [startId].
  ///
  /// Returns the number of rows written.
  Future<int> _indexBook(
    BookDefinition book,
    int startId,
    void Function(double, String) onProgress, {
    required int? total,
    required int completed,
  }) async {
    final index = _searchDatabase!;
    final source = await _openBook(book);
    final bookRows = await _countIndexableRows(book, database: source);
    // A killed incremental install may leave partial rows but no completion
    // marker. Remove only this book's unfinished index before retrying it.
    if (_ftsAvailable) {
      final partial = await index.query('search_docs', columns: ['id'], where: 'book = ?', whereArgs: [book.key]);
      if (partial.isNotEmpty) {
        // Contentless FTS tables cannot delete rows reliably on older SQLite.
        // Rebuild from scratch rather than leave a duplicate/stale mirror.
        await _rebuildSearchIndex(onProgress);
        return 0;
      }
    } else {
      await index.delete('search_docs', where: 'book = ?', whereArgs: [book.key]);
    }
    var id = startId;
    var written = 0;

    for (var offset = 0; offset < bookRows; offset += _indexPageSize) {
      final rows = await _readIndexRows(book, source, offset);
      if (rows.isEmpty) break;
      final batch = index.batch();
      for (final row in rows) {
        final recordId = _asInt(row['record_id']);
        if (recordId == null) continue;
        final titles = _titlesFor(book, row);
        final arabic = (row['arabic'] ?? '').toString();
        final urdu = (row['urdu'] ?? '').toString();
        final sectionId = row['section_id']?.toString();
        final page = row['page_no']?.toString();
        final normalized = [
          normalizeArabicUrdu(titles.chapter),
          normalizeArabicUrdu(titles.section),
          normalizeArabicUrdu(arabic),
          normalizeArabicUrdu('$urdu ${(row['commentary'] ?? '')} ${(row['footnote'] ?? '')}'),
        ];
        batch.insert('search_docs', {
          'id': id,
          'book': book.key,
          'record_id': recordId,
          'section_id': sectionId == null || sectionId.isEmpty ? null : sectionId,
          'page_no': page == null || page.isEmpty ? null : page,
          'chapter_title': titles.chapter,
          'section_title': titles.section,
          'container_type': _asInt(row['container_type']),
          'container_id': _asInt(row['container_id']),
          'norm_arabic': normalized[2],
          'norm_urdu': normalized[3],
          'norm_text': normalized.where((part) => part.isNotEmpty).join(' '),
        });
        if (_ftsAvailable && normalized.any((part) => part.isNotEmpty)) {
          batch.rawInsert(
            'INSERT INTO search_fts(rowid, chapter_title, section_title, arabic, urdu) '
            'VALUES (?, ?, ?, ?, ?)',
            [id, ...normalized],
          );
        }
        id++;
        written++;
      }
      await batch.commit(noResult: true);
      if (total != null && total > 0) {
        final done = completed + offset + rows.length;
        final progress = 0.2 + (0.8 * done / total);
        onProgress(
          progress.clamp(0.2, 0.99).toDouble(),
          'متن کی تلاش تیار ہو رہی ہے — $done / $total',
        );
      } else {
        onProgress(0.99, 'نئی کتاب کی فہرست تیار ہو رہی ہے — ${book.titleUrdu}');
      }
    }

    if (written != bookRows) throw StateError('Incomplete index: ${book.key}: $written / $bookRows');
    await index.insert(
      'search_meta',
      {'key': 'indexed:${book.key}', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return written;
  }

  ({String chapter, String section}) _titlesFor(BookDefinition book, Map<String, Object?> row) {
    switch (book.source) {
      case CorpusSource.quran:
        final chapter = _asInt(row['container_type']) ?? 1;
        final juz = _asInt(row['juz']);
        final urduName = chapter >= 1 && chapter <= urduSurahNames.length
            ? urduSurahNames[chapter - 1]
            : '';
        final arabicName = (row['surah_name'] ?? '').toString();
        return (
          chapter: 'سورہ ${urduName.isEmpty ? arabicName : '$urduName $arabicName'}',
          section: juz == null ? '' : 'پارہ $juz',
        );
      case CorpusSource.dua:
        final category = _asInt(row['container_type']) ?? 0;
        return (
          chapter: duaCategoryTitles[category] ?? 'مفاتیح الجنان',
          section: (row['section_title'] ?? '').toString(),
        );
      case CorpusSource.balagha:
        final type = _asInt(row['container_type']) ?? 1;
        return (
          chapter: balaghaSectionTitles[type] ?? 'نہج البلاغہ',
          section: (row['section_title'] ?? '').toString(),
        );
      case CorpusSource.sahifa:
      case CorpusSource.fatwa:
        return (chapter: book.titleUrdu, section: (row['section_title'] ?? '').toString());
      case CorpusSource.hadith:
        final chapter = (row['chapter_title'] ?? '').toString();
        // Twenty records across four books point at a section id that has no
        // Sections row. They stay readable through the LEFT JOIN; give them the
        // book name instead of an empty header.
        return (
          chapter: chapter.isEmpty ? book.titleUrdu : chapter,
          section: (row['section_title'] ?? '').toString(),
        );
    }
  }

  Future<List<Map<String, Object?>>> _readIndexRows(
    BookDefinition book,
    Database source,
    int offset,
  ) async {
    switch (book.source) {
      case CorpusSource.sahifa:
      case CorpusSource.fatwa:
        return source.rawQuery('${_extraQuery(book)} ORDER BY record_id LIMIT ? OFFSET ?', [_indexPageSize, offset]);
      case CorpusSource.hadith:
        return source.rawQuery('''
          SELECT COALESCE(NULLIF(p.ID, ''), -p.rowid) AS record_id, p.txt AS arabic, p.Secid AS section_id,
                 p.paganum AS page_no, p.mean AS urdu,
                 COALESCE(s.title, '') AS section_title,
                 COALESCE(c.title, '') AS chapter_title
          FROM Parags AS p
          LEFT JOIN Sections AS s ON s.Secid = p.Secid
          LEFT JOIN Chaps AS c ON c.cid = s.Chapid
          WHERE LENGTH(COALESCE(p.txt, '')) > 0 OR LENGTH(COALESCE(p.mean, '')) > 0
          ORDER BY p.rowid
          LIMIT ? OFFSET ?
        ''', [_indexPageSize, offset]);
      case CorpusSource.quran:
        return source.rawQuery('''
          SELECT q.ID AS record_id, q.Arabic AS arabic, q.tr AS urdu, q.talighe AS commentary, q.page AS page_no,
                 q.chapter AS container_type, q.chapter AS container_id,
                 q.juz AS juz, q.verse AS verse, COALESCE(cp.Name, '') AS surah_name
          FROM Quran AS q
          LEFT JOIN ChapterProperty AS cp ON cp.Id = q.chapter
          ORDER BY q.ID
          LIMIT ? OFFSET ?
        ''', [_indexPageSize, offset]);
      case CorpusSource.dua:
        return source.rawQuery('''
          SELECT m.rowid AS record_id, m.M_name AS section_title, m.M_cat_id AS container_type,
                 m._id AS container_id,
                 COALESCE((SELECT GROUP_CONCAT(t.body, ' ') FROM (
                     SELECT L_text AS body FROM Lines
                     WHERE L_M_id = m._id AND L_type = 1 ORDER BY L_prio, rowid
                 ) AS t), '') AS arabic,
                 COALESCE((SELECT GROUP_CONCAT(u.body, ' ') FROM (
                     SELECT COALESCE(NULLIF(L_Translate, '0'), L_text) AS body FROM Lines
                     WHERE L_M_id = m._id ORDER BY L_prio, rowid
                 ) AS u), '') AS urdu
          FROM M_items AS m
          ORDER BY m.rowid
          LIMIT ? OFFSET ?
        ''', [_indexPageSize, offset]);
      case CorpusSource.balagha:
        return source.rawQuery('''
          SELECT x.ID AS record_id, x.AR AS arabic, x.UR AS urdu, x.ParaNo AS page_no,
                 x.Type AS container_type, x.TypeNo AS container_id,
                 COALESCE(t.ShortDesc, t.Description, '') AS section_title
          FROM balaghatext AS x
          LEFT JOIN balaghatoc AS t ON t.TypeID = x.Type AND t.TypeNo = x.TypeNo
          UNION ALL
          SELECT -h.ID, '', h.hawashi, h.ParaNo, h.Type, h.TypeNo,
                 CASE WHEN h.Type = 5 THEN 'مقدمہ' ELSE 'حاشیہ' END
          FROM balaghatext_hawashi h
          UNION ALL
          SELECT -1000000-m.ID, m.mqar, m.mqur, m.ParaNo, m.Type, 0, 'مقدمہ'
          FROM balaghatext_muqadamat m
          ORDER BY record_id
          LIMIT ? OFFSET ?
        ''', [_indexPageSize, offset]);
    }
  }

  Future<void> _ensureReaderIndexes(BookDefinition book) async {
    final path = p.join(_databaseDirectory, book.fileName);
    Database? database;
    try {
      database = await openDatabase(path);
      final statements = switch (book.source) {
        CorpusSource.sahifa => const [
            'CREATE INDEX IF NOT EXISTS shia_sahifa_container ON saheefa_data(t_id, t_no, p_no, ID)',
          ],
        CorpusSource.fatwa => const [
            'CREATE INDEX IF NOT EXISTS shia_fatwa_category ON question_answers(category_id)',
          ],
        CorpusSource.hadith => const [
            'CREATE INDEX IF NOT EXISTS shia_parags_record ON Parags(ID)',
            'CREATE INDEX IF NOT EXISTS shia_parags_section ON Parags(Secid)',
            'CREATE INDEX IF NOT EXISTS shia_sections_chapter ON Sections(Chapid)',
            'CREATE INDEX IF NOT EXISTS shia_sections_record ON Sections(Secid)',
            'CREATE INDEX IF NOT EXISTS shia_chapters_record ON Chaps(cid)',
          ],
        CorpusSource.quran => const [
            'CREATE INDEX IF NOT EXISTS shia_quran_record ON Quran(ID)',
            'CREATE INDEX IF NOT EXISTS shia_quran_chapter_verse ON Quran(chapter, verse)',
            'CREATE INDEX IF NOT EXISTS shia_quran_juz ON Quran(juz)',
            'CREATE INDEX IF NOT EXISTS shia_quran_page ON Quran(page)',
            'CREATE INDEX IF NOT EXISTS shia_quran_surah ON ChapterProperty(Id)',
          ],
        CorpusSource.dua => const [
            'CREATE INDEX IF NOT EXISTS shia_mafatih_items_order ON M_items(M_cat_id, M_type, M_prio)',
            'CREATE INDEX IF NOT EXISTS shia_mafatih_lines_item ON Lines(L_M_id, L_prio)',
            'CREATE INDEX IF NOT EXISTS shia_mafatih_lines_record ON Lines(_id)',
          ],
        CorpusSource.balagha => const [
            'CREATE INDEX IF NOT EXISTS shia_balagha_text_locate ON balaghatext(Type, TypeNo, ParaNo)',
            'CREATE INDEX IF NOT EXISTS shia_balagha_toc_type ON balaghatoc(TypeID, TypeNo)',
            'CREATE INDEX IF NOT EXISTS shia_balagha_hawashi_locate ON balaghatext_hawashi(Type, TypeNo, ParaNo)',
            'CREATE INDEX IF NOT EXISTS shia_balagha_muqadamat_type ON balaghatext_muqadamat(Type, ParaFormat, ID)',
          ],
      };
      final existing = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      );
      final names = existing.map((row) => row['name']?.toString()).toSet();
      for (final statement in statements) {
        final name = RegExp(r'INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)', caseSensitive: false)
            .firstMatch(statement)
            ?.group(1);
        if (name != null && names.contains(name)) continue;
        await database.execute(statement);
      }
    } finally {
      await database?.close();
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
    if (!await File(path).exists()) {
      throw StateError('${book.titleUrdu} ابھی نصب نہیں ہے۔ ڈیٹا اسکرین سے ڈاؤن لوڈ کریں۔');
    }
    final database = await openDatabase(path, readOnly: true, singleInstance: false);
    _bookDatabases[book.key] = database;
    return database;
  }

  String _extraQuery(BookDefinition book) => book.source == CorpusSource.sahifa
      ? """
        SELECT d.ID AS record_id, d.t_id * 10000 + d.t_no AS section_id,
          CASE WHEN d.oe = 'a' THEN d.p_text ELSE '' END AS arabic,
          CASE WHEN d.oe != 'a' THEN d.p_text ELSE '' END AS urdu,
          COALESCE((SELECT i.lnk_text FROM saheefa_index i
            WHERE CAST(i.lnk_cat AS INTEGER) = d.t_id AND i.lnk_id = d.t_no LIMIT 1),
            'حصہ ' || d.t_id || ' / ' || d.t_no) AS section_title,
          d.t_id AS container_type, d.t_no AS container_id, d.p_format AS format
        FROM saheefa_data d
      """
      : """
        SELECT q.rowid AS record_id, q.category_id AS section_id, '' AS arabic,
          q.question_ur || char(10) || char(10) || q.answer_ur AS urdu,
          c.category_title_ur AS section_title, q.collection_title_ur AS chapter_title,
          COALESCE(q.source_ref, '') || ' — ' || q.source_url AS locator
        FROM question_answers q JOIN categories c ON c.category_id = q.category_id
      """;

  // ---------------------------------------------------------------- hadith

  Future<List<Map<String, Object?>>> getChapters(BookDefinition book) async {
    final db = await _openBook(book);
    if (book.source == CorpusSource.sahifa || book.source == CorpusSource.fatwa) {
      return db.rawQuery('SELECT section_id AS ID, section_id AS cid, section_title AS title '
          'FROM (${_extraQuery(book)}) GROUP BY section_id ORDER BY section_id');
    }
    return db.rawQuery('SELECT ID, cid, title FROM Chaps ORDER BY cid');
  }

  Future<List<Map<String, Object?>>> getSections(BookDefinition book, int chapterId) async {
    final db = await _openBook(book);
    if (book.source == CorpusSource.sahifa || book.source == CorpusSource.fatwa) {
      return db.rawQuery('SELECT section_id AS ID, section_title AS title, section_id AS Chapid, section_id AS Secid '
          'FROM (${_extraQuery(book)}) WHERE section_id = ? GROUP BY section_id', [chapterId]);
    }
    return db.rawQuery(
      'SELECT ID, title, Chapid, Secid FROM Sections WHERE Chapid = ? ORDER BY Secid',
      [chapterId],
    );
  }

  Future<List<Passage>> getSectionPassages(BookDefinition book, int sectionId) async {
    final db = await _openBook(book);
    if (book.source == CorpusSource.sahifa || book.source == CorpusSource.fatwa) {
      final rows = await db.rawQuery('SELECT * FROM (${_extraQuery(book)}) WHERE section_id = ? ORDER BY record_id', [sectionId]);
      return rows.map(Passage.fromMap).toList();
    }
    final rows = await db.rawQuery('''
      SELECT COALESCE(NULLIF(p.ID, ''), -p.rowid) AS record_id, p.txt AS arabic, p.Secid AS section_id,
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

  // ----------------------------------------------------------------- quran

  Future<List<QuranSurah>> getSurahs() async {
    final book = BookDefinition.bookFor(CorpusSource.quran);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery(
      'SELECT Id, Name, Nozol, Verse, revel FROM ChapterProperty ORDER BY Id',
    );
    return [
      for (var i = 0; i < rows.length; i++) QuranSurah.fromMap(rows[i], index: i),
    ];
  }

  Future<Passage?> getQuranVerse(int chapter, int verse) async {
    final book = BookDefinition.bookFor(CorpusSource.quran)!;
    final db = await _openBook(book);
    final rows = await db.rawQuery('SELECT ID FROM Quran WHERE chapter = ? AND verse = ? LIMIT 1', [chapter, verse]);
    return rows.isEmpty ? null : getPassageById(book, _asInt(rows.first['ID'])!);
  }

  Future<List<Passage>> getSurahVerses(int chapter) async {
    final book = BookDefinition.bookFor(CorpusSource.quran);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT q.ID AS record_id, q.Arabic AS arabic, q.tr AS urdu, q.talighe AS commentary,
             q.chapter AS container_type, q.chapter AS container_id, q.page AS page_no,
             q.juz AS juz, q.verse AS verse, COALESCE(cp.Name, '') AS surah_name
      FROM Quran AS q LEFT JOIN ChapterProperty AS cp ON cp.Id = q.chapter
      WHERE q.chapter = ?
      ORDER BY q.verse
    ''', [chapter]);
    return rows.map(_quranPassage).toList();
  }

  Future<List<QuranJuzEntry>> getJuzIndex() async {
    final book = BookDefinition.bookFor(CorpusSource.quran);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT j.juz AS juz, q.ID AS first_id, q.chapter AS surah, q.verse AS verse
      FROM (SELECT juz, MIN(ID) AS first_id FROM Quran GROUP BY juz) AS j
      JOIN Quran AS q ON q.ID = j.first_id
      ORDER BY j.juz
    ''');
    return [
      for (final row in rows)
        QuranJuzEntry(
          juz: _asInt(row['juz']) ?? 0,
          firstRecordId: _asInt(row['first_id']) ?? 0,
          surah: _asInt(row['surah']) ?? 1,
          verse: _asInt(row['verse']) ?? 1,
        ),
    ];
  }

  Future<List<Passage>> getJuzVerses(int juz) async {
    final book = BookDefinition.bookFor(CorpusSource.quran);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT q.ID AS record_id, q.Arabic AS arabic, q.tr AS urdu, q.talighe AS commentary,
             q.chapter AS container_type, q.chapter AS container_id, q.page AS page_no,
             q.juz AS juz, q.verse AS verse, COALESCE(cp.Name, '') AS surah_name
      FROM Quran AS q LEFT JOIN ChapterProperty AS cp ON cp.Id = q.chapter
      WHERE q.juz = ?
      ORDER BY q.ID
    ''', [juz]);
    return rows.map(_quranPassage).toList();
  }

  Future<List<Passage>> getQuranPage(int page) async {
    final book = BookDefinition.bookFor(CorpusSource.quran);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT q.ID AS record_id, q.Arabic AS arabic, q.tr AS urdu, q.talighe AS commentary,
             q.chapter AS container_type, q.chapter AS container_id, q.page AS page_no,
             q.juz AS juz, q.verse AS verse, COALESCE(cp.Name, '') AS surah_name
      FROM Quran AS q LEFT JOIN ChapterProperty AS cp ON cp.Id = q.chapter
      WHERE q.page = ?
      ORDER BY q.ID
    ''', [page]);
    return rows.map(_quranPassage).toList();
  }

  Passage _quranPassage(Map<String, Object?> row) {
    final chapter = _asInt(row['container_type']) ?? 1;
    final verse = _asInt(row['verse']) ?? 0;
    final juz = _asInt(row['juz']);
    final page = _asInt(row['page_no']);
    final urduName = chapter >= 1 && chapter <= urduSurahNames.length
        ? urduSurahNames[chapter - 1]
        : '';
    final arabicName = (row['surah_name'] ?? '').toString();
    final locatorParts = <String>[
      if (verse > 0) 'آیت $verse',
      if (juz != null) 'پارہ $juz',
      if (page != null) 'صفحہ $page',
    ];
    return Passage(
      recordId: _asInt(row['record_id']) ?? 0,
      arabic: _compact((row['arabic'] ?? '').toString()),
      urdu: _compact((row['urdu'] ?? '').toString()),
      commentary: _compact((row['commentary'] ?? '').toString()),
      page: page,
      containerType: chapter,
      containerId: chapter,
      chapterTitle: urduName.isEmpty ? arabicName : '$urduName · $arabicName',
      sectionTitle: arabicName,
      locator: locatorParts.join(' • '),
    );
  }

  // ------------------------------------------------------------------ duas

  Future<List<DuaCategory>> getDuaCategories() async {
    final book = BookDefinition.bookFor(CorpusSource.dua);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT M_cat_id AS cat, COUNT(*) AS total,
             SUM(CASE WHEN M_type = 1 THEN 1 ELSE 0 END) AS leaves
      FROM M_items GROUP BY M_cat_id ORDER BY M_cat_id
    ''');
    return rows.map((row) {
      final id = _asInt(row['cat']) ?? 0;
      return DuaCategory(
        id: id,
        titleUrdu: duaCategoryTitles[id] ?? 'حصہ $id',
        itemCount: _asInt(row['leaves']) ?? _asInt(row['total']) ?? 0,
      );
    }).toList();
  }

  Future<List<DuaItem>> getDuaItems(int categoryId) async {
    final book = BookDefinition.bookFor(CorpusSource.dua);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT m.rowid AS row_id, m.M_name, m.M_cat_id, m.M_type, m.M_montakhab,
             (SELECT COUNT(*) FROM Lines AS l WHERE l.L_M_id = m._id) AS line_count
      FROM M_items AS m
      WHERE m.M_cat_id = ?
      ORDER BY m.M_prio, m.rowid
    ''', [categoryId]);
    return rows.map(DuaItem.fromMap).toList();
  }

  Future<List<DuaItem>> getFeaturedDuas({int limit = 12}) async {
    final book = BookDefinition.bookFor(CorpusSource.dua);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT m.rowid AS row_id, m.M_name, m.M_cat_id, m.M_type, m.M_montakhab,
             (SELECT COUNT(*) FROM Lines AS l WHERE l.L_M_id = m._id) AS line_count
      FROM M_items AS m
      WHERE m.M_montakhab = 1 AND m.M_type = 1
      ORDER BY m.M_cat_id, m.M_prio, m.rowid
      LIMIT ?
    ''', [limit]);
    return rows.map(DuaItem.fromMap).toList();
  }

  Future<List<Passage>> getDuaLines(int itemRowId) async {
    final book = BookDefinition.bookFor(CorpusSource.dua);
    if (book == null) return const [];
    final db = await _openBook(book);
    final itemRows = await db.rawQuery(
      'SELECT rowid AS row_id, _id, M_name, M_cat_id FROM M_items WHERE rowid = ? LIMIT 1',
      [itemRowId],
    );
    if (itemRows.isEmpty) return const [];
    final itemId = _asInt(itemRows.first['_id']);
    final title = (itemRows.first['M_name'] ?? '').toString();
    final category = _asInt(itemRows.first['M_cat_id']) ?? 0;
    final rows = await db.rawQuery('''
      SELECT rowid AS record_id, L_text, L_Translate, L_prio, L_type
      FROM Lines WHERE L_M_id = ?
      ORDER BY L_prio, rowid
    ''', [itemId]);
    // The source holds a few completely blank rows; never render them.
    return [
      for (final row in rows) _duaPassage(row, title: title, category: category, itemRowId: itemRowId)
    ].where((passage) => !passage.isEmpty).toList();
  }

  Passage _duaPassage(
    Map<String, Object?> row, {
    required String title,
    required int category,
    required int itemRowId,
  }) {
    final text = _compact((row['L_text'] ?? '').toString());
    final translate = _compact((row['L_Translate'] ?? '').toString());
    final type = _asInt(row['L_type']) ?? 1;
    // Mafatih rows are of two kinds in the source database: the dua itself
    // (Arabic with an Urdu translation) and Urdu instructions to the reciter
    // printed between segments ("پھر سات مرتبہ پڑھیں"), where L_Translate
    // holds the sentinel '0'. Keep the kinds distinct so the reader renders
    // each the way the book does — no "سطر نمبر" labels, and instructions are
    // never dressed up as tafseer.
    final isInstruction = type == 2;
    return Passage(
      recordId: _asInt(row['record_id']) ?? 0,
      arabic: isInstruction ? '' : text,
      urdu: isInstruction ? text : (translate == '0' ? '' : translate),
      containerType: category,
      containerId: itemRowId,
      chapterTitle: duaCategoryTitles[category] ?? 'مفاتیح الجنان',
      sectionTitle: title,
      format: type,
    );
  }

  // ------------------------------------------------------- nahj al-balagha

  Future<List<BalaghaSection>> getBalaghaSections() async {
    final book = BookDefinition.bookFor(CorpusSource.balagha);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT t.TypeID AS type, COUNT(DISTINCT t.TypeNo) AS entries,
             (SELECT COUNT(*) FROM balaghatext_muqadamat AS m WHERE m.Type = t.TypeID) AS intro
      FROM balaghatoc AS t
      GROUP BY t.TypeID ORDER BY t.TypeID
    ''');
    return rows.map((row) {
      final type = _asInt(row['type']) ?? 0;
      return BalaghaSection(
        type: type,
        titleUrdu: balaghaSectionTitles[type] ?? 'حصہ $type',
        entryCount: _asInt(row['entries']) ?? 0,
        hasIntroduction: (_asInt(row['intro']) ?? 0) > 0,
      );
    }).toList();
  }

  Future<List<BalaghaEntry>> getBalaghaEntries(int type) async {
    final book = BookDefinition.bookFor(CorpusSource.balagha);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT t.TypeNo AS type_no, COALESCE(NULLIF(t.ShortDesc, ''), t.Description, '') AS title,
             (SELECT COUNT(*) FROM balaghatext AS x WHERE x.Type = t.TypeID AND x.TypeNo = t.TypeNo)
               + (SELECT COUNT(*) FROM balaghatext_hawashi AS h
                   WHERE h.Type = 5 AND t.TypeID = 5 AND h.TypeNo = t.TypeNo) AS paragraphs
      FROM balaghatoc AS t
      WHERE t.TypeID = ?
      ORDER BY t.TypeNo
    ''', [type]);
    return rows.map((row) => BalaghaEntry(
          typeNo: _asInt(row['type_no']) ?? 0,
          title: _compact((row['title'] ?? '').toString()),
          paragraphCount: _asInt(row['paragraphs']) ?? 0,
        )).toList();
  }

  Future<List<Passage>> getBalaghaEntry(int type, int typeNo) async {
    final book = BookDefinition.bookFor(CorpusSource.balagha);
    if (book == null) return const [];
    final db = await _openBook(book);
    final paragraphs = <Passage>[];

    if (type == 5) {
      // The introductions live as continuous Urdu prose in the footnote table.
      final prose = await db.rawQuery('''
        SELECT ID AS record_id, hawashi AS urdu, TypeNo AS container_id
        FROM balaghatext_hawashi WHERE Type = 5 AND TypeNo = ? ORDER BY ID
      ''', [typeNo]);
      // Footnote-table prose gets a negative id so it can never collide with a
      // balaghatext id, and getPassageById can resolve it back to this entry.
      paragraphs.addAll(prose.map((row) => Passage(
            recordId: -(_asInt(row['record_id']) ?? 0),
            arabic: '',
            urdu: _compact((row['urdu'] ?? '').toString()),
            containerType: type,
            containerId: typeNo,
            chapterTitle: balaghaSectionTitles[type] ?? 'نہج البلاغہ',
            sectionTitle: 'مقدمہ',
          )));
    }

    final rows = await db.rawQuery('''
      SELECT x.ID AS record_id, x.AR AS arabic, x.UR AS urdu, x.ParaNo AS page_no,
             x.ParaFormat AS format, x.Type AS container_type, x.TypeNo AS container_id
      FROM balaghatext AS x
      WHERE x.Type = ? AND x.TypeNo = ?
      ORDER BY (x.ParaNo IS NULL), x.ParaNo, x.ID
    ''', [type, typeNo]);
    for (final row in rows) {
      final passage = Passage(
        recordId: _asInt(row['record_id']) ?? 0,
        arabic: _compact((row['arabic'] ?? '').toString()),
        urdu: _compact((row['urdu'] ?? '').toString()),
        page: _asInt(row['page_no']),
        containerType: type,
        containerId: typeNo,
        chapterTitle: balaghaSectionTitles[type] ?? 'نہج البلاغہ',
        // The database's own paragraph role (title / text / sub-heading /
        // separator) — shown as book typography, never as a "فقرا نمبر" label,
        // which is an internal ordering field readers found confusing.
        format: _asInt(row['format']),
      );
      paragraphs.add(passage);
    }

    final footnotes = await _footnotesByParagraph(db, type, typeNo);
    return [
      for (final passage in paragraphs)
        if (passage.page != null && (footnotes[passage.page] ?? '').isNotEmpty)
          passage.copyWith(footnote: footnotes[passage.page]!)
        else
          passage,
    ].where((passage) => !passage.isEmpty).toList();
  }

  /// Every footnote of one entry, grouped by the paragraph it annotates.
  Future<Map<int, String>> _footnotesByParagraph(Database db, int type, int typeNo) async {
    if (type == 5) return const {};
    final rows = await db.rawQuery('''
      SELECT ParaNo AS para, hawashi AS body FROM balaghatext_hawashi
      WHERE Type = ? AND TypeNo = ? AND ParaNo IS NOT NULL
      ORDER BY ParaNo, ID
    ''', [type, typeNo]);
    final grouped = <int, List<String>>{};
    for (final row in rows) {
      final para = _asInt(row['para']);
      final body = _compact((row['body'] ?? '').toString());
      if (para == null || body.isEmpty) continue;
      grouped.putIfAbsent(para, () => []).add(body);
    }
    return grouped.map((para, bodies) => MapEntry(para, bodies.join('\n\n')));
  }

  /// Footnotes (`balaghatext_hawashi`) attached to one paragraph.
  Future<List<Passage>> getBalaghaFootnotes(int type, int typeNo, int paraNo) async {
    final book = BookDefinition.bookFor(CorpusSource.balagha);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT ID AS record_id, hawashi AS urdu, hawashiflag AS flag
      FROM balaghatext_hawashi
      WHERE Type = ? AND TypeNo = ? AND ParaNo = ?
      ORDER BY ID
    ''', [type, typeNo, paraNo]);
    return rows.map((row) => Passage(
          recordId: _asInt(row['record_id']) ?? 0,
          arabic: '',
          urdu: _compact((row['urdu'] ?? '').toString()),
          containerType: type,
          containerId: typeNo,
          locator: (row['flag'] ?? '').toString(),
        )).toList();
  }

  Future<List<Passage>> getBalaghaNotes(int type, int typeNo) async {
    final book = BookDefinition.bookFor(CorpusSource.balagha)!;
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT ID, hawashi, ParaNo FROM balaghatext_hawashi
      WHERE Type = ? AND TypeNo = ? ORDER BY ID
    ''', [type, typeNo]);
    return rows.map((row) => Passage(recordId: -(_asInt(row['ID']) ?? 0),
      arabic: '', urdu: _compact((row['hawashi'] ?? '').toString()),
      containerType: type, containerId: typeNo, sectionTitle: 'حاشیہ')).toList();
  }

  Future<List<Passage>> getBalaghaIntroduction(int type) async {
    final book = BookDefinition.bookFor(CorpusSource.balagha);
    if (book == null) return const [];
    final db = await _openBook(book);
    final rows = await db.rawQuery('''
      SELECT ID AS record_id, mqar AS arabic, mqur AS urdu
      FROM balaghatext_muqadamat WHERE Type = ? ORDER BY ID
    ''', [type]);
    return rows.map((row) => Passage(
          recordId: -1000000 - (_asInt(row['record_id']) ?? 0),
          arabic: _compact((row['arabic'] ?? '').toString()),
          urdu: _compact((row['urdu'] ?? '').toString()),
          containerType: type,
          containerId: 0,
          chapterTitle: balaghaSectionTitles[type] ?? 'نہج البلاغہ',
          sectionTitle: 'مقدمہ',
        )).toList();
  }

  // --------------------------------------------------------------- lookups

  Future<Passage?> getPassageById(BookDefinition book, int recordId) async {
    final db = await _openBook(book);
    switch (book.source) {
      case CorpusSource.sahifa:
      case CorpusSource.fatwa:
        final rows = await db.rawQuery('SELECT * FROM (${_extraQuery(book)}) WHERE record_id = ?', [recordId]);
        return rows.isEmpty ? null : Passage.fromMap(rows.first);
      case CorpusSource.hadith:
        final rows = await db.rawQuery('''
          SELECT COALESCE(NULLIF(p.ID, ''), -p.rowid) AS record_id, p.txt AS arabic, p.Secid AS section_id,
                 p.paganum AS page_no, p.mean AS urdu,
                 COALESCE(s.title, '') AS section_title,
                 COALESCE(c.title, '') AS chapter_title
          FROM Parags AS p
          LEFT JOIN Sections AS s ON s.Secid = p.Secid
          LEFT JOIN Chaps AS c ON c.cid = s.Chapid
          WHERE COALESCE(NULLIF(p.ID, ''), -p.rowid) = ?
          LIMIT 1
        ''', [recordId]);
        return rows.isEmpty ? null : Passage.fromMap(rows.first);
      case CorpusSource.quran:
        final rows = await db.rawQuery('''
          SELECT q.ID AS record_id, q.Arabic AS arabic, q.tr AS urdu, q.talighe AS commentary,
                 q.chapter AS container_type, q.chapter AS container_id, q.page AS page_no,
                 q.juz AS juz, q.verse AS verse, COALESCE(cp.Name, '') AS surah_name
          FROM Quran AS q LEFT JOIN ChapterProperty AS cp ON cp.Id = q.chapter
          WHERE q.ID = ?
          LIMIT 1
        ''', [recordId]);
        return rows.isEmpty ? null : _quranPassage(rows.first);
      case CorpusSource.dua:
        final itemRows = await db.rawQuery(
          'SELECT rowid AS row_id, _id, M_name, M_cat_id FROM M_items WHERE rowid = ? LIMIT 1',
          [recordId],
        );
        if (itemRows.isEmpty) return null;
        final title = (itemRows.first['M_name'] ?? '').toString();
        final category = _asInt(itemRows.first['M_cat_id']) ?? 0;
        return Passage(
          recordId: recordId,
          arabic: '',
          urdu: title,
          containerType: category,
          containerId: recordId,
          chapterTitle: duaCategoryTitles[category] ?? 'مفاتیح الجنان',
          sectionTitle: title,
          locator: 'دعا',
        );
      case CorpusSource.balagha:
        if (recordId < -1000000) {
          final rows = await db.rawQuery('''
            SELECT ID AS record_id, mqar AS arabic, mqur AS urdu, Type AS container_type,
                   0 AS container_id, 'مقدمہ' AS section_title
            FROM balaghatext_muqadamat WHERE ID = ?
          ''', [-1000000 - recordId]);
          if (rows.isEmpty) return null;
          final row = rows.first;
          return Passage(recordId: recordId, arabic: _compact((row['arabic'] ?? '').toString()),
            urdu: _compact((row['urdu'] ?? '').toString()),
            containerType: _asInt(row['container_type']), containerId: 0, sectionTitle: 'مقدمہ');
        }
        if (recordId < 0) {
          final prose = await db.rawQuery('''
            SELECT h.ID AS record_id, h.hawashi AS urdu, h.Type AS container_type,
                   h.TypeNo AS container_id
            FROM balaghatext_hawashi AS h
            WHERE h.ID = ?
            LIMIT 1
          ''', [-recordId]);
          if (prose.isEmpty) return null;
          final row = prose.first;
          final type = _asInt(row['container_type']) ?? 5;
          return Passage(
            recordId: recordId,
            arabic: '',
            urdu: _compact((row['urdu'] ?? '').toString()),
            containerType: type,
            containerId: _asInt(row['container_id']),
            chapterTitle: balaghaSectionTitles[type] ?? 'نہج البلاغہ',
            sectionTitle: type == 5 ? 'مقدمہ' : 'حاشیہ',
          );
        }
        final rows = await db.rawQuery('''
          SELECT x.ID AS record_id, x.AR AS arabic, x.UR AS urdu, x.ParaNo AS page_no,
                 x.Type AS container_type, x.TypeNo AS container_id,
                 COALESCE(t.ShortDesc, t.Description, '') AS section_title
          FROM balaghatext AS x
          LEFT JOIN balaghatoc AS t ON t.TypeID = x.Type AND t.TypeNo = x.TypeNo
          WHERE x.ID = ?
          LIMIT 1
        ''', [recordId]);
        if (rows.isEmpty) return null;
        final row = rows.first;
        final type = _asInt(row['container_type']) ?? 1;
        final footnotes = await _footnotesByParagraph(db, type, _asInt(row['container_id']) ?? 0);
        return Passage(
          recordId: recordId,
          arabic: _compact((row['arabic'] ?? '').toString()),
          urdu: _compact((row['urdu'] ?? '').toString()),
          page: _asInt(row['page_no']),
          footnote: footnotes[_asInt(row['page_no'])] ?? '',
          containerType: type,
          containerId: _asInt(row['container_id']),
          chapterTitle: balaghaSectionTitles[type] ?? 'نہج البلاغہ',
          sectionTitle: _compact((row['section_title'] ?? '').toString()),
        );
    }
  }

  /// Literal normalized substring search over EVERY indexed record. Pagination
  /// limits hydration/rendering, never which part of the book is searched.
  Future<({List<SearchHit> hits, int total})> searchPage(String query, {
    int offset = 0, int limit = 40, String? bookKey,
    String language = 'all', CorpusSource? source,
  }) async {
    final tokens = normalizeArabicUrdu(query).split(' ').where((t) => t.isNotEmpty).toSet();
    final db = _searchDatabase;
    if (tokens.isEmpty || db == null) return (hits: <SearchHit>[], total: 0);
    final column = language == 'arabic' ? 'norm_arabic' : language == 'urdu' ? 'norm_urdu' : 'norm_text';
    final conditions = <String>[];
    final args = <Object?>[];
    for (final token in tokens) {
      conditions.add("COALESCE($column, '') LIKE ?");
      args.add(likeNeedle(token));
    }
    if (bookKey != null) { conditions.add('book = ?'); args.add(bookKey); }
    final keys = source == null ? _installed.toList() : _installedBookKeysFor(source);
    if (keys.isEmpty) return (hits: <SearchHit>[], total: 0);
    conditions.add('book IN (${List.filled(keys.length, '?').join(',')})');
    args.addAll(keys);
    final where = conditions.join(' AND ');
    final counts = await db.rawQuery('SELECT COUNT(*) AS total FROM search_docs WHERE $where', args);
    final total = _asInt(counts.first['total']) ?? 0;
    final docs = await db.rawQuery('SELECT * FROM search_docs WHERE $where ORDER BY id LIMIT ? OFFSET ?', [...args, limit, offset]);
    final hits = <SearchHit>[];
    for (final doc in docs) {
      final book = BookDefinition.byKey(doc['book']?.toString());
      final id = _asInt(doc['record_id']);
      if (book == null || id == null) continue;
      final hydrated = await _hydrate(book, [id], tokens.toList());
      final passage = hydrated[id];
      if (passage == null) throw StateError('Indexed passage missing: ${book.key}:$id');
      hits.add(SearchHit(book: book, passage: passage, citation: formatCitation(
        bookTitle: book.titleUrdu, chapterTitle: passage.chapterTitle,
        sectionTitle: passage.sectionTitle, locator: passage.locator, page: passage.page)));
    }
    return (hits: hits, total: total);
  }

  // ---------------------------------------------------------------- search

  Future<List<SearchHit>> search(
    String query, {
    int limit = 40,
    String? bookKey,
    String language = 'all',
    CorpusSource? source,
  }) async {
    final tokens = searchTokens(query);
    if (tokens.isEmpty) return [];
    final selectedLanguage = const {'arabic', 'urdu'}.contains(language) ? language : 'all';
    final fts4 = _ftsEngine == 'fts4';
    final bookFilter = bookKey ?? _singleBookKeyFor(source);

    List<Map<String, Object?>> docs = [];
    if (_ftsAvailable) {
      for (final prefix in const [true, false]) {
        final strict = buildFtsQuery(tokens, fts4: fts4, prefix: prefix, andMode: true);
        if (strict.isNotEmpty) docs = await _searchFts(strict, limit, bookFilter, source);
        if (docs.isNotEmpty) break;
        final broad = buildFtsQuery(tokens, fts4: fts4, prefix: prefix, andMode: false);
        if (broad.isNotEmpty && broad != strict) {
          docs = await _searchFts(broad, limit, bookFilter, source);
        }
        if (docs.isNotEmpty) break;
      }
    }
    if (docs.isEmpty) {
      docs = await _searchNormalizedLike(tokens, limit, bookFilter, source);
    }
    if (docs.isEmpty && tokens.length > 2) {
      final distinctive = [...tokens]..sort((a, b) => b.length.compareTo(a.length));
      docs = await _searchNormalizedLike(distinctive.take(2).toList(), limit, bookFilter, source);
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
      if (book == null || !_installed.contains(book.key)) continue;
      final ids = entry.value.map((doc) => _asInt(doc['record_id'])).whereType<int>().toList();
      if (ids.isEmpty) continue;
      passageCache[entry.key] = await _hydrate(book, ids, tokens);
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
      if (selectedLanguage == 'urdu' &&
          passage.urdu.trim().isEmpty &&
          passage.commentary.trim().isEmpty) {
        continue;
      }
      final chapter = passage.chapterTitle.isNotEmpty
          ? passage.chapterTitle
          : (doc['chapter_title'] ?? '').toString();
      final section = passage.sectionTitle.isNotEmpty
          ? passage.sectionTitle
          : (doc['section_title'] ?? '').toString();
      hits.add(SearchHit(
        book: book,
        passage: Passage(
          recordId: passage.recordId,
          sectionId: passage.sectionId,
          page: passage.page,
          arabic: passage.arabic,
          urdu: passage.urdu,
          commentary: passage.commentary,
          locator: passage.locator,
          containerType: _asInt(doc['container_type']) ?? passage.containerType,
          containerId: _asInt(doc['container_id']) ?? passage.containerId,
          chapterTitle: chapter,
          sectionTitle: section,
        ),
        citation: formatCitation(
          bookTitle: book.titleUrdu,
          chapterTitle: chapter,
          sectionTitle: section,
          locator: passage.locator,
          page: passage.page,
        ),
      ));
    }
    return hits.take(limit).toList();
  }

  String? _singleBookKeyFor(CorpusSource? source) {
    if (source == null) return null;
    final matches = BookDefinition.all
        .where((book) => book.source == source && _installed.contains(book.key))
        .toList();
    return matches.length == 1 ? matches.first.key : null;
  }

  /// Loads the full text for search results, using the query to pick the best
  /// snippet for collections that are indexed per supplication.
  Future<Map<int, Passage>> _hydrate(
    BookDefinition book,
    List<int> ids,
    List<String> tokens,
  ) async {
    final db = await _openBook(book);
    final placeholders = List.filled(ids.length, '?').join(',');
    switch (book.source) {
      case CorpusSource.sahifa:
      case CorpusSource.fatwa:
        final rows = await db.rawQuery('SELECT * FROM (${_extraQuery(book)}) WHERE record_id IN ($placeholders)', ids);
        return {for (final row in rows) _asInt(row['record_id'])!: Passage.fromMap(row)};
      case CorpusSource.hadith:
        final rows = await db.rawQuery('''
          SELECT COALESCE(NULLIF(p.ID, ''), -p.rowid) AS record_id, p.txt AS arabic, p.Secid AS section_id,
                 p.paganum AS page_no, p.mean AS urdu,
                 COALESCE(s.title, '') AS section_title,
                 COALESCE(c.title, '') AS chapter_title
          FROM Parags AS p
          LEFT JOIN Sections AS s ON s.Secid = p.Secid
          LEFT JOIN Chaps AS c ON c.cid = s.Chapid
          WHERE COALESCE(NULLIF(p.ID, ''), -p.rowid) IN ($placeholders)
        ''', ids);
        return {
          for (final row in rows)
            if (_asInt(row['record_id']) != null) _asInt(row['record_id'])!: Passage.fromMap(row),
        };
      case CorpusSource.quran:
        final rows = await db.rawQuery('''
          SELECT q.ID AS record_id, q.Arabic AS arabic, q.tr AS urdu, q.talighe AS commentary,
                 q.chapter AS container_type, q.chapter AS container_id, q.page AS page_no,
                 q.juz AS juz, q.verse AS verse, COALESCE(cp.Name, '') AS surah_name
          FROM Quran AS q LEFT JOIN ChapterProperty AS cp ON cp.Id = q.chapter
          WHERE q.ID IN ($placeholders)
        ''', ids);
        return {
          for (final row in rows)
            if (_asInt(row['record_id']) != null) _asInt(row['record_id'])!: _quranPassage(row),
        };
      case CorpusSource.balagha:
        final result = <int, Passage>{};
        for (final id in ids) {
          final passage = await getPassageById(book, id);
          if (passage != null) result[id] = passage;
        }
        return result;
      case CorpusSource.dua:
        final rows = await db.rawQuery('''
          SELECT m.rowid AS record_id, m.M_name AS section_title, m.M_cat_id AS container_type,
                 m._id AS container_id
          FROM M_items AS m WHERE m.rowid IN ($placeholders)
        ''', ids);
        final itemIds = rows.map((row) => _asInt(row['container_id'])).whereType<int>().toList();
        final lineRows = itemIds.isEmpty
            ? <Map<String, Object?>>[]
            : await db.rawQuery('''
                SELECT L_M_id, L_text, L_Translate, L_prio, L_type
                FROM Lines WHERE L_M_id IN (${List.filled(itemIds.length, '?').join(',')})
                ORDER BY L_M_id, L_prio, rowid
              ''', itemIds);
        final linesByItem = <int, List<Map<String, Object?>>>{};
        for (final row in lineRows) {
          final key = _asInt(row['L_M_id']);
          if (key == null) continue;
          linesByItem.putIfAbsent(key, () => []).add(row);
        }
        final result = <int, Passage>{};
        for (final row in rows) {
          final recordId = _asInt(row['record_id']);
          final itemId = _asInt(row['container_id']);
          if (recordId == null || itemId == null) continue;
          final lines = linesByItem[itemId] ?? const [];
          final best = _bestMatchingLine(lines, tokens);
          final category = _asInt(row['container_type']) ?? 0;
          final title = _compact((row['section_title'] ?? '').toString());
          if (best == null) {
            result[recordId] = Passage(
              recordId: recordId,
              arabic: '',
              urdu: title,
              containerType: category,
              containerId: recordId,
              chapterTitle: duaCategoryTitles[category] ?? 'مفاتیح الجنان',
              sectionTitle: title,
            );
            continue;
          }
          final text = _compact((best['L_text'] ?? '').toString());
          final translate = _compact((best['L_Translate'] ?? '').toString());
          final isNote = _asInt(best['L_type']) == 2 || translate.isEmpty || translate == '0';
          result[recordId] = Passage(
            recordId: recordId,
            arabic: isNote ? '' : text,
            urdu: isNote ? text : translate,
            containerType: category,
            containerId: recordId,
            chapterTitle: duaCategoryTitles[category] ?? 'مفاتیح الجنان',
            sectionTitle: title,
          );
        }
        return result;
    }
  }

  Map<String, Object?>? _bestMatchingLine(List<Map<String, Object?>> lines, List<String> tokens) {
    if (lines.isEmpty) return null;
    Map<String, Object?>? best;
    var bestScore = -1;
    for (final line in lines) {
      final blob = '${line['L_text'] ?? ''} ${line['L_Translate'] ?? ''}';
      final score = relevanceScore(blob, tokens);
      if (score > bestScore) {
        bestScore = score;
        best = line;
      }
    }
    return best ?? lines.first;
  }

  Future<List<SearchHit>> searchMany(
    List<String> queries, {
    int limit = 12,
    String? bookKey,
    String language = 'all',
    CorpusSource? source,
  }) async {
    final seen = <String>{};
    final merged = <SearchHit>[];
    for (final query in queries.take(12)) {
      if (query.trim().isEmpty) continue;
      final batch = await search(
        query,
        limit: limit,
        bookKey: bookKey,
        language: language,
        source: source,
      );
      for (final hit in batch) {
        final id = '${hit.book.key}:${hit.passage.recordId}';
        if (seen.add(id)) merged.add(hit);
      }
    }
    if (merged.isEmpty) return const [];
    final terms = queries.expand(searchTokens).toSet();
    int scoreOf(SearchHit hit) {
      final title =
          relevanceScore('${hit.passage.chapterTitle} ${hit.passage.sectionTitle}', terms) * 4;
      final body = relevanceScore(
        '${hit.passage.arabic} ${hit.passage.urdu} ${hit.passage.commentary}',
        terms,
      );
      return title + body;
    }

    merged.sort((left, right) => scoreOf(right).compareTo(scoreOf(left)));
    return merged.take(limit).toList();
  }

  Future<List<Map<String, Object?>>> _searchFts(
    String expression,
    int limit,
    String? bookKey,
    CorpusSource? source,
  ) async {
    if (expression.isEmpty || _searchDatabase == null) return [];
    final where = <String>[];
    final args = <Object?>[expression];
    if (bookKey != null) {
      where.add('d.book = ?');
      args.add(bookKey);
    }
    if (source != null) {
      final keys = _installedBookKeysFor(source);
      if (keys.isEmpty) return [];
      where.add('d.book IN (${List.filled(keys.length, '?').join(',')})');
      args.addAll(keys);
    }
    args.add(limit);
    final clause = where.isEmpty ? '' : ' AND ${where.join(' AND ')}';
    final rank = _ftsEngine == 'fts5' ? 'bm25(search_fts, 0.35, 0.6, 1.2, 1.2)' : 'd.id';
    try {
      return await _searchDatabase!.rawQuery('''
        SELECT d.*, $rank AS rank
        FROM search_fts
        JOIN search_docs AS d ON d.id = search_fts.rowid
        WHERE search_fts MATCH ?$clause
        ORDER BY rank
        LIMIT ?
      ''', args);
    } catch (_) {
      return [];
    }
  }

  List<String> _installedBookKeysFor(CorpusSource source) => BookDefinition.all
      .where((book) => book.source == source && _installed.contains(book.key))
      .map((book) => book.key)
      .toList();

  Future<List<Map<String, Object?>>> _searchNormalizedLike(
    List<String> tokens,
    int limit,
    String? bookKey,
    CorpusSource? source,
  ) async {
    if (_searchDatabase == null || tokens.isEmpty) return [];
    final conditions = <String>[];
    final args = <Object?>[];
    for (final token in tokens) {
      conditions.add("COALESCE(d.norm_text, '') LIKE ?");
      args.add(likeNeedle(token));
    }
    if (bookKey != null) {
      conditions.add('d.book = ?');
      args.add(bookKey);
    }
    if (source != null) {
      final keys = _installedBookKeysFor(source);
      if (keys.isEmpty) return [];
      conditions.add('d.book IN (${List.filled(keys.length, '?').join(',')})');
      args.addAll(keys);
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

  // ------------------------------------------------------ saved user state

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
    }).where((target) => target.recordId != 0).toList();
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
      if (!_installed.contains(book.key)) continue;
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
    if (BookDefinition.byKey(parts.first) == null || recordId == 0) return null;
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
    _installed.clear();
    _initialized = false;
  }
}

String _compact(String value) {
  if (value.isEmpty) return value;
  var text = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.replaceAll('\u0640', '');
  text = text.replaceAll(RegExp(r'[\u200e\u200f\u200b\ufeff]'), '');
  text = text.replaceAll(RegExp(r'[^\S\n]+'), ' ');
  text = text.replaceAll(RegExp(r' *\n *'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

int? _asInt(Object? value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
