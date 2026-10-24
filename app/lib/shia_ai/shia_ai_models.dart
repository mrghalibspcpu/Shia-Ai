/// Data models for the source-grounded ShiaAi feature.
///
/// Nothing in this file calls the model or the network: an evidence record is
/// always a real, locally indexed corpus row (`bookKey` + `recordId`), and a
/// citation can only be created from such a record. The synthesis service may
/// name citation ids, but every id is re-validated against the retrieved set
/// before a [ShiaAiCitation] is shown.
library;

import '../models.dart';

/// How an assistant turn was produced. The UI uses this to pick the icon,
/// colour and Urdu wording; it never invents a state.
enum ShiaAiDelivery {
  /// Model synthesis succeeded and every citation was verified locally.
  answered,

  /// The library had too little evidence; the model was not asked to guess.
  abstained,

  /// Online synthesis is switched off/unconfigured: only local sources are
  /// shown and nothing left the device.
  offlineSources,

  /// No installed book contained a matching passage.
  noEvidence,

  /// The device could not reach the configured gateway.
  networkError,

  /// Gemini rejected the request because the quota is exhausted.
  quotaExhausted,

  /// The gateway has no usable server-side key (or it was rejected).
  keyUnavailable,

  /// Model unavailable, bad status code or an unparsable response.
  serviceError,
}

/// One retrieved corpus passage, carrying its true storage identity.
///
/// [citationId] (`"<bookKey>:<recordId>"`) is the stable handle the synthesis
/// service uses to refer to a passage; the app only ever accepts handles that
/// resolve back to one of these objects.
class ShiaAiEvidence {
  const ShiaAiEvidence({
    required this.bookKey,
    required this.recordId,
    required this.bookTitle,
    required this.score,
    required this.matchedTokens,
    this.sectionId,
    this.page,
    this.chapterTitle = '',
    this.sectionTitle = '',
    this.locator = '',
    this.sourceUrl = '',
    this.sourceRef = '',
    this.arabic = '',
    this.urdu = '',
    this.commentary = '',
  });

  final String bookKey;
  final int recordId;
  final int? sectionId;
  final int? page;
  final String bookTitle;
  final String chapterTitle;
  final String sectionTitle;
  final String locator;
  final String sourceUrl;
  final String sourceRef;
  final String arabic;
  final String urdu;
  final String commentary;

  /// Re-ranking score computed on the device (title/body term coverage).
  final int score;

  /// How many distinct question terms this passage actually contains.
  final int matchedTokens;

  String get citationId => '$bookKey:$recordId';

  BookDefinition? get book => BookDefinition.byKey(bookKey);

  /// True only when this evidence can really be opened in a reader.
  bool get isOpenable => book != null && recordId > 0;

  bool get hasWebSource =>
      sourceUrl.startsWith('http://') || sourceUrl.startsWith('https://');

  /// Builds evidence straight from a local [SearchHit], so the book key and
  /// record id can never drift away from the row that was actually indexed.
  factory ShiaAiEvidence.fromHit(
    SearchHit hit, {
    required int score,
    required int matchedTokens,
  }) {
    final passage = hit.passage;
    return ShiaAiEvidence(
      bookKey: hit.book.key,
      recordId: passage.recordId,
      sectionId: passage.sectionId,
      page: passage.page,
      bookTitle: hit.book.titleUrdu,
      chapterTitle: passage.chapterTitle,
      sectionTitle: passage.sectionTitle,
      locator: passage.locator,
      sourceUrl: passage.sourceUrl,
      sourceRef: passage.sourceRef,
      arabic: passage.arabic,
      urdu: passage.urdu,
      commentary: passage.commentary,
      score: score,
      matchedTokens: matchedTokens,
    );
  }

  /// The excerpt that may leave the device. It is capped here too, so a long
  /// Quran/hadith record can never be uploaded wholesale by mistake.
  Map<String, Object?> toGatewayJson({int maxChars = 1200}) {
    String clip(String value) =>
        value.length <= maxChars ? value : '${value.substring(0, maxChars)}…';
    return <String, Object?>{
      'citation_id': citationId,
      'book_title': bookTitle,
      'chapter_title': chapterTitle,
      'section_title': sectionTitle,
      'locator': locator,
      if (page != null) 'page': page,
      'arabic': clip(arabic),
      'urdu': clip(urdu),
    };
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'book_key': bookKey,
        'record_id': recordId,
        if (sectionId != null) 'section_id': sectionId,
        if (page != null) 'page': page,
        'book_title': bookTitle,
        'chapter_title': chapterTitle,
        'section_title': sectionTitle,
        'locator': locator,
        'source_url': sourceUrl,
        'source_ref': sourceRef,
        'arabic': arabic,
        'urdu': urdu,
        'commentary': commentary,
        'score': score,
        'matched_tokens': matchedTokens,
      };

  factory ShiaAiEvidence.fromJson(Map<String, Object?> json) => ShiaAiEvidence(
        bookKey: (json['book_key'] ?? '').toString(),
        recordId: _asInt(json['record_id']) ?? 0,
        sectionId: _asInt(json['section_id']),
        page: _asInt(json['page']),
        bookTitle: (json['book_title'] ?? '').toString(),
        chapterTitle: (json['chapter_title'] ?? '').toString(),
        sectionTitle: (json['section_title'] ?? '').toString(),
        locator: (json['locator'] ?? '').toString(),
        sourceUrl: (json['source_url'] ?? '').toString(),
        sourceRef: (json['source_ref'] ?? '').toString(),
        arabic: (json['arabic'] ?? '').toString(),
        urdu: (json['urdu'] ?? '').toString(),
        commentary: (json['commentary'] ?? '').toString(),
        score: _asInt(json['score']) ?? 0,
        matchedTokens: _asInt(json['matched_tokens']) ?? 0,
      );
}

/// A tappable citation. Constructed only from verified [ShiaAiEvidence] in
/// app code — never parsed out of model-generated prose.
class ShiaAiCitation {
  const ShiaAiCitation({
    required this.bookKey,
    required this.recordId,
    required this.bookTitle,
    this.sectionId,
    this.page,
    this.chapterTitle = '',
    this.sectionTitle = '',
    this.locator = '',
    this.sourceUrl = '',
    this.sourceRef = '',
  });

  final String bookKey;
  final int recordId;
  final int? sectionId;
  final int? page;
  final String bookTitle;
  final String chapterTitle;
  final String sectionTitle;
  final String locator;
  final String sourceUrl;
  final String sourceRef;

  String get citationId => '$bookKey:$recordId';

  BookDefinition? get book => BookDefinition.byKey(bookKey);

  /// The app's trust gate: an unknown book key or a non-positive storage id
  /// means this citation must not be rendered or navigated to.
  bool get isValid => book != null && recordId > 0;

  bool get hasWebSource =>
      sourceUrl.startsWith('http://') || sourceUrl.startsWith('https://');

  /// One-line Urdu label for the chip, e.g. «الکافی • فصل: …».
  String get shortLabel {
    final where = sectionTitle.isNotEmpty
        ? sectionTitle
        : (chapterTitle.isNotEmpty ? chapterTitle : locator);
    return where.isEmpty ? bookTitle : '$bookTitle — $where';
  }

  factory ShiaAiCitation.fromEvidence(ShiaAiEvidence evidence) =>
      ShiaAiCitation(
        bookKey: evidence.bookKey,
        recordId: evidence.recordId,
        sectionId: evidence.sectionId,
        page: evidence.page,
        bookTitle: evidence.bookTitle,
        chapterTitle: evidence.chapterTitle,
        sectionTitle: evidence.sectionTitle,
        locator: evidence.locator,
        sourceUrl: evidence.sourceUrl,
        sourceRef: evidence.sourceRef,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'book_key': bookKey,
        'record_id': recordId,
        if (sectionId != null) 'section_id': sectionId,
        if (page != null) 'page': page,
        'book_title': bookTitle,
        'chapter_title': chapterTitle,
        'section_title': sectionTitle,
        'locator': locator,
        'source_url': sourceUrl,
        'source_ref': sourceRef,
      };

  factory ShiaAiCitation.fromJson(Map<String, Object?> json) => ShiaAiCitation(
        bookKey: (json['book_key'] ?? '').toString(),
        recordId: _asInt(json['record_id']) ?? 0,
        sectionId: _asInt(json['section_id']),
        page: _asInt(json['page']),
        bookTitle: (json['book_title'] ?? '').toString(),
        chapterTitle: (json['chapter_title'] ?? '').toString(),
        sectionTitle: (json['section_title'] ?? '').toString(),
        locator: (json['locator'] ?? '').toString(),
        sourceUrl: (json['source_url'] ?? '').toString(),
        sourceRef: (json['source_ref'] ?? '').toString(),
      );
}

/// One chat bubble, persisted on the device.
class ShiaAiMessage {
  const ShiaAiMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.createdAt,
    this.delivery = ShiaAiDelivery.answered,
    this.citations = const <ShiaAiCitation>[],
    this.evidenceIds = const <String>[],
  });

  final String id;
  final bool isUser;
  final String text;
  final DateTime createdAt;
  final ShiaAiDelivery delivery;

  /// Verified, tappable citations (assistant turns only).
  final List<ShiaAiCitation> citations;

  /// Citation ids of the evidence this turn was grounded in, including
  /// passages the model did not explicitly reference.
  final List<String> evidenceIds;

  bool get hasCitations => citations.isNotEmpty;

  factory ShiaAiMessage.user(String text, {required String id}) =>
      ShiaAiMessage(id: id, isUser: true, text: text, createdAt: DateTime.now());

  factory ShiaAiMessage.assistant(
    String text, {
    required String id,
    required ShiaAiDelivery delivery,
    List<ShiaAiCitation> citations = const <ShiaAiCitation>[],
    List<String> evidenceIds = const <String>[],
  }) =>
      ShiaAiMessage(
        id: id,
        isUser: false,
        text: text,
        createdAt: DateTime.now(),
        delivery: delivery,
        citations: citations,
        evidenceIds: evidenceIds,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'is_user': isUser,
        'text': text,
        'created_at': createdAt.millisecondsSinceEpoch,
        'delivery': delivery.name,
        'citations': citations.map((c) => c.toJson()).toList(),
        'evidence_ids': evidenceIds,
      };

  factory ShiaAiMessage.fromJson(Map<String, Object?> json) => ShiaAiMessage(
        id: (json['id'] ?? '').toString(),
        isUser: json['is_user'] == true,
        text: (json['text'] ?? '').toString(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          _asInt(json['created_at']) ?? 0,
        ),
        delivery: ShiaAiDelivery.values.firstWhere(
          (value) => value.name == json['delivery'],
          orElse: () => ShiaAiDelivery.serviceError,
        ),
        citations: (json['citations'] as List<Object?>? ?? const <Object?>[])
            .whereType<Map>()
            .map((row) => ShiaAiCitation.fromJson(row.cast<String, Object?>()))
            .where((citation) => citation.isValid)
            .toList(),
        evidenceIds: (json['evidence_ids'] as List<Object?>? ?? const <Object?>[])
            .map((value) => value.toString())
            .where((value) => value.contains(':'))
            .toList(),
      );
}

/// The structured outcome of one [ShiaAiEngine.ask] call, before it becomes a
/// chat bubble.
class ShiaAiReply {
  const ShiaAiReply({
    required this.answer,
    required this.delivery,
    this.evidence = const <ShiaAiEvidence>[],
    this.citations = const <ShiaAiCitation>[],
  });

  final String answer;
  final ShiaAiDelivery delivery;
  final List<ShiaAiEvidence> evidence;
  final List<ShiaAiCitation> citations;

  bool get isSynthesis => delivery == ShiaAiDelivery.answered;
}

int? _asInt(Object? value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
