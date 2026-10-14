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

const Set<String> kSearchStopwords = {
  'کو', 'کر', 'کے', 'کی', 'کا', 'ہے', 'ہیں', 'تھا', 'تھی', 'تھے', 'کیا', 'کیسا', 'کیسے', 'کیسی',
  'بارے', 'میں', 'سے', 'پر', 'اور', 'یا', 'یہ', 'وہ', 'ہم', 'آپ', 'نہ', 'نہیں', 'نا', 'ہی', 'تو',
  'بھی', 'ایک', 'لیے', 'لئے', 'والا', 'والی', 'والے', 'ہو', 'ہوگا', 'ہوگی', 'ہوگے', 'ہونا',
  'اپنا', 'اپنی', 'اپنے', 'اس', 'ان', 'جو', 'جس', 'جن', 'تاکہ', 'اگر', 'لیکن', 'پھر', 'اب',
  'بتائیں', 'بتاو', 'بتاؤ', 'سمجھائیں', 'جواب', 'سوال', 'پوچھیں', 'چاہیے', 'چاهیے',
  'the', 'a', 'an', 'is', 'are', 'was', 'of', 'in', 'to', 'for', 'how', 'what', 'why',
  'when', 'where', 'who', 'with', 'about', 'please', 'me', 'my', 'your',
  'في', 'من', 'على', 'الى', 'عن', 'ما', 'هل', 'كيف', 'ماذا', 'الذي', 'التي', 'هذا', 'هذه',
  'و', 'أو', 'لا', 'إن', 'أن', 'ف', 'ثم', 'قد', 'لم', 'لن',
};

String stemToken(String token) {
  var text = token;
  const suffixes = ['یوں', 'وں', 'یاں', 'یں', 'ین', 'ات', 'گی', 'گے', 'گا', 'نا', 'نی', 'نے'];
  for (final suffix in suffixes) {
    if (text.endsWith(suffix) && text.length - suffix.length >= 3) {
      text = text.substring(0, text.length - suffix.length);
      break;
    }
  }
  if (text.startsWith('ال') && text.length > 5) text = text.substring(2);
  return text;
}

List<String> searchTokens(String query, {int limit = 12}) {
  final seen = <String>{};
  final tokens = <String>[];
  for (final raw in normalizeArabicUrdu(query).split(' ')) {
    if (raw.isEmpty || kSearchStopwords.contains(raw)) continue;
    final token = stemToken(raw);
    if (token.length < 3 || kSearchStopwords.contains(token) || !seen.add(token)) continue;
    tokens.add(token);
    if (tokens.length >= limit) break;
  }
  return tokens;
}

const List<(List<String>, List<String>)> kTopicExpansions = [
  (
    [
      'ملا کر', 'ملاکر', 'جمع بین', 'صلاتین', 'صلوٰتین', 'دو نماز', 'نمازوں کو ملا', 'نمازیں جمع',
      'mila kar', 'milakar', 'jama kar', 'combine namaz', 'combine prayer', 'jam bayn',
    ],
    ['جمع بین الصلاتین', 'جمع بین الصلوٰتین', 'يجمع بين الصلاتين', 'ظہر اور عصر جمع'],
  ),
  (
    ['وضو', 'وضوء', 'الو ضوء'],
    ['وضو', 'الوضوء', 'کیفیت وضو'],
  ),
  (
    ['تیمم', 'تيمم'],
    ['تیمم', 'التيمم'],
  ),
  (
    ['غسل جنابت', 'غسل', 'جنابت'],
    ['غسل جنابت', 'الغسل'],
  ),
  (
    ['مسافر', 'قصر', 'شکستہ نماز'],
    ['نماز مسافر', 'تقصیر', 'صلاة المسافر'],
  ),
  (
    ['نماز جمعہ', 'جمعہ کی نماز'],
    ['نماز جمعہ', 'صلاة الجمعة'],
  ),
  (
    ['خمس'],
    ['خمس', 'الخمس'],
  ),
  (
    ['زکوٰة', 'زکوة', 'زکوۃ', 'زكاة'],
    ['زکوٰة', 'الزكاة'],
  ),
  (
    ['متحہ', 'متعہ', 'نکاح موقت'],
    ['متعہ', 'المتعة', 'نکاح موقت'],
  ),
  (
    ['غدیٖر', 'غدیر', 'ولایت'],
    ['غدیر خم', 'من کنت مولاه', 'ولایت علی'],
  ),
  (
    [
      'کربلا', 'كربلا', 'عاشور', 'حسین', 'شهید', 'شہید', 'مقتل',
      'hussain', 'husain', 'hussein', 'husein',
      'karbala', 'ashura', 'aashura', 'shaheed', 'shadeed',
      'yazid', 'yazeed', 'ziyad', 'shimr', 'shimar', 'shimer',
      'harmala', 'harmalah', 'maqtal', 'maktel',
    ],
    [
      'قتل الحسین',
      'مقتل الحسین',
      'امام حسین',
      'کربلا',
      'یزید بن معاویہ',
      'عبید اللہ بن زیاد',
      'عمر بن سعد',
      'شمر بن ذی الجوشن',
      'حرملہ',
      'عاشوراء',
    ],
  ),
  (
    ['namaz', 'namaaz', 'salat', 'salaat'],
    ['نماز', 'الصلاة'],
  ),
  (
    ['wazu', 'wuzu', 'wudhu', 'wazo', 'wudu'],
    ['وضو', 'الوضوء'],
  ),
  (
    ['roza', 'rozah', 'sawm', 'siyam'],
    ['روزہ', 'الصوم'],
  ),
  (
    ['khums', 'khumus'],
    ['خمس', 'الخمس'],
  ),
  (
    ['mutah', 'muta'],
    ['متعہ', 'المتعة'],
  ),
  (
    ['ghadir', 'ghadeer'],
    ['غدیر خم', 'من کنت مولاه'],
  ),
  (
    ['mahdi', 'mehdi', 'imam zaman'],
    ['امام مہدی', 'صاحب الزمان', 'الغیبة'],
  ),
  (
    ['مہدی', 'امام زمان', 'غیبت'],
    ['امام مہدی', 'الغیبة', 'صاحب الزمان'],
  ),
  (
    ['جنازہ', 'میٹ کی نماز'],
    ['نماز جنازہ', 'صلاة الجنازة'],
  ),
  (
    ['حج', 'عمرہ'],
    ['الحج', 'العمرة'],
  ),
];

List<String> expandSearchQueries(String question) {
  final original = question.trim();
  if (original.isEmpty) return const [];
  final norm = ' ${normalizeArabicUrdu(original)} ';
  final scripted = hasUrduLetters(original) || hasArabicScript(original);
  final queries = <String>[];
  void add(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    if (queries.every((item) => item != text)) queries.add(text);
  }

  // Latin-only (Roman Urdu / English) questions do not exist in the FTS index.
  if (scripted) add(original);
  for (final entry in kTopicExpansions) {
    final triggered = entry.$1.any((trigger) {
      final needle = normalizeArabicUrdu(trigger);
      return needle.isNotEmpty && norm.contains(needle);
    });
    if (triggered) {
      for (final extra in entry.$2) {
        add(extra);
      }
    }
  }
  if (scripted) {
    final tokens = searchTokens(original);
    if (tokens.length >= 2) add(tokens.take(4).join(' '));
  }
  if (queries.isEmpty) add(original);
  return queries;
}

int relevanceScore(String blob, Iterable<String> terms) {
  final haystack = normalizeArabicUrdu(blob);
  if (haystack.isEmpty) return 0;
  var score = 0;
  for (final term in terms) {
    final needle = normalizeArabicUrdu(term);
    if (needle.isEmpty) continue;
    if (haystack.contains(needle)) score += needle.length + 2;
  }
  return score;
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

const List<String> _arabicDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// Renders a number with Arabic-Indic digits, as used across the Urdu corpus.
String arabicNumerals(int value) => value.toString().split('').map((digit) {
      final parsed = int.tryParse(digit);
      if (parsed == null || parsed < 0 || parsed >= _arabicDigits.length) return digit;
      return _arabicDigits[parsed];
    }).join();

/// Human citation for a passage: book, volume/chapter, section, the readable
/// locator (verse / juz / page), and the printed page when known.
///
/// It deliberately never prints the database row id. That number (e.g. a
/// `Parags.ID` like 562276) is an internal storage key — readers mistook it
/// for the hadith number, which it is not. Hadith are cited by book, chapter
/// and page, exactly as the printed editions do.
String formatCitation({
  required String bookTitle,
  required String chapterTitle,
  required String sectionTitle,
  String locator = '',
  int? page,
}) {
  final lines = <String>['کتاب: $bookTitle'];
  if (chapterTitle.isNotEmpty) lines.add('جلد / باب: $chapterTitle');
  if (sectionTitle.isNotEmpty) lines.add('فصل: $sectionTitle');
  if (locator.isNotEmpty) lines.add('حوالہ: $locator');
  if (page != null) lines.add('صفحہ: $page');
  return lines.join('\n');
}

/// Match normalized Arabic/Urdu text while preserving original UTF-16 offsets
/// for highlights and exact-word scrolling (including vowel marks).
List<({int start, int end})> searchMatchRanges(String text, String query) {
  final tokens = normalizeArabicUrdu(query).split(' ').where((t) => t.isNotEmpty).toSet();
  if (tokens.isEmpty) return const [];
  final buffer = StringBuffer();
  final starts = <int>[];
  final ends = <int>[];
  var offset = 0;
  var lastSpace = false;
  final ignored = RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF\u0640\u200e\u200f\u200b\ufeff]');
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final end = offset + char.length;
    if (ignored.hasMatch(char)) {
      if (ends.isNotEmpty) ends[ends.length - 1] = end;
    } else {
      final normalized = normalizeArabicUrdu(char);
      final part = normalized.isEmpty ? ' ' : normalized;
      if (part != ' ' || buffer.isEmpty || !lastSpace) {
        buffer.write(part);
        lastSpace = part == ' ';
        for (var i = 0; i < part.length; i++) { starts.add(offset); ends.add(end); }
      }
    }
    offset = end;
  }
  final normalized = buffer.toString();
  final ranges = <({int start, int end})>[];
  for (final token in tokens) {
    var from = 0;
    while (from < normalized.length) {
      final found = normalized.indexOf(token, from);
      if (found < 0) break;
      ranges.add((start: starts[found], end: ends[found + token.length - 1]));
      from = found + token.length;
    }
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final merged = <({int start, int end})>[];
  for (final range in ranges) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final previous = merged.removeLast();
      merged.add((start: previous.start, end: range.end > previous.end ? range.end : previous.end));
    } else { merged.add(range); }
  }
  return merged;
}

/// Accept Latin, Urdu/Persian, and Arabic-Indic digits in jump fields.
int? parseReaderNumber(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var result = value.trim();
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
  }
  return int.tryParse(result);
}

/// Put the first match in the preview, even if it occurs near a record's end.
String searchSnippet(String text, String query, {int radius = 100}) {
  final matches = searchMatchRanges(text, query);
  if (matches.isEmpty || text.length <= radius * 2) return text;
  final match = matches.first;
  var start = (match.start - radius).clamp(0, text.length);
  var end = (match.end + radius).clamp(0, text.length);
  // Avoid breaking surrogate pairs in the rare non-Arabic text in the corpus.
  if (start > 0 && text.codeUnitAt(start) >= 0xDC00 && text.codeUnitAt(start) <= 0xDFFF) start--;
  if (end < text.length && text.codeUnitAt(end) >= 0xDC00 && text.codeUnitAt(end) <= 0xDFFF) end++;
  return '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}';
}
