bool looksLikeGeminiApiKey(String value) {
  final key = value.trim();
  if (key.startsWith('AIza') && key.length >= 30 && key.length <= 80) {
    return !key.contains(RegExp(r'\s')) && !key.contains('://');
  }
  return false;
}

String compactDisplayText(String value) {
  if (value.isEmpty) return value;
  var text = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.replaceAll('\u0640', '');
  text = text.replaceAll(RegExp(r'[\u200e\u200f\u200b\ufeff]'), '');
  text = text.replaceAll(RegExp(r'[^\S\n]+'), ' ');
  text = text.replaceAll(RegExp(r' *\n *'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

String normalizeArabicUrdu(String value) {
  var text = compactDisplayText(value).toLowerCase();
  text = text.replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF]'), '');
  text = text.replaceAll(RegExp(r'[\u0609-\u060D\u061B-\u061F\u066A-\u066D\u06D4\uFD3E\uFD3F]'), ' ');
  const variants = <String, String>{
    'آ': 'ا',
    'أ': 'ا',
    'إ': 'ا',
    'ٱ': 'ا',
    'ك': 'ک',
    'ي': 'ی',
    'ى': 'ی',
    'ة': 'ه',
    'ہ': 'ه',
    'ۃ': 'ه',
    'ۀ': 'ه',
  };
  variants.forEach((from, to) => text = text.replaceAll(from, to));
  text = text.replaceAll(
    RegExp(r'[^a-z0-9\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFEFF]+'),
    ' ',
  );
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

List<String> searchTokens(String query, {int limit = 12}) {
  final seen = <String>{};
  final tokens = <String>[];
  for (final token in normalizeArabicUrdu(query).split(' ')) {
    if (token.isEmpty || token.length < 2 || !seen.add(token)) continue;
    tokens.add(token);
    if (tokens.length >= limit) break;
  }
  return tokens;
}

String escapeFtsToken(String token) {
  return token.replaceAll(RegExp(r'["*:()^~-]'), '');
}

String buildFtsQuery(
  List<String> tokens, {
  required bool fts4,
  required bool prefix,
  required bool andMode,
}) {
  final parts = <String>[];
  for (final token in tokens) {
    final clean = escapeFtsToken(token);
    if (clean.isEmpty) continue;
    if (fts4) {
      parts.add(prefix ? '$clean*' : clean);
    } else {
      parts.add(prefix ? '"$clean"*' : '"$clean"');
    }
  }
  if (parts.isEmpty) return '';
  return parts.join(andMode ? ' AND ' : ' OR ');
}

String likeNeedle(String token) {
  return '%${token.replaceAll('%', '').replaceAll('_', '')}%';
}

bool hasUrduLetters(String text) => RegExp(r'[پچژگٹڈڑںےھکیہۍ]').hasMatch(text);

bool hasArabicScript(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x0600 && rune <= 0x08FF) || (rune >= 0xFB50 && rune <= 0xFEFF)) {
      return true;
    }
  }
  return false;
}

String noMatchMessage(String question) {
  if (hasUrduLetters(question)) {
    return 'مقامی کتب میں اس سوال کے مطابق روایت نہیں ملی۔ دوسرا لفظ یا مختصر کلیدی لفظ آزمائیں۔';
  }
  if (hasArabicScript(question)) {
    return 'لم أعثر على رواية مطابقة في الكتب المحلية. جرّب كلمة مفتاحية أقصر.';
  }
  return 'No matching narration was found in the local books. Try a shorter keyword.';
}

String localGroundedAnswer(String question, List<String> excerpts) {
  final buffer = StringBuffer();
  if (hasUrduLetters(question) || hasArabicScript(question)) {
    buffer.writeln('مقامی کتب سے یہ متعلقہ روایات ملی ہیں:');
  } else {
    buffer.writeln('These matching records were found in the local books:');
  }
  buffer.writeln();
  for (var i = 0; i < excerpts.length; i++) {
    buffer.writeln(excerpts[i]);
    if (i != excerpts.length - 1) buffer.writeln();
  }
  buffer.writeln();
  buffer.write(
    'مکمل شیعہ اے آئی جواب کے لیے سیٹنگز میں Google AI Studio کی API کلید (AIza…) درج کریں۔',
  );
  return buffer.toString().trim();
}

String formatCitation({
  required String bookTitle,
  required String chapterTitle,
  required String sectionTitle,
  required int recordId,
  int? page,
}) {
  final parts = <String>[bookTitle];
  if (chapterTitle.isNotEmpty) parts.add(chapterTitle);
  if (sectionTitle.isNotEmpty) parts.add(sectionTitle);
  parts.add('حدیث نمبر $recordId');
  if (page != null) parts.add('صفحہ $page');
  return parts.join(' · ');
}
