import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_ai/data_packages.dart';
import 'package:shia_ai/models.dart';

/// The **نئی کتابیں** shelf and its first book, the Shia Urdu Wikipedia
/// collection. These checks run without any database: they pin the wiring
/// (model, manifest, packaged asset) so a broken download can never ship.
void main() {
  final manifestFile = File('assets/database-manifest.json');
  final packedFile = File('../assets/shia_urdu_wikipedia.db.gz');

  test('the Wikipedia collection is a normal library book', () {
    final wiki = BookDefinition.byKey('shia_wiki');
    expect(wiki, isNotNull);
    expect(wiki!.titleUrdu, 'شیعہ اردو ویکیپیڈیا');
    expect(wiki.fileName, 'shia_urdu_wikipedia.db');
    expect(wiki.source, CorpusSource.wiki);
    expect(wiki.source.label, 'نئی کتابیں');
    // It must not leak into the hadith shelf (that list drives the library
    // page and the per-book download prompts).
    expect(BookDefinition.hadithBooks.map((book) => book.key), isNot(contains('shia_wiki')));
    expect(BookDefinition.newBooks.map((book) => book.key), <String>['shia_wiki']);
    expect(BookDefinition.all.where((book) => book.key == 'shia_wiki'), hasLength(1));
    // Appended last, so every existing book keeps the accent colour it had.
    expect(BookDefinition.all.last.key, 'shia_wiki');
    expect(BookDefinition.bookFor(CorpusSource.wiki)!.key, 'shia_wiki');
  });

  test('the manifest publishes the reader edition with a real digest', () {
    final catalog = DataCatalog.parse(manifestFile.readAsStringSync());
    final package = catalog.byKey('shia_wiki');
    expect(package, isNotNull);
    expect(package!.fileName, 'shia_urdu_wikipedia.db');
    expect(package.titleUrdu, 'شیعہ اردو ویکیپیڈیا');
    expect(package.source, 'wiki');
    expect(package.sha256, hasLength(64));
    expect(package.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(package.sizeBytes, greaterThan(50 * 1024 * 1024));
    expect(package.isDownloadable, isTrue);
    // The app packages every database gzipped; the Wikipedia edition is no
    // exception, and the installer unpacks and hashes it like the rest.
    expect(catalog.extension, '.gz');
    // The checked-in app copy of the manifest is the same document.
    expect(File('assets/database-manifest.json').readAsStringSync(),
        File('../assets/database-manifest.json').readAsStringSync());
  });

  test('the committed .gz expands to exactly the published edition', () async {
    expect(packedFile.existsSync(), isTrue,
        reason: 'assets/shia_urdu_wikipedia.db.gz must be committed');
    final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final entry = (manifest['databases'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['key'] == 'shia_wiki');
    // 57 MB: fine for a test runner, and it proves the committed asset is
    // byte-for-byte the database the manifest promises to every phone.
    final bytes = gzip.decode(packedFile.readAsBytesSync());
    expect(bytes.length, entry['size_bytes']);
    // A real SQLite database, not a text file or a truncated download.
    expect(utf8.decode(bytes.sublist(0, 15)), 'SQLite format 3');
    expect(sha256.convert(bytes).toString(), entry['sha256']);
  });
}
