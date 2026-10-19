import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_ai/data_packages.dart';
import 'package:shia_ai/models.dart';

/// The Xplore **اثنا عشری انسائکلوپیڈیا** book. These checks run without any database: they pin the wiring
/// (model, manifest, packaged asset) so a broken download can never ship.
void main() {
  final manifestFile = File('assets/database-manifest.json');
  final packedFile = File('../assets/athna_ashari_encyclopedia_v2.db.gz');

  test('the encyclopaedia is a normal library book', () {
    final book = BookDefinition.byKey('athna_ashari_encyclopedia');
    expect(book, isNotNull);
    expect(book!.titleUrdu, 'اثنا عشری انسائکلوپیڈیا');
    expect(book.fileName, 'athna_ashari_encyclopedia_v2.db');
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
    expect(package!.fileName, 'athna_ashari_encyclopedia_v2.db');
    expect(package.titleUrdu, 'اثنا عشری انسائکلوپیڈیا');
    expect(package.source, 'encyclopedia');
    expect(package.sha256, hasLength(64));
    expect(package.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    // The prose-only edition is around 10 MB; a manifest line advertising a
    // small or empty file would mean the build silently lost the corpus.
    expect(package.sizeBytes, greaterThan(5 * 1024 * 1024));
    expect(package.isDownloadable, isTrue);
    // The app packages every database gzipped; the encyclopaedia is no
    // exception, and the installer unpacks and hashes it like the rest.
    expect(catalog.extension, '.gz');
    // The checked-in app copy of the manifest is the same document.
    expect(File('assets/database-manifest.json').readAsStringSync(),
        File('../assets/database-manifest.json').readAsStringSync());
  });

  test('the committed .gz expands to exactly the published edition', () {
    expect(packedFile.existsSync(), isTrue,
        reason: 'assets/athna_ashari_encyclopedia_v2.db.gz must be committed');
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
