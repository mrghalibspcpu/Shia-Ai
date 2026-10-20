import 'dart:convert';

/// One downloadable database described by `assets/database-manifest.json`.
///
/// This file has no Flutter imports on purpose: the catalog is plain data so it
/// can be parsed, merged, and unit tested without a widget binding.
class DataPackage {
  const DataPackage({
    required this.key,
    required this.fileName,
    required this.titleUrdu,
    required this.titleLatin,
    required this.source,
    required this.sizeBytes,
    required this.sha256,
  });

  final String key;
  final String fileName;
  final String titleUrdu;
  final String titleLatin;
  final String source;
  final int sizeBytes;
  final String sha256;

  factory DataPackage.fromJson(Map<String, dynamic> json) => DataPackage(
        key: (json['key'] ?? '').toString(),
        fileName: (json['name'] ?? '').toString(),
        titleUrdu: (json['title_urdu'] ?? '').toString(),
        titleLatin: (json['title_latin'] ?? '').toString(),
        source: (json['source'] ?? 'hadith').toString(),
        sizeBytes: _asInt(json['size_bytes']) ?? 0,
        sha256: (json['sha256'] ?? '').toString().toLowerCase(),
      );

  bool get isDownloadable => fileName.isNotEmpty && sha256.length == 64 && sizeBytes > 0;
}

/// The parsed manifest: what exists, how big it is, and where to fetch it.
class DataCatalog {
  const DataCatalog({
    required this.packages,
    required this.baseUrls,
    this.extension = '.gz',
  });

  final List<DataPackage> packages;
  final List<String> baseUrls;
  final String extension;

  static const DataCatalog empty = DataCatalog(packages: [], baseUrls: []);

  factory DataCatalog.fromJson(Map<String, dynamic> json) {
    final rawPackages = json['databases'];
    final packages = <DataPackage>[];
    if (rawPackages is List) {
      for (final entry in rawPackages) {
        if (entry is Map) {
          final package = DataPackage.fromJson(Map<String, dynamic>.from(entry));
          if (package.key.isNotEmpty && package.fileName.isNotEmpty) packages.add(package);
        }
      }
    }
    final download = json['download'] is Map
        ? Map<String, dynamic>.from(json['download'] as Map)
        : const <String, dynamic>{};
    final rawUrls = download['base_urls'];
    final baseUrls = <String>[];
    if (rawUrls is List) {
      for (final url in rawUrls) {
        final text = url.toString().trim();
        if (text.isEmpty) continue;
        baseUrls.add(text.endsWith('/') ? text : '$text/');
      }
    }
    return DataCatalog(
      packages: packages,
      baseUrls: baseUrls,
      extension: (download['extension'] ?? '.gz').toString(),
    );
  }

  static DataCatalog parse(String raw) {
    // A truncated or corrupt manifest must never take the app down: the caller
    // falls back to the bundled copy or to a fresh download.
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return empty;
      return DataCatalog.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return empty;
    }
  }

  DataPackage? byKey(String key) {
    for (final package in packages) {
      if (package.key == key) return package;
    }
    return null;
  }

  bool get isEmpty => packages.isEmpty;

  int get totalBytes => packages.fold(0, (sum, package) => sum + package.sizeBytes);
}

/// Candidate URLs for one file, in the order they should be attempted.
///
/// A build may pin its own mirror with `--dart-define=SHIA_DATA_BASE_URL`; the
/// manifest's own list (GitHub Releases, then the repository itself) follows.
List<String> downloadUrlsFor({
  required DataPackage package,
  required List<String> baseUrls,
  required String extension,
  String? overrideBaseUrl,
}) {
  final ordered = <String>[];
  final override = (overrideBaseUrl ?? '').trim();
  if (override.isNotEmpty) {
    ordered.add(override.endsWith('/') ? override : '$override/');
  }
  for (final base in baseUrls) {
    if (!ordered.contains(base)) ordered.add(base);
  }
  return [
    for (final base in ordered) '$base${package.fileName}$extension',
    for (final base in ordered) '$base${package.fileName}',
  ];
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final decimals = unit >= 2 ? 0 : (value < 10 ? 1 : 0);
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}

int? _asInt(Object? value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
