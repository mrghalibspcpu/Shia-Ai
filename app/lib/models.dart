enum CorpusSource { hadith, quran, dua, balagha, sahifa, fatwa }

extension CorpusSourceX on CorpusSource {
  /// Urdu label used by the search filter and library sections.
  String get label => switch (this) {
        CorpusSource.hadith => 'کتبِ احادیث',
        CorpusSource.quran => 'قرآنِ کریم',
        CorpusSource.dua => 'دعائیں و اعمال',
        CorpusSource.balagha => 'نہج البلاغہ',
        CorpusSource.sahifa => 'صحیفہ سجادیہ',
        CorpusSource.fatwa => 'فتاویٰ',
      };

  /// Wire value stored in the search index and the manifest.
  String get wire => switch (this) {
        CorpusSource.hadith => 'hadith',
        CorpusSource.quran => 'quran',
        CorpusSource.dua => 'dua',
        CorpusSource.balagha => 'balagha',
        CorpusSource.sahifa => 'sahifa',
        CorpusSource.fatwa => 'fatwa',
      };
}

CorpusSource corpusSourceFromWire(String? value) => switch (value) {
      'quran' => CorpusSource.quran,
      'dua' => CorpusSource.dua,
      'balagha' => CorpusSource.balagha,
      'sahifa' => CorpusSource.sahifa,
      'fatwa' => CorpusSource.fatwa,
      _ => CorpusSource.hadith,
    };

class BookDefinition {
  const BookDefinition({
    required this.key,
    required this.fileName,
    required this.titleUrdu,
    required this.titleLatin,
    this.description = '',
    this.source = CorpusSource.hadith,
    this.recordLabel = 'حدیث نمبر',
  });

  final String key;
  final String fileName;
  final String titleUrdu;
  final String titleLatin;
  final String description;
  final CorpusSource source;
  final String recordLabel;

  static const List<BookDefinition> all = [
    BookDefinition(key: 'sahifa', fileName: 'Sahifa_Sajjadiyya_full_runtime.sqlite3',
      titleUrdu: 'صحیفہ سجادیہ', titleLatin: 'Sahifa Sajjadiyya',
      description: 'دعائیں، مناجات، ترجمہ اور حواشی', source: CorpusSource.sahifa, recordLabel: 'دعا'),
    BookDefinition(key: 'khamenei', fileName: 'khamenei_urdu_fatawa.sqlite',
      titleUrdu: 'فتاویٰ — آیت اللہ خامنہ ای', titleLatin: 'Khamenei Urdu Fatawa',
      description: 'اردو سوال و جواب، اصل ماخذ کے ساتھ', source: CorpusSource.fatwa, recordLabel: 'مسئلہ'),
    BookDefinition(key: 'sistani', fileName: 'sistani_urdu_fatawa.sqlite',
      titleUrdu: 'فتاویٰ — آیت اللہ سیستانی', titleLatin: 'Sistani Urdu Fatawa',
      description: 'اردو سوال و جواب، اصل ماخذ کے ساتھ', source: CorpusSource.fatwa, recordLabel: 'مسئلہ'),
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
    BookDefinition(
      key: 'quran',
      fileName: 'quran.db',
      titleUrdu: 'قرآنِ کریم',
      titleLatin: 'Al-Quran al-Karim',
      description: 'مکمل قرآن، اردو ترجمہ اور تفسیری حواشی کے ساتھ',
      source: CorpusSource.quran,
      recordLabel: 'آیت',
    ),
    BookDefinition(
      key: 'mafatih',
      fileName: 'mafatihdb-v4.db',
      titleUrdu: 'مفاتیح الجنان',
      titleLatin: 'Mafatih al-Jinan',
      description: 'دعائیں، زیارات، تعقیبات اور ماہانہ اعمال',
      source: CorpusSource.dua,
      recordLabel: 'دعا',
    ),
    BookDefinition(
      key: 'nahjul_balagha',
      fileName: 'nahjul_balagha.db',
      titleUrdu: 'نہج البلاغہ',
      titleLatin: 'Nahj al-Balagha',
      description: 'خطب، خطوط، حکمت اور مقدمات اردو ترجمہ کے ساتھ',
      source: CorpusSource.balagha,
      recordLabel: 'فقرا',
    ),
  ];

  static List<BookDefinition> get hadithBooks =>
      all.where((book) => book.source == CorpusSource.hadith).toList();

  static BookDefinition? bookFor(CorpusSource source) {
    for (final book in all) {
      if (book.source == source) return book;
    }
    return null;
  }

  static BookDefinition? byKey(String? key) {
    if (key == null) return null;
    final needle = key.toLowerCase();
    for (final book in all) {
      if (book.key == needle) return book;
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
    this.locator = '',
    this.containerType,
    this.containerId,
    this.commentary = '',
    this.footnote = '',
    this.format,
  });

  final int recordId;
  final int? sectionId;
  final int? page;
  final String arabic;
  final String urdu;
  final String sectionTitle;
  final String chapterTitle;

  /// Short human locator such as "آیت ۱ • پارہ ۱".
  final String locator;

  /// Owning container inside the database (surah, section type, supplication).
  final int? containerType;
  final int? containerId;

  /// Optional explanatory text (Quran tafseer note, footnote body).
  final String commentary;
  final String footnote;

  /// Presentation role kept from the source database (Nahj al-Balagha
  /// `ParaFormat`: 1 title, 2 text, 3 sub-heading, 4 separator; Mafatih line
  /// type: 1 dua text, 2 Urdu instruction). Null for the hadith books/Quran.
  final int? format;

  factory Passage.fromMap(Map<String, Object?> row) => Passage(
        recordId: _asInt(row['record_id'] ?? row['ID']) ?? 0,
        sectionId: _asInt(row['section_id'] ?? row['Secid']),
        page: _asInt(row['page_no'] ?? row['paganum']),
        arabic: _compact((row['arabic'] ?? row['txt'] ?? '').toString()),
        urdu: _compact((row['urdu'] ?? row['mean'] ?? '').toString()),
        sectionTitle: _compact((row['section_title'] ?? '').toString()),
        chapterTitle: _compact((row['chapter_title'] ?? '').toString()),
        locator: _compact((row['locator'] ?? '').toString()),
        containerType: _asInt(row['container_type']),
        containerId: _asInt(row['container_id']),
        commentary: _compact((row['commentary'] ?? '').toString()),
        footnote: _compact((row['footnote'] ?? '').toString()),
        format: _asInt(row['format'] ?? row['ParaFormat']),
      );

  bool get isEmpty => arabic.trim().isEmpty && urdu.trim().isEmpty;

  String get copyableText {
    final parts = <String>[
      if (arabic.trim().isNotEmpty) arabic.trim(),
      if (urdu.trim().isNotEmpty) urdu.trim(),
    ];
    return parts.join('\n\n');
  }

  Passage copyWith({String? footnote, String? commentary, String? locator}) => Passage(
        recordId: recordId,
        sectionId: sectionId,
        page: page,
        arabic: arabic,
        urdu: urdu,
        sectionTitle: sectionTitle,
        chapterTitle: chapterTitle,
        locator: locator ?? this.locator,
        containerType: containerType,
        containerId: containerId,
        commentary: commentary ?? this.commentary,
        footnote: footnote ?? this.footnote,
        format: format,
      );
}

class SearchHit {
  const SearchHit({required this.book, required this.passage, this.citation = ''});

  final BookDefinition book;
  final Passage passage;
  final String citation;
}

/// One surah row from `ChapterProperty`.
class QuranSurah {
  const QuranSurah({
    required this.number,
    required this.nameArabic,
    required this.nameUrdu,
    required this.revelationPlace,
    required this.verseCount,
    required this.revelationOrder,
  });

  final int number;
  final String nameArabic;
  final String nameUrdu;
  final String revelationPlace;
  final int verseCount;
  final int revelationOrder;

  factory QuranSurah.fromMap(Map<String, Object?> row, {required int index}) => QuranSurah(
        number: _asInt(row['Id']) ?? index + 1,
        nameArabic: _compact((row['Name'] ?? '').toString()),
        nameUrdu: index >= 0 && index < urduSurahNames.length ? urduSurahNames[index] : '',
        revelationPlace: _compact((row['Nozol'] ?? '').toString()),
        verseCount: _asInt(row['Verse']) ?? 0,
        revelationOrder: _asInt(row['revel']) ?? 0,
      );

  String get displayTitle => nameUrdu.isEmpty ? nameArabic : '$nameUrdu · $nameArabic';
}

/// Where a juz begins, for the Quran's "پارے" index.
class QuranJuzEntry {
  const QuranJuzEntry({
    required this.juz,
    required this.firstRecordId,
    required this.surah,
    required this.verse,
  });

  final int juz;
  final int firstRecordId;
  final int surah;
  final int verse;

  String get title {
    final name = surah >= 1 && surah <= urduSurahNames.length ? urduSurahNames[surah - 1] : '$surah';
    return 'پارہ $juz — سورہ $name، آیت $verse';
  }
}

/// One entry of the Mafatih catalogue (`M_items`).
class DuaItem {
  const DuaItem({
    required this.rowId,
    required this.name,
    required this.categoryId,
    required this.isHeader,
    required this.isFeatured,
    this.lineCount = 0,
  });

  final int rowId;
  final String name;
  final int categoryId;
  final bool isHeader;
  final bool isFeatured;
  final int lineCount;

  factory DuaItem.fromMap(Map<String, Object?> row) => DuaItem(
        rowId: _asInt(row['row_id'] ?? row['rowid']) ?? 0,
        name: _compact((row['M_name'] ?? '').toString()),
        categoryId: _asInt(row['M_cat_id']) ?? 0,
        isHeader: _asInt(row['M_type']) == 2,
        isFeatured: _asInt(row['M_montakhab']) == 1,
        lineCount: _asInt(row['line_count']) ?? 0,
      );
}

class DuaCategory {
  const DuaCategory({required this.id, required this.titleUrdu, required this.itemCount});

  final int id;
  final String titleUrdu;
  final int itemCount;
}

/// One section of Nahj al-Balagha (khutbas, letters, wisdoms, traditions, intro).
class BalaghaSection {
  const BalaghaSection({
    required this.type,
    required this.titleUrdu,
    required this.entryCount,
    required this.hasIntroduction,
  });

  final int type;
  final String titleUrdu;
  final int entryCount;
  final bool hasIntroduction;
}

class BalaghaEntry {
  const BalaghaEntry({
    required this.typeNo,
    required this.title,
    required this.paragraphCount,
  });

  final int typeNo;
  final String title;
  final int paragraphCount;
}

int? _asInt(Object? value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _compact(String value) {
  if (value.isEmpty) return value;
  var text = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.replaceAll('\u0640', '');
  text = text.replaceAll(RegExp(r'[\u200e\u200f\u200b\ufeff]'), '');
  text = text.replaceAll(RegExp(r'[^\S\n]+'), ' ');
  text = text.replaceAll(RegExp(r' *\n *'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

/// Urdu names of the 114 surahs, in mushaf order (index 0 = al-Fatiha).
const List<String> urduSurahNames = [
  'الفاتحہ', 'البقرہ', 'آلِ عمران', 'النساء', 'المائدہ', 'الانعام', 'الاعراف', 'الانفال',
  'التوبہ', 'یونس', 'ھود', 'یوسف', 'الرعد', 'ابراہیم', 'الحجر', 'النحل', 'بنی اسرائیل',
  'الکہف', 'مریم', 'طٰہٰ', 'الانبیاء', 'الحج', 'المؤمنون', 'النور', 'الفرقان', 'الشعراء',
  'النمل', 'القصص', 'العنکبوت', 'الروم', 'لقمان', 'السجدہ', 'الاحزاب', 'سبا', 'فاطر',
  'یٰسٰین', 'الصافات', 'ص', 'الزمر', 'المومن', 'حم السجدہ', 'الشوری', 'الزخرف', 'الدخان',
  'الجاثیہ', 'الاحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق', 'الذاریات', 'الطور', 'النجم',
  'القمر', 'الرحمٰن', 'الواقعہ', 'الحدید', 'المجادلہ', 'الحشر', 'الممتحنہ', 'الصف',
  'الجمعہ', 'المنافقون', 'التغابن', 'الطلاق', 'التحریم', 'الملک', 'القلم', 'الحاقہ',
  'المعارج', 'نوح', 'الجن', 'المزمل', 'المدثر', 'القیامہ', 'الدھر', 'المرسلات', 'النبا',
  'النازعات', 'عبس', 'التکویر', 'الانفطار', 'المطففین', 'الانشقاق', 'البروج', 'الطارق',
  'الاعلیٰ', 'الغاشیہ', 'الفجر', 'البلد', 'الشمس', 'اللیل', 'الضحیٰ', 'الم نشرح', 'التین',
  'العلق', 'القدر', 'البینہ', 'الزلزال', 'العادیات', 'القارعہ', 'التکاثر', 'العصر',
  'الہمزہ', 'الفیل', 'قریش', 'الماعون', 'الکوثر', 'الکافرون', 'النصر', 'اللہب', 'الاخلاص',
  'الفلق', 'الناس',
];

/// Urdu titles of the six chapters of Mafatih al-Jinan (`M_cat_id`).
const Map<int, String> duaCategoryTitles = {
  1: 'قرآنی سورتیں اور ان کے خواص',
  2: 'تعقیبات اور نماز کے اعمال',
  3: 'مہینوں کے اعمال (رجب تا ربیع الثانی)',
  4: 'زیارات اور آدابِ سفر',
  5: 'مشہور دعائیں اور زیارات',
  6: 'شب و روز کے اعمال اور ملحقات',
};

/// Urdu titles of the Nahj al-Balagha divisions (`Type` / `TypeID`).
const Map<int, String> balaghaSectionTitles = {
  1: 'خطب',
  2: 'کتب و خطوط',
  3: 'حکمت و اقوالِ قصار',
  4: 'احادیثِ رسولِ خدا ﷺ',
  5: 'مقدمات و تعارف',
};
