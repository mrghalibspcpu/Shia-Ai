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
String arabicNumerals(int value) =>
    value.toString().split('').map((digit) => digit == '-' ? digit : _arabicDigits[int.parse(digit)!]).join();

String formatCitation({
  required String bookTitle,
  required String chapterTitle,
  required String sectionTitle,
  required int recordId,
  int? page,
  String recordLabel = 'حدیث نمبر',
}) {
  final lines = <String>['کتاب: $bookTitle'];
  if (chapterTitle.isNotEmpty) lines.add('جلد / باب: $chapterTitle');
  if (sectionTitle.isNotEmpty) lines.add('فصل: $sectionTitle');
  lines.add('$recordLabel: $recordId');
  if (page != null) lines.add('صفحہ: $page');
  return lines.join('\n');
}
