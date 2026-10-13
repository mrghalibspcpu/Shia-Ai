class BookDefinition {
  const BookDefinition({
    required this.key,
    required this.fileName,
    required this.titleUrdu,
    required this.titleLatin,
    this.description = '',
  });

  final String key;
  final String fileName;
  final String titleUrdu;
  final String titleLatin;
  final String description;

  static const List<BookDefinition> all = [
    BookDefinition(key: 'tahzeeb', fileName: 'Tahzeeb.db', titleUrdu: 'تہذیب الاحکام', titleLatin: 'Tahdhib al-Ahkam'),
    BookDefinition(key: 'alkafi', fileName: 'alkafi.db', titleUrdu: 'الکافی', titleLatin: 'Al-Kafi'),
    BookDefinition(key: 'alkhisal', fileName: 'alkhisal.db', titleUrdu: 'الخصال', titleLatin: 'Al-Khisal'),
    BookDefinition(key: 'hakam', fileName: 'hakam.db', titleUrdu: 'حِکَم', titleLatin: 'Hikam'),
    BookDefinition(key: 'hidaya', fileName: 'hidaya.db', titleUrdu: 'الہدایہ', titleLatin: 'Al-Hidaya'),
    BookDefinition(key: 'hikmatprophet', fileName: 'hikmatprophet.db', titleUrdu: 'حکمتِ پیغمبر', titleLatin: 'Wisdoms of the Prophet'),
    BookDefinition(key: 'imam', fileName: 'imam.db', titleUrdu: 'حکمتِ ائمہ', titleLatin: 'Wisdoms of the Imams'),
    BookDefinition(key: 'kamaledeen', fileName: 'kamaledeen.db', titleUrdu: 'کمال الدین و تمام النعمة', titleLatin: 'Kamal al-Din'),
    BookDefinition(key: 'maniakbar', fileName: 'maniakbar.db', titleUrdu: 'معانی الاخبار', titleLatin: "Ma'ani al-Akhbar"),
    BookDefinition(key: 'manlahyahzur', fileName: 'manlahyahzur.db', titleUrdu: 'من لا یحضره الفقیہ', titleLatin: 'Man La Yahduruhu al-Faqih'),
    BookDefinition(key: 'mezan', fileName: 'mezan.db', titleUrdu: 'میزان الحکمة', titleLatin: 'Mizan al-Hikmah'),
    BookDefinition(key: 'swab', fileName: 'swab.db', titleUrdu: 'ثواب الاعمال', titleLatin: 'Thawab al-A’mal'),
    BookDefinition(key: 'towheed', fileName: 'towheed.db', titleUrdu: 'التوحید', titleLatin: 'Al-Tawhid'),
    BookDefinition(key: 'wasail', fileName: 'wasail.db', titleUrdu: 'وسائل الشیعہ', titleLatin: "Wasa'il al-Shi'a"),
  ];

  static BookDefinition? byKey(String? key) {
    if (key == null) return null;
    for (final book in all) {
      if (book.key == key.toLowerCase()) return book;
    }
    return null;
  }
}

class ReaderTarget {
  const ReaderTarget({
    required this.book,
    required this.recordId,
    this.sectionId,
    this.page,
  });

  final String book;
  final int recordId;
  final int? sectionId;
  final int? page;

  factory ReaderTarget.fromJson(Map<String, dynamic> json) {
    final sectionId = _asInt(json['section_id']);
    return ReaderTarget(
      book: (json['book'] ?? '').toString().toLowerCase(),
      recordId: _asInt(json['record_id']) ?? 0,
      sectionId: sectionId,
      page: _asInt(json['page']),
    );
  }
}

class Passage {
  const Passage({
    required this.recordId,
    required this.arabic,
    required this.urdu,
    this.sectionId,
    this.page,
    this.sectionTitle = '',
    this.chapterTitle = '',
  });

  final int recordId;
  final int? sectionId;
  final int? page;
  final String arabic;
  final String urdu;
  final String sectionTitle;
  final String chapterTitle;

  factory Passage.fromMap(Map<String, Object?> row) => Passage(
        recordId: _asInt(row['record_id'] ?? row['ID']) ?? 0,
        sectionId: _asInt(row['section_id'] ?? row['Secid']),
        page: _asInt(row['page_no'] ?? row['paganum']),
        arabic: (row['arabic'] ?? row['txt'] ?? '').toString(),
        urdu: (row['urdu'] ?? row['mean'] ?? '').toString(),
        sectionTitle: (row['section_title'] ?? '').toString(),
        chapterTitle: (row['chapter_title'] ?? '').toString(),
      );
}

class SearchHit {
  const SearchHit({required this.book, required this.passage, this.citation = ''});

  final BookDefinition book;
  final Passage passage;
  final String citation;
}

class AiSource {
  const AiSource({required this.marker, required this.citation, required this.target});

  final String marker;
  final String citation;
  final ReaderTarget target;

  factory AiSource.fromJson(Map<String, dynamic> json) {
    final targetJson = json['reader_target'] is Map
        ? Map<String, dynamic>.from(json['reader_target'] as Map)
        : <String, dynamic>{
            'book': json['book'],
            'record_id': json['paragraph_id'] ?? json['record_id'],
            'section_id': json['section_id'],
            'page': json['page_no'] ?? json['page'],
          };
    final bookKey = (targetJson['book'] ?? json['book'] ?? '').toString().toLowerCase();
    return AiSource(
      marker: (json['marker'] ?? '').toString(),
      citation: (json['citation'] ?? '').toString(),
      target: ReaderTarget.fromJson({...targetJson, 'book': bookKey}),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.isUser,
    required this.text,
    this.sources = const [],
    this.createdAt,
  });

  final bool isUser;
  final String text;
  final List<AiSource> sources;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'isUser': isUser,
        'text': text,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'sources': sources
            .map((source) => {
                  'marker': source.marker,
                  'citation': source.citation,
                  'book': source.target.book,
                  'record_id': source.target.recordId,
                  'section_id': source.target.sectionId,
                  'page': source.target.page,
                })
            .toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        isUser: json['isUser'] == true,
        text: (json['text'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
        sources: (json['sources'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((source) => AiSource.fromJson(Map<String, dynamic>.from(source)))
            .toList(),
      );
}

int? _asInt(Object? value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
