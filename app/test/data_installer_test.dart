import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/data_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retries another mirror after a corrupt gzip payload', () async {
    final source = await File('assets/databases/nahjul_balagha_v2.db').readAsBytes();
    final validGzip = gzip.encode(source);
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.host == 'github.com') {
        // Valid gzip signature, but truncated before a complete stream.
        return http.Response.bytes([0x1f, 0x8b, 0x08, 0x00], 200);
      }
      if (request.url.host == 'raw.githubusercontent.com' &&
          request.url.path.endsWith('nahjul_balagha_v2.db.gz')) {
        return http.Response.bytes(validGzip, 200);
      }
      return http.Response('', 404);
    });
    final directory = await Directory.systemTemp.createTemp('shiaverse-installer-test-');
    final installer = DataInstaller(directory: () => directory, client: client);

    try {
      final catalog = await installer.loadCatalog(allowNetwork: false);
      final package = catalog.byKey('nahjul_balagha')!;

      await installer.install(package);

      expect(requests, hasLength(2));
      expect(requests.first.host, 'github.com');
      expect(requests.last.host, 'raw.githubusercontent.com');
      expect(await File('${directory.path}/${package.fileName}').readAsBytes(), source);
      expect(await File('${directory.path}/${package.fileName}.part').exists(), isFalse);
    } finally {
      await installer.close();
      await directory.delete(recursive: true);
    }
  });
}
