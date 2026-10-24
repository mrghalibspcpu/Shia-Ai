/// Orchestrates one ShiaAi turn: retrieve locally → judge evidence → call the
/// self-hosted gateway only when evidence is sufficient → validate every
/// citation id against the retrieved records.
///
/// Hard rules enforced here rather than left to the model:
///   * no evidence / weak evidence → abstain, never call the network;
///   * the model can only cite ids that exist in the retrieved set;
///   * citations are built in app code from real records, not parsed from
///     model prose;
///   * transport/quota/key failures degrade to local sources, never to
///     general-knowledge answers.
library;

import 'shia_ai_gateway.dart';
import 'shia_ai_models.dart';
import 'shia_ai_retriever.dart';
import 'shia_ai_settings.dart';

/// Urdu wording shared by the chat screen and the tests, so the abstaining
/// contract cannot silently drift between layers.
class ShiaAiWording {
  const ShiaAiWording._();

  static const String noEvidence =
      'آپ کی نصب شدہ کتب میں اس سوال سے متعلق کوئی عبارت نہیں ملی۔ '
      'براہِ کرم مختلف الفاظ، کتاب کا نام یا کوئی کلیدی لفظ استعمال کر کے دوبارہ پوچھیں۔ '
      'ShiaAi عام معلومات سے جواب نہیں بناتا اور نہ ہی کوئی حدیث، فتویٰ یا حوالہ خود گھڑتا ہے۔';

  static const String weakEvidence =
      'اس سوال پر نصب شدہ کتب میں واضح اور کافی مواد دستیاب نہیں، اس لیے کوئی جواب مرتب نہیں کیا گیا۔ '
      'ذیل میں ملنے والی متعلقہ عبارتیں دی جا رہی ہیں — آپ انہیں کھول کر خود جائزہ لے سکتے ہیں۔';

  static const String offlineSources =
      'آن لائن خلاصہ بند ہے (گیٹ وے ترتیب نہیں دیا گیا یا اجازت فعال نہیں)۔ '
      'آلہ نے صرف آپ کی ڈیوائس پر موجود کتب سے درج ذیل متعلقہ عبارتیں تلاش کی ہیں؛ '
      'کوئی تحریر انٹرنیٹ پر نہیں بھیجی گئی۔';

  static const String networkError =
      'گیٹ وے تک رابطہ نہیں ہو سکا، اس لیے آن لائن جواب تیار نہیں ہو سکا۔ '
      'آپ کی مقامی کتب سے ملنے والی عبارتیں نیچے موجود ہیں۔ آف لائن مطالعہ اور تلاش بدستور جاری ہے۔';

  static const String quotaExhausted =
      'ماڈل کی استعمال کی حد ختم ہو چکی ہے یا سروس فی الحال دستیاب نہیں۔ '
      'براہِ کرم کچھ دیر بعد دوبارہ کوشش کریں۔ اس دوران مقامی ماخذ کی عبارتیں یہاں دی گئی ہیں۔';

  static const String keyUnavailable =
      'سرور پر Gemini کلید ترتیب نہیں ہے یا اسے مسترد کر دیا گیا۔ '
      'جب تک منتظم اسے درست نہ کرے، صرف مقامی ماخذ کی عبارتیں پیش کی جا رہی ہیں۔';

  static const String serviceError =
      'جوابی سروس سے درست جواب موصول نہیں ہوا۔ کوئی بھی غیر مصدقہ بات نہیں لکھی جا رہی؛ '
      'مقامی کتب سے حاصل شدہ عبارتیں نیچے دستیاب ہیں۔';

  static const String modelAbstained =
      'ماڈل نے فراہم کردہ عبارتوں میں اس سوال کا واضح جواب نہیں پایا، اس لیے حوالہ جات کے ساتھ '
      'متعلقہ عبارتیں ہی پیش کی جا رہی ہیں۔ ان کے بغیر کوئی نیا حکم یا حوالہ شامل نہیں کیا گیا۔';

  static const String privacyNotice =
      'ShiaAi پہلے آپ کی نصب شدہ کتب میں سے صرف متعلقہ عبارتیں ڈھونڈتا ہے۔ '
      'آن لائن جواب کی صورت میں ان منتخب اقتباسات (پوری کتاب نہیں) کو آپ کے متعین کردہ محفوظ سرور '
      'اور وہاں سے Gemini کو بھیجا جاتا ہے۔ کلید ہمیشہ سرور پر رہتی ہے، ایپ میں نہیں۔';
}

class ShiaAiEngine {
  ShiaAiEngine({
    required this.retriever,
    ShiaAiGateway? gateway,
    Future<ShiaAiPreferences> Function()? preferences,
  })  : _gateway = gateway,
        _preferences = preferences ?? ShiaAiPreferences.load;

  final ShiaAiRetriever retriever;
  final ShiaAiGateway? _gateway;
  final Future<ShiaAiPreferences> Function() _preferences;

  Future<ShiaAiReply> ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      return const ShiaAiReply(
        answer: '',
        delivery: ShiaAiDelivery.noEvidence,
      );
    }

    final retrieval = await retriever.retrieve(trimmed);
    if (!retrieval.hasAny) {
      return const ShiaAiReply(
        answer: ShiaAiWording.noEvidence,
        delivery: ShiaAiDelivery.noEvidence,
      );
    }
    if (!retrieval.hasEnough) {
      return ShiaAiReply(
        answer: ShiaAiWording.weakEvidence,
        delivery: ShiaAiDelivery.abstained,
        evidence: retrieval.evidence,
        citations: citationsFor(retrieval.evidence, retrieval.evidenceIds),
      );
    }

    final preferences = await _preferences();
    if (!preferences.isConfigured || _gateway == null) {
      return ShiaAiReply(
        answer: ShiaAiWording.offlineSources,
        delivery: ShiaAiDelivery.offlineSources,
        evidence: retrieval.evidence,
        citations: citationsFor(retrieval.evidence, retrieval.evidenceIds),
      );
    }

    final Uri endpoint;
    try {
      endpoint = Uri.parse(preferences.gatewayUrl.trim());
    } on FormatException {
      return _localFallback(retrieval, ShiaAiDelivery.serviceError,
          ShiaAiWording.serviceError);
    }

    try {
      final response = await _gateway.synthesize(
        endpoint: endpoint,
        question: trimmed,
        evidence: retrieval.evidence,
      );
      // The model may only cite ids from the evidence it actually received.
      final allowed = retrieval.evidenceIds;
      final verifiedIds = response.usedIds
          .where(allowed.contains)
          .toSet();
      final citations = citationsFor(
        retrieval.evidence,
        verifiedIds.isEmpty ? allowed : verifiedIds,
      );
      if (!response.sufficient) {
        return ShiaAiReply(
          answer: ShiaAiWording.modelAbstained,
          delivery: ShiaAiDelivery.abstained,
          evidence: retrieval.evidence,
          citations: citations,
        );
      }
      return ShiaAiReply(
        answer: cleanModelAnswer(response.answer),
        delivery: ShiaAiDelivery.answered,
        evidence: retrieval.evidence,
        citations: citations,
      );
    } on ShiaAiGatewayException catch (error) {
      final wording = switch (error.delivery) {
        ShiaAiDelivery.networkError => ShiaAiWording.networkError,
        ShiaAiDelivery.quotaExhausted => ShiaAiWording.quotaExhausted,
        ShiaAiDelivery.keyUnavailable => ShiaAiWording.keyUnavailable,
        _ => ShiaAiWording.serviceError,
      };
      return _localFallback(retrieval, error.delivery, wording);
    }
  }

  ShiaAiReply _localFallback(
    ShiaAiRetrieval retrieval,
    ShiaAiDelivery delivery,
    String wording,
  ) =>
      ShiaAiReply(
        answer: wording,
        delivery: delivery,
        evidence: retrieval.evidence,
        citations: citationsFor(retrieval.evidence, retrieval.evidenceIds),
      );

  /// Builds citations in app code, solely from verified retrieved records.
  /// Ids that do not resolve to evidence (or to a known book/positive record
  /// id) are dropped here — model prose can never create a citation.
  static List<ShiaAiCitation> citationsFor(
    List<ShiaAiEvidence> evidence,
    Set<String> allowedIds,
  ) {
    final byId = <String, ShiaAiEvidence>{
      for (final item in evidence) item.citationId: item,
    };
    final citations = <ShiaAiCitation>[];
    for (final id in allowedIds) {
      final item = byId[id];
      if (item == null || !item.isOpenable) continue;
      final citation = ShiaAiCitation.fromEvidence(item);
      if (citation.isValid && !citations.any((c) => c.citationId == id)) {
        citations.add(citation);
      }
    }
    return citations;
  }
}

/// Removes lightweight chat/markdown noise the model sometimes adds despite
/// the prompt. It never adds text, and never touches citation ids.
String cleanModelAnswer(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return text;
  // Strip a leading/trailing fenced block if the whole answer is wrapped.
  text = text.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
  text = text.replaceAll(RegExp(r'\s*```$'), '');
  // Keep the words, drop bold/italic markers and stray heading hashes.
  text = text.replaceAll(RegExp(r'[*_#`]{1,3}'), '');
  return text.trim();
}
