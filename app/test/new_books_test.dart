import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiaverse/data_packages.dart';
import 'package:shiaverse/models.dart';

/// The **نئی کتابیں** shelf and its first book, **اثنا عشری انسائکلوپیڈیا**.
///
/// Since 1.20 the edition is the Urdu-Wikipedia corpus **merged** with the
/// Wikishia topic notes, so these checks also pin that merge: the shipped
/// database must contain both sources, the merged article count, and a
/// revision URL on every imported section.
void main() {
  final manifestFile = File('assets/database-manifest.json');
  final packedFile = File('../assets/athna_ashari_encyclopedia.db.gz');

  test('the encyclopaedia is a normal library book', () {
    final book = BookDefinition.byKey('athna_ashari_encyclopedia');
    expect(book, isNotNull);
    expect(book!.titleUrdu, 'اثنا عشری انسائکلوپیڈیا');
    expect(book.fileName, 'athna_ashari_encyclopedia.db');
    expect(book.source, CorpusSource.encyclopedia);
    expect(book.source.label, 'نئی کتابیں');
    // It must not leak into the hadith shelf (that list drives the library
    // page and the per-book download prompts).
    expect(BookDefinition.hadithBooks.map((book) => book.key),
        isNot(contains('athna_ashari_encyclopedia')));
    expect(BookDefinition.newBooks.map((book) => book.key),
        <String>['athna_ashari_encyclopedia']);
    expect(BookDefinition.all.where((book) => book.key == 'athna_ashari_encyclopedia'),
        hasLength(1));
    // Appended last, so every existing book keeps the accent colour it had.
    expect(BookDefinition.all.last.key, 'athna_ashari_encyclopedia');
    expect(BookDefinition.bookFor(CorpusSource.encyclopedia)!.key,
        'athna_ashari_encyclopedia');
  });

  test('the retired Wikipedia collection is gone from the catalogue', () {
    expect(BookDefinition.byKey('shia_wiki'), isNull);
    expect(BookDefinition.newBooks.map((book) => book.key), isNot(contains('shia_wiki')));
    expect(CorpusSource.values.map((source) => source.wire), isNot(contains('wiki')));
    final manifest = manifestFile.readAsStringSync();
    expect(manifest.contains('shia_urdu_wikipedia'), isFalse);
    expect(manifest.contains('"wiki"'), isFalse);
  });

  test('the manifest publishes the reader edition with a real digest', () {
    final catalog = DataCatalog.parse(manifestFile.readAsStringSync());
    final package = catalog.byKey('athna_ashari_encyclopedia');
    expect(package, isNotNull);
    expect(package!.fileName, 'athna_ashari_encyclopedia.db');
    expect(package.titleUrdu, 'اثنا عشری انسائکلوپیڈیا');
    expect(package.source, 'encyclopedia');
    expect(package.sha256, hasLength(64));
    expect(package.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    // The prose-only edition is around 10 MB; a manifest line advertising a
    // small or empty file would mean the build silently lost the corpus.
    // Wikipedia (574 articles) + Wikishia notes (61 new articles) is ~11 MB.
    expect(package.sizeBytes, greaterThan(9 * 1024 * 1024));
    expect(package.isDownloadable, isTrue);
    // The app packages every database gzipped; the encyclopaedia is no
    // exception, and the installer unpacks and hashes it like the rest.
    expect(catalog.extension, '.gz');
    // The checked-in app copy of the manifest is the same document.
    expect(File('assets/database-manifest.json').readAsStringSync(),
        File('../assets/database-manifest.json').readAsStringSync());
  });

  test('the shipped edition really contains the merged Wikishia notes', () {
    // The merge lives in scripts/merge_wikishia_notes.py. This pins the bytes
    // committed here: the Wikishia revision pages and a note-only topic are in
    // the same database as the Wikipedia articles, and the title has no
    // «(منتخب)» suffix any more.
    final bytes = gzip.decode(packedFile.readAsBytesSync());
    final text = utf8.decode(bytes, allowMalformed: true);
    expect(text.contains('https://ur.wikishia.net/w/index.php?title='), isTrue,
        reason: 'every imported section keeps its Wikishia revision URL');
    expect(text.contains('ur.wikipedia.org'), isTrue,
        reason: 'the Wikipedia articles must survive the merge');
    expect(text.contains('مرجع تقلید'), isTrue,
        reason: 'a topic that only the Wikishia notes carry');
    final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final entry = (manifest['databases'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['key'] == 'athna_ashari_encyclopedia');
    expect(entry['title_ur'], 'اثنا عشری انسائکلوپیڈیا');
    expect(entry['sha256'], hasLength(64));
  });

  test('the committed .gz expands to exactly the published edition', () {
    expect(packedFile.existsSync(), isTrue,
        reason: 'assets/athna_ashari_encyclopedia.db.gz must be committed');
    final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final entry = (manifest['databases'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['key'] == 'athna_ashari_encyclopedia');
    final bytes = gzip.decode(packedFile.readAsBytesSync());
    expect(bytes.length, entry['size_bytes']);
    // A real SQLite database, not a text file or a truncated download.
    expect(utf8.decode(bytes.sublist(0, 15)), 'SQLite format 3');
    expect(sha256.convert(bytes).toString(), entry['sha256']);
  });
}
