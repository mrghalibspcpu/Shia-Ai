/// On-device retrieval for ShiaAi.
///
/// It reuses the existing SQLite collections, the normalized `search_docs`
/// index and the FTS/LIKE machinery of [LibraryRepository] — no cloud index,
/// no embedding service, and every result keeps its true book key and record
/// id. The layer on top only (1) expands Roman-Urdu questions into the Arabic
/// script the corpus is written in, (2) fans the question out into several
/// query variants, and (3) re-ranks the merged passages by term coverage so a
/// chat question behaves better than a bare keyword search.
library;

import '../library_repository.dart';
import '../models.dart';
import '../text_utils.dart';
import 'shia_ai_models.dart';

/// Roman-Urdu/English trigger → Arabic-script query terms.
///
/// `expandSearchQueries` already carries the biggest topic clusters (namaz,
/// wuzu, roza, khums, mutah, ghadir, karbala…). This map fills the everyday
/// fiqh vocabulary a chat question tends to use, and only ever ADDS Arabic
/// script variants — the index stores no Latin text, so Latin tokens alone
/// cannot match anything.
const Map<String, List<String>> kShiaAiRomanHints = <String, List<String>>{
  'wudu': ['وضو', 'الوضوء', 'کیفیت وضو'],
  'wuzu': ['وضو', 'الوضوء'],
  'wazoo': ['وضو', 'الوضوء'],
  'ghusl': ['غسل', 'الغسل'],
  'ghusal': ['غسل', 'الغسل'],
  'bath': ['غسل', 'الغسل'],
  'janabat': ['غسل جنابت', 'جنابت'],
  'tayammum': ['تیمم', 'التيمم'],
  'tayamum': ['تیمم', 'التيمم'],
  'namaz': ['نماز', 'الصلاة'],
  'namaaz': ['نماز', 'الصلاة'],
  'salat': ['نماز', 'الصلاة'],
  'prayer': ['نماز', 'الصلاة'],
  'roza': ['روزہ', 'الصوم'],
  'rozah': ['روزہ', 'الصوم'],
  'fasting': ['روزہ', 'الصوم'],
  'sawm': ['روزہ', 'الصوم'],
  'zakat': ['زکوٰة', 'الزكاة'],
  'zakaat': ['زکوٰة', 'الزكاة'],
  'khums': ['خمس', 'الخمس'],
  'hajj': ['الحج', 'حج'],
  'umrah': ['العمرة', 'عمرہ'],
  'umra': ['العمرة', 'عمرہ'],
  'nikah': ['نکاح', 'النکاح'],
  'marriage': ['نکاح', 'النکاح'],
  'talaq': ['طلاق', 'الطلاق'],
  'divorce': ['طلاق', 'الطلاق'],
  'mutah': ['متعہ', 'المتعة'],
  'muta': ['متعہ', 'المتعة'],
  'dua': ['دعا', 'الدعاء'],
  'duaa': ['دعا', 'الدعاء'],
  'quran': ['قرآن', 'القرآن'],
  'imam': ['امام', 'الائمہ'],
  'nabi': ['نبی', 'النبی'],
  'prophet': ['نبی', 'النبی', 'رسول'],
  'allah': ['اللہ', 'الله'],
  'jumuah': ['نماز جمعہ', 'صلاة الجمعة'],
  'jumma': ['نماز جمعہ', 'صلاة الجمعة'],
  'friday': ['نماز جمعہ', 'صلاة الجمعة'],
  'janaza': ['نماز جنازہ', 'صلاة الجنازة'],
  'funeral': ['نماز جنازہ', 'صلاة الجنازة'],
  'qasr': ['نماز مسافر', 'تقصیر'],
  'traveller': ['نماز مسافر', 'صلاة المسافر'],
  'musafir': ['نماز مسافر', 'صلاة المسافر'],
  'taqleed': ['تقلید', 'مرجع'],
  'marja': ['مرجع تقلید', 'تقلید'],
  'najis': ['نجاست', 'نجس'],
  'pak': ['طہارت', 'پاک'],
  'haiz': ['حیض'],
  'menstruation': ['حیض'],
  'istikhara': ['استخارہ'],
  'sadaqah': ['صدقہ', 'الصدقہ'],
  'charity': ['صدقہ', 'زکوٰة'],
  'rizq': ['رزق'],
  'shaitan': ['شیطان', 'الشيطان'],
  'qiyamah': ['قیامت', 'يوم القيامة'],
  'judgement': ['قیامت', 'يوم القيامة'],
  'mahdi': ['امام مہدی', 'صاحب الزمان', 'الغیبة'],
  'mehdi': ['امام مہدی', 'صاحب الزمان'],
  'ghadir': ['غدیر خم', 'من کنت مولاه'],
  'karbala': ['کربلا', 'مقتل الحسین', 'امام حسین'],
  'hussain': ['امام حسین', 'قتل الحسین'],
  'husain': ['امام حسین', 'قتل الحسین'],
  'hijab': ['حجاب', 'ستر'],
  'purdah': ['حجاب', 'ستر'],
};

/// At least this score marks a passage as strong evidence on its own.
const int kShiaAiStrongScore = 14;

/// A passage must contain at least one question term to survive re-ranking.
const int kShiaAiMinScore = 4;

/// The result of one retrieval pass.
class ShiaAiRetrieval {
  const ShiaAiRetrieval({
    required this.question,
    required this.queries,
    required this.terms,
    required this.evidence,
  });

  final String question;
  final List<String> queries;
  final Set<String> terms;
  final List<ShiaAiEvidence> evidence;

  bool get hasAny => evidence.isNotEmpty;

  /// Evidence is "enough" when one passage is strong, or at least two
  /// different passages each match real question terms. Everything below that
  /// is reported as insufficient instead of being sent for synthesis.
  bool get hasEnough =>
      evidence.any((item) => item.score >= kShiaAiStrongScore) ||
      evidence.where((item) => item.matchedTokens >= 1).length >= 2;

  /// Ids the synthesis layer is allowed to cite.
  Set<String> get evidenceIds =>
      evidence.map((item) => item.citationId).toSet();
}

class ShiaAiRetriever {
  ShiaAiRetriever({required this.library, this.maxPassages = 8});

  final LibraryRepository library;

  /// How many passages are handed to the synthesis service at most.
  final int maxPassages;

  /// Per-book cap so one large collection (e.g. Wasa'il) cannot crowd out
  /// every other source.
  static const int perBookCap = 3;

  /// All search variants for one question: the original wording, the existing
  /// topic expansions, and Roman-Urdu → Arabic-script hints.
  List<String> buildQueries(String question) {
    final original = question.trim();
    if (original.isEmpty) return const <String>[];
    final queries = <String>[];
    void add(String value) {
      final text = value.trim();
      if (text.isEmpty || queries.contains(text)) return;
      queries.add(text);
    }

    for (final variant in expandSearchQueries(original)) {
      add(variant);
    }

    final normalized = ' ${normalizeArabicUrdu(original)} ';
    final scripted =
        hasUrduLetters(original) || hasArabicScript(original);
    final romanAdditions = <String>[];
    kShiaAiRomanHints.forEach((trigger, targets) {
      final needle = normalizeArabicUrdu(trigger);
      if (needle.isNotEmpty && normalized.contains('$needle ')) {
        romanAdditions.addAll(targets);
      }
    });
    for (final term in romanAdditions) {
      add(term);
    }
    // A joined Urdu query from the first hints gives AND-style FTS a chance.
    if (!scripted && romanAdditions.isNotEmpty) {
      add(romanAdditions.take(3).join(' '));
    }
    if (queries.isEmpty) add(original);
    return queries.take(12).toList();
  }

  /// Runs every variant through the existing local search, then re-ranks and
  /// de-duplicates the merged hits.
  Future<ShiaAiRetrieval> retrieve(String question) async {
    final trimmed = question.trim();
    final queries = buildQueries(trimmed);
    final terms = <String>{};
    for (final query in queries) {
      terms.addAll(searchTokens(query));
    }
    if (trimmed.isEmpty || queries.isEmpty) {
      return ShiaAiRetrieval(
        question: trimmed,
        queries: queries,
        terms: terms,
        evidence: const <ShiaAiEvidence>[],
      );
    }

    final hits = await library.searchMany(queries, limit: 30);
    final seen = <String>{};
    final scored = <ShiaAiEvidence>[];
    for (final hit in hits) {
      final id = '${hit.book.key}:${hit.passage.recordId}';
      if (!seen.add(id)) continue;
      final result = scoreHit(hit, terms, normalizeArabicUrdu(trimmed));
      if (result.score < kShiaAiMinScore || result.matched == 0) continue;
      scored.add(ShiaAiEvidence.fromHit(
        hit,
        score: result.score,
        matchedTokens: result.matched,
      ));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      // Stable tie-break: book title then record id, so tests and phones
      // agree on the order.
      final byBook = a.bookKey.compareTo(b.bookKey);
      return byBook != 0 ? byBook : a.recordId.compareTo(b.recordId);
    });

    // Diversity cap after ranking: keep the best perBookCap passages per book.
    final perBook = <String, int>{};
    final diverse = <ShiaAiEvidence>[];
    for (final item in scored) {
      final count = perBook[item.bookKey] ?? 0;
      if (count >= perBookCap) continue;
      perBook[item.bookKey] = count + 1;
      diverse.add(item);
      if (diverse.length >= maxPassages) break;
    }

    return ShiaAiRetrieval(
      question: trimmed,
      queries: queries,
      terms: terms,
      evidence: diverse,
    );
  }

  /// Pure scoring (exposed for tests): title matches weigh heavily, the body
  /// contributes term coverage, an intact phrase gets a bonus, and matching a
  /// larger share of the question terms beats one repeated token.
  static ({int score, int matched}) scoreHit(
    SearchHit hit,
    Set<String> terms,
    String normalizedQuestion,
  ) {
    if (terms.isEmpty) return (score: 0, matched: 0);
    final passage = hit.passage;
    final titleBlob = normalizeArabicUrdu(
      '${hit.book.titleUrdu} ${passage.chapterTitle} ${passage.sectionTitle} ${passage.locator}',
    );
    final bodyBlob = normalizeArabicUrdu(
      '${passage.arabic} ${passage.urdu} ${passage.commentary}',
    );
    var score = 0;
    var matched = 0;
    for (final term in terms) {
      final inTitle = titleBlob.contains(term);
      final inBody = bodyBlob.contains(term);
      if (!inTitle && !inBody) continue;
      matched++;
      score += term.length + 2;
      if (inTitle) score += (term.length + 2) * 3;
      if (inBody) score += 2;
    }
    if (normalizedQuestion.length >= 6 &&
        (titleBlob.contains(normalizedQuestion) ||
            bodyBlob.contains(normalizedQuestion))) {
      score += 10; // intact question phrase
    }
    // Coverage reward: a passage answering most of the question outranks one
    // matching a single token many times.
    score += (matched * matched);
    return (score: score, matched: matched);
  }
}
