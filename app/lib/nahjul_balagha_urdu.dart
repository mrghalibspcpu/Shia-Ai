/// The repair layer for the Urdu column of Nahj al-Balagha.
///
/// `assets/nahjul_balagha.db` (1.21.1) is proofread: sermons 4-10 were decoded
/// by hand, mirrored words elsewhere were mapped back, split introductions were
/// rejoined, and `scripts/verify_corpus.py` fails the build if any of that
/// returns. A fresh download therefore needs no repair at all — and gets none,
/// because every rule here is guarded by a damage test.
///
/// A phone that already downloaded the **old** file keeps it until the reader
/// removes the book and downloads it again. That copy has three defects, and
/// this file fixes exactly those three while the reader is reading:
///
/// * whole paragraphs stored with their letters mirrored — «ےک», «ںیم», «ےن»
///   instead of «کے», «میں», «نے». [kNahjulBalaghaParagraphFixes] holds the
///   proofread text of the 21 affected paragraphs and replaces a paragraph only
///   when [looksScrambled] still finds a mirrored word in it;
/// * 32 sermon introductions that the old file cut off mid-sentence ("…اسی
///   [بصرہ کی مذمت] کے بارے میں" with no «فرمایا:»). They are completed for the
///   same table, only when the stored copy is a shortened prefix;
/// * single reversed words scattered through otherwise readable text, which
///   [kNahjulBalaghaWordFixes] maps back. Every key is a form that is not an
///   Urdu word, so no real word can be hit.
///
/// [kNahjulBalaghaPhraseFixes] carries the few longer fragments (and the eight
/// paragraph counters the source file left inside sentences) where a word map
/// is too blunt; it matches whole words only, so «امت پر» is never read as a
/// scrambled «تم پر».
///
/// Only Nahj al-Balagha text (`CorpusSource.balagha`) passes through here; the
/// fourteen hadith books, the Quran, Mafatih and the Sahifa come from a
/// different corpus and were never affected.
///
/// `tests/test_nahjul_balagha_urdu.py` replays these tables over the checked-in
/// database and fails if a proofread paragraph is rewritten or an old damaged
/// one stops being repaired.
library;

/// The mirrored forms that only appear when a word was stored letter-reversed.
/// Used to decide whether a stored paragraph is still the damaged one.
const List<String> _scrambledTells = <String>[
  'ےک', 'یک', 'ےہ', 'ےس', 'ںیم', 'اک', 'وک', 'ےن', 'رپ', 'ںیہ', 'وج',
  'ںیہن', 'ہک', 'ینعی', 'وت', 'ےیل', 'یھب', 'اھت', 'ایگ', 'ےھت', 'ےب',
];

/// True when a paragraph is still the old, letter-shuffled text.
///
/// One mirrored token is enough: the repaired database contains **none** of
/// them anywhere (checked over all 3,742 paragraphs), so a proofread paragraph
/// always scores zero and cannot be touched by the table below.
bool looksScrambled(String text) {
  if (text.isEmpty) return false;
  for (final token in text.split(RegExp(r'\s+'))) {
    if (_scrambledTells.contains(token)) return true;
  }
  return false;
}

/// Whitespace collapsed, so a line break cannot hide a truncation.
String _squeezed(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// True when [text] is the beginning of [correct] and simply stops early.
///
/// The old file lost the second half of 32 sermon introductions; the reader saw
/// a sentence that broke off. Such a copy is replaced with the whole sentence,
/// while a paragraph that merely differs in brackets is left alone.
bool _isShortenedCopy(String text, String correct) {
  final stored = _squeezed(text);
  final full = _squeezed(correct);
  return stored.length < full.length && full.startsWith(stored);
}

/// The proofread text of every paragraph the **old** file still shows wrong.
///
/// The table is a verbatim copy of `balaghatext.UR` in the repaired
/// `nahjul_balagha.db` (1.21.1) — not a fresh translation, so a phone that
/// repairs itself this way reads exactly what a fresh download would give it.
/// `tests/test_nahjul_balagha_urdu.py` fails if any entry stops matching the
/// database, which keeps the two in step.
///
/// Two kinds of damage are covered, and nothing else:
///
/// * **66-89, 220, 221, 697** — the paragraphs of sermons 4-10 (and the two
///   stray letters) whose letters were stored in mirror order, the defect
///   readers reported: `ےک`, `ںیم`, `ےن` instead of `کے`, `میں`, `نے`;
/// * **91-2232 (see [kNahjulBalaghaParagraphFixes]) — 32 sermon introductions
///   that the old file cut off mid-sentence** ("…اسی [بصرہ کی مذمت] کے بارے
///   میں" with no «فرمایا:»), because the introduction was stored in two rows
///   and the second one was lost.
///
/// Every other row of the old file reads correctly and is left untouched.
const Map<int, String> kNahjulBalaghaParagraphFixes = <int, String>{
  66:       'وہ کان بہرا ہو گیا جس نے نصیحت کی بات کو نہیں سمجھا! [کیسے سمجھتا؟ '
      'کیونکہ اس کے دل میں ضد اور دھرمی تھی] اور جسے زوردار آواز [حق کی '
      'واضح پکار] نے بہرا کر دیا ہو، وہ آہٹ [ہلکی سی خبر] کو کیسے سمجھے گا؟ '
      '[یعنی جو حق کو سننا ہی نہیں چاہتا، وہ کیسے ہدایت پائے گا]۔ ایک ایسا '
      'دل باندھ دیا گیا ہے جس سے دھڑکن [اضطراب] کبھی جدا نہیں ہوتی [یعنی یہ '
      'فتنہ زدہ لوگ ہمیشہ بے چینی اور شک میں مبتلا رہے]۔ میں مسلسل تم لوگوں '
      'سے غداری کے نتائج کا انتظار کرتا رہا [یعنی مجھے ہمیشہ علم تھا کہ تم '
      'غداری کرو گے]، اور میں تم میں دھوکہ کھانے والوں کی علامتیں دیکھ رہا '
      'تھا [یعنی میں تمہارے چہروں سے تمہارے اندر کی نیتوں کو جانتا تھا]۔ '
      'دین کی چادر نے مجھے تم سے چھپائے رکھا [یعنی میں نے مذہبی ذمہ داری کے '
      'تحت تم پر سختی نہیں کی]، لیکن سچی نیت نے تمہاری حقیقت مجھ پر کھول دی '
      '[اللہ کے علم اور بصیرت سے]۔ میں گمراہی کے راستوں کے درمیان تمہارے '
      'لیے حق کی شاہراہ پر قائم رہا، جہاں تم لوگ ملتے تو تھے مگر کوئی رہبر '
      'نہیں تھا، اور تم کنویں کھودتے تھے مگر پانی نہیں نکلتا تھا [یعنی تم '
      'حق کی تلاش میں تھے مگر تمہاری کوششیں غلط تھیں اور بے فائدہ ثابت '
      'ہوئیں]۔',
  67:       'آج، میں تمہارے لیے گونگی چیز کو بھی بولنے والا بنا دوں گا [یعنی میں '
      'تمام مخفی حقائق اور پیچیدہ مسائل کھول کر بیان کروں گا]۔ اس شخص کی '
      'رائے زائل ہو گئی جو مجھ سے پیچھے ہٹ گیا [کیسے؟ کیونکہ اس نے ہدایت کا '
      'اصل مرکز چھوڑ دیا]۔ جب سے مجھے حق دکھایا گیا ہے، مجھے اس میں کبھی شک '
      'نہیں ہوا [یعنی آغاز سے آخر تک میں حق پر کامل یقین رکھتا ہوں]۔ [ہاں] '
      'موسیٰ علیہ السلام کو اپنے بارے میں خوف نہیں تھا [کہ وہ فرعون سے ہار '
      'جائیں گے]، بلکہ وہ تو جاہلوں کے غلبے اور گمراہی کی حکومتوں [باطل کے '
      'اقتدار] پر ڈر گئے تھے [کہ کہیں عوام گمراہ نہ ہو جائیں]۔ آج ہم حق اور '
      'باطل کے راستے پر آمنے سامنے کھڑے ہو گئے ہیں، اور جس نے پانی پر '
      'بھروسا کیا، وہ پیاسا نہیں رہے گا [یعنی جس نے ہمارے ذریعہ حق کی پناہ '
      'لی، وہ ہدایت سے محروم نہیں ہوگا]۔',
  69:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  70:       'جو آپ نے رسول اللہ ﷺ کی وفات کے بعد اس وقت ارشاد فرمایا جب عباس '
      '[رسول ﷺ کے چچا] اور ابو سفیان بن حرب نے آپ سے کہا تھا کہ وہ آپ کی '
      'خلافت کے لیے بیعت کرنے کو تیار ہیں:۔',
  71:       'اے لوگو! فتنوں کی موجوں کو نجات کی کشتیوں کے ذریعے چیر دو [یعنی '
      'رہبری کی صحیح پیروی اور حق پر ثابت قدمی سے]، اور اختلاف و جھگڑے '
      '[مُنَافَرَة] کے راستے سے ہٹ جاؤ، اور فخر و مباہات [آپس میں بڑا بننے] '
      'کے تاج اتار پھینکو۔ وہ شخص کامیاب ہوا جو [طاقت اور مدد] کے بازو کے '
      'ساتھ کھڑا ہوا، یا وہ جس نے [فتنوں کے سامنے] ہتھیار ڈال دیے [بیٹھ '
      'گیا] اور آرام پایا [یعنی یا تو طاقتور ہو کر حق قائم کرو یا صبر کر کے '
      'فتنے سے بچو]۔ [یہ خلافت جو تمہیں ملی ہے، اس کی حقیقت یہ ہے کہ] یہ '
      'گدلا پانی ہے [کیونکہ اس میں شک اور فتنہ شامل ہے]، اور ایسا نوالہ ہے '
      'جو کھانے والے کے گلے میں پھنس جائے گا، اور [جو اسے بغیر استحقاق کے '
      'حاصل کرے گا] وہ ایسے شخص کی مانند ہے جو پھل کو اس کے پکنے کے وقت سے '
      'پہلے توڑ لے، یا اس کاشتکار کی طرح ہے جو کسی اور کی زمین میں کھیتی '
      'کرے۔',
  72:       'اگر میں بولوں [خلافت کے لیے حق کا مطالبہ کروں] تو وہ کہیں گے: "اسے '
      'حکومت کا لالچ ہے"، اور اگر میں خاموش رہوں تو وہ کہیں گے: "اسے موت کا '
      'خوف ہے!" [مگر] کہاں! ان تمام سختیوں اور مصیبتوں کے بعد یہ سوچنا فضول '
      'ہے [یعنی میری جرات اور قربانیاں دیکھ کر بھی یہ سوچنا غلط ہے]۔ اللہ '
      'کی قسم! ابو طالب کا بیٹا [علی] تو موت سے اتنا مانوس ہے جتنا ایک بچہ '
      'اپنی ماں کے پستان [دودھ] سے مانوس ہوتا ہے! بلکہ (میں اس لیے خاموش '
      'ہوا) کہ میں تو ایک پوشیدہ علم پر سمٹ گیا ہوں [یعنی وہ حقائق جنہیں '
      'میں نے اپنے سینے میں چھپا لیا ہے]؛ اگر میں اسے ظاہر کر دوں تو تم '
      'کنویں کی گہرائی میں ڈول کی رسیوں کی طرح مضطرب ہو جاؤ گے [یعنی وہ '
      'اتنا گہرا، حیران کن اور بڑا علم ہے کہ تم گھبرا کر بے قابو ہو جاؤ '
      'گے]۔',
  74:       '(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)',
  75:       'جو آپ نے اس وقت فرمایا جب آپ کو مشورہ دیا گیا کہ وہ طلحہ اور زبیر کا '
      'پیچھا نہ کریں اور نہ ہی ان سے لڑائی کے لیے گھات لگائیں:',
  76:       'اللہ کی قسم! میں اس بجو [ضَبُع] کی طرح نہیں ہوں گا [جو بہت سست اور '
      'بے وقوف ہوتا ہے]: جو لمبی مدت تک ڈھول پیٹنے [شور] پر سویا رہتا ہے جب '
      'تک اس کا پیچھا کرنے والا اس تک پہنچ نہ جائے، اور اس کی گھات میں '
      'بیٹھنے والا اسے دھوکے سے پکڑ نہ لے۔ بلکہ میں تو ہمیشہ حق کی طرف '
      'بڑھنے والے کے ذریعے حق سے پیٹھ پھیرنے والے کو ماروں گا، اور سننے '
      'والے، فرمانبردار کے ذریعے نافرمانی کرنے والے، شک کرنے والے کو [ختم '
      'کروں گا]، یہاں تک کہ میرا دن [موت] آ جائے۔ اللہ کی قسم! جب سے اللہ '
      'تعالیٰ نے اپنے نبی ﷺ کو قبض کیا ہے، تب سے لے کر آج تک، مجھے میرے حق '
      '[خلافت] سے ہمیشہ دور رکھا گیا ہے، اور دوسروں کو مجھ پر ترجیح دی گئی '
      'ہے [میرے حقوق چھین لیے گئے ہیں]۔',
  78:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  79:       'ان [گمراہ لوگوں] نے شیطان کو اپنے معاملات کا محور اور مرکز بنا لیا '
      '[یعنی ہر فیصلہ شیطان کی پیروی میں کرتے ہیں]، اور شیطان نے انہیں اپنے '
      'لیے جال [پھندے] بنا لیا [تاکہ وہ دوسروں کو بھی گمراہ کر سکیں]۔ پس اس '
      '[شیطان] نے ان کے سینوں میں انڈے دیے اور بچے نکالے [یعنی ان کے دلوں '
      'میں برے وسوسے اور نظریات جڑ پکڑ گئے]، اور ان کی گودوں میں رینگتا اور '
      'چلتا رہا [یعنی وہ ان کی روزمرہ زندگی کا حصہ بن گیا]۔ پھر وہ ان کی '
      'آنکھوں سے دیکھتا ہے [حرام کی طرف]، اور ان کی زبانوں سے بولتا ہے [غلط '
      'اور باطل باتیں]۔ پس اس [شیطان] نے انہیں غلطیوں [زلل] پر سوار کر دیا، '
      'اور ان کے لیے باطل [سچائی سے دوری] کو خوبصورت بنا دیا [تاکہ وہ اسے '
      'حق سمجھیں]۔ یہ اس شخص کا کام ہے جسے شیطان نے اپنے اقتدار میں شریک کر '
      'لیا ہے، اور اس کی زبان سے باطل بات کہلواتا ہے۔',
  81:       '(یہ امیر المومنین علیہ السلام کا کلام ہے)',
  82:       'جو آپ نے زبیر کے بارے میں اس وقت فرمایا جب حالات کا تقاضا یہی تھا:',
  83:       'وہ [زبیر] یہ دعویٰ کرتے ہیں کہ انہوں نے بیعت تو اپنے ہاتھ سے کی تھی، '
      'لیکن اپنے دل سے نہیں کی تھی [یعنی وہ میری خلافت پر دلی طور پر راضی '
      'نہیں تھے]۔ پس انہوں نے بیعت کا اقرار تو کر لیا، لیکن اندرونی سازش '
      '[وَلِيجَة، یعنی خفیہ عدم رضا مندی] کا دعویٰ کیا۔ تو چاہیے کہ وہ اپنے '
      'اس دعوے کے ثبوت میں کوئی ایسی بات پیش کریں جو جانی جاتی ہو [یعنی '
      'دلیل لائیں]، ورنہ وہ اس (اطاعت) میں واپس داخل ہو جائیں جس سے وہ نکل '
      'گئے ہیں [یعنی اپنی بیعت کو پورا کریں]۔',
  85:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  86:       'انہوں [دشمنوں، جیسے اہل جمل یا معاویہ] نے بہت گرج چمک کی [دھمکیاں '
      'دیں اور بڑی باتیں کیں]، مگر ان دونوں باتوں [گرج اور چمک] کے ساتھ '
      'ناکامی شامل ہے۔ جبکہ ہم اس وقت تک گرجتے نہیں جب تک کہ ضرب نہ لگا دیں '
      '[یعنی ہم صرف خالی دھمکی نہیں دیتے بلکہ عمل کرتے ہیں]، اور نہ ہی '
      'سیلاب لاتے ہیں جب تک کہ برسا نہ دیں [یعنی ہماری بات اور عمل میں کوئی '
      'تضاد نہیں، ہم پہلے حملہ کرتے ہیں پھر نتیجہ آتا ہے]۔',
  88:       '(یہ امیر المومنین علیہ السلام کے ایک خطبہ کا حصہ ہے)',
  89:       'خبردار! بے شک شیطان نے اپنے گروہ [حزب] کو اکٹھا کر لیا ہے، اور اپنے '
      'سواروں اور پیادوں کو بلا لیا ہے [یعنی تمام گمراہ کرنے والی طاقتیں '
      'جمع کر لی ہیں]۔ اور میرے ساتھ میری مکمل بصیرت [حق و باطل کی پہچان کا '
      'علم] ہے۔ میں نے نہ تو اپنے آپ پر حق کو مشتبہ کیا [یعنی میں خود شک '
      'میں نہیں ہوں]، اور نہ ہی کسی نے مجھ پر حق کو مشتبہ کیا ہے [یعنی کوئی '
      'مجھے دھوکہ نہیں دے سکتا]۔ اور اللہ کی قسم! میں ضرور ان کے لیے ایک '
      'ایسا حوض تیار کروں گا جس سے پانی میں خود نکالوں گا [یعنی میں خود جنگ '
      'کی تیاری کروں گا]، کہ وہ (شکست کے بعد) نہ تو اس سے سیراب ہو کر لوٹیں '
      'گے، اور نہ دوبارہ اس طرف آئیں گے [یعنی میں انہیں ایسی فیصلہ کن شکست '
      'دوں گا کہ وہ دوبارہ مقابلہ کرنے کی جرات نہیں کریں گے]۔',
  220:       'طلحہ سے ہرگز نہ ملنا، کیونکہ اگر تم اس سے ملو گے تو اسے ایسے بیل '
      '[ثور] کی طرح پاؤ گے جو اپنے سینگ کو موڑ رہا ہو [کیسے؟ یعنی وہ اکڑا '
      'ہوا ہے اور لڑنے کے لیے تیار ہے]، وہ سرکش [مشکل] چیز پر سوار ہوتا ہے '
      'اور کہتا ہے کہ یہ نرم [آسان] ہے [کیسے؟ یعنی وہ اپنے غلط راستے کو حق '
      'سمجھتا ہے]۔ لیکن زبیر سے ملنا، کیونکہ وہ مزاج کے اعتبار سے زیادہ نرم '
      'ہے [لین عریکۃ]، پس اسے کہنا کہ تمہارا ماموں کا بیٹا [علی] تم سے پوچھ '
      'رہا ہے: "تم نے مجھے حجاز [مدینہ] میں تو پہچانا، اور عراق [بصرہ] میں '
      'آ کر کیوں میرا انکار کر دیا؟ پس وہ کیا بات ہے جو ظاہر ہوئی [تبدیلی '
      'آئی] جس نے تجھے [مجھ سے] منحرف کر دیا؟"',
  221:       '[سید رضی کہتے ہیں]: اور آپ علیہ السلام وہ پہلے شخص ہیں جن سے یہ جملہ '
      'سنا گیا ہے، یعنی "فَمَا دَعَا اَمْرٌ بَدَا" [پس وہ کیا بات ہے جو '
      'ظاہر ہوئی جس نے تجھے منحرف کر دیا]۔',
  697:       'امام (رہنما) کی ذمہ داری صرف وہی ہے جو اللہ کی طرف سے اس پر ڈالی گئی '
      'ہے: یعنی نصیحت [وعظ] کو پوری طرح پہنچانا، خیر خواہی میں پوری کوشش '
      'کرنا، سنت کو زندہ رکھنا، مستحق لوگوں پر سزائیں (حدود) نافذ کرنا اور '
      'حقداروں تک ان کا حصہ پہنچانا۔',
  91:       '(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)',
  101:       '(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)',
  112:       'جو آپ نے اسی [بصرہ کی مذمت] کے بارے میں فرمایا:',
  115:       '(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)',
  119:       '(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)',
  129:       '(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)',
  136:       '(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)',
  141:       '(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)',
  146:       '(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)',
  154:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  158:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  168:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  171:       '(یہ امیر المؤمنین علیہ السلام کا ایک خطبہ ہے)',
  184:       '(یہ امیر المؤمنین علیہ السلام کا ایک خطبہ ہے)',
  186:       '[اس خطبے کا ایک حصہ]',
  188:       '[اس خطبے کا ایک حصہ]',
  191:       '(یہ امیر المؤمنین علیہ السلام کا ایک خطبہ ہے)',
  200:       '(یہ امیر المؤمنین علیہ السلام کا ایک خطبہ ہے)',
  208:       '(یہ امیر المؤمنین علیہ السلام کا ایک کلام ہے)',
  218:       '(یہ امیر المؤمنین علیہ السلام کا ایک کلام ہے)',
  223:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  233:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  242:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  249:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  255:       '(یہ امیر المومنین علیہ السلام کا ایک خطبہ ہے)',
  259:       '(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)',
  267:       'ایک خطبہ کا حصہ',
  279:       'ایک خطبہ کا حصہ',
  282:       'ایک خطبہ کا حصہ',
  932:       '(یہ امیرالمومنین علی علیہ السلام کا کلام ہے)',
  937:       '(یہ امیرالمومنین علی علیہ السلام کا کلام ہے)',
  2232:       'یہ آپؑ کا عہد نامہ ہے',
};

/// Fragments the source file carries inside otherwise readable sentences.
///
/// Applied before [kNahjulBalaghaWordFixes]; the longer, more specific phrases
/// come first so a later, shorter rule cannot eat their context.
const List<(String, String)> kNahjulBalaghaPhraseFixes = <(String, String)>[
  ('بج کت', 'جب تک'),
  ('بیزاری کت اظرہ', 'بیزاری کے اظہار'),
  ('سر کت اٹھائے', 'سر اٹھائے'),
  ('آئیں کت گے', 'آئیں گے'),
  ('تع کت یہاں', 'یہاں'),
  ('مت رہو تع ورنہ', 'مت رہو ورنہ'),
  ('تع نکیل', 'لیکن'),
  ('تع اللہ کی اطاعت', 'اللہ کی اطاعت'),
  ('اندھے تق [یعنی', 'اندھے [یعنی'),
  ('سے تق کسی کو', 'سے کسی کو'),
  ('کلام تق کت', 'کلام'),
  ('جیسی تق ہے', 'جیسی ہے'),
  ('موت سے تق پہلے', 'موت سے پہلے'),
  ('کو 58 اس', 'کو اس'),
  ('تما م با طل', 'تمام باطل'),
  ('تب تو تی میں', 'تب تو میں'),
  ('ان تی کے', 'ان کے'),
  ('کت بوجھ', 'بوجھ'),
  // «تم» written with its two letters swapped; a prohibition can never be
  // followed by a case marker, so these can only be the pronoun.
  ('مت پر', 'تم پر'),
  ('مت میں', 'تم میں'),
  ('مت سے', 'تم سے'),
  ('مت نے', 'تم نے'),
  ('مت کو', 'تم کو'),
  ('مت کی', 'تم کی'),
  ('مت کا', 'تم کا'),
  ('مت کے', 'تم کے'),
  ('مت لوگ', 'تم لوگ'),
  ('[مت تباہ', '[تم تباہ'),
  // Paragraph counters the source file left inside eight sentences.
  ('دنیا کو 37 اپنی', 'دنیا کو اپنی'),
  ('زیادہ اس 38 کے عاشق', 'زیادہ اس کے عاشق'),
  ('پہنچایا۔ 39 پس', 'پہنچایا۔ پس'),
  ('لیے 40 کتنے', 'لیے کتنے'),
  ('آدمی بھی 57 ہلاک', 'آدمی بھی ہلاک'),
  ('حقدار ہے 59 کہ', 'حقدار ہے کہ'),
  ('مملوک 60 [ملیکت]', 'مملوک [ملیکت]'),
];

/// Reversed word forms written by the source app, mapped back to the word they
/// stand for. Every key is a form that is not an Urdu word, so the mapping is
/// safe to apply to the whole column; words that are legitimate in both
/// directions (بس/سب، رہ/ہر، کلام/مالک …) are deliberately absent.
const Map<String, String> kNahjulBalaghaWordFixes = <String, String>{
  'ےک': 'کے', 'یک': 'کی', 'ےہ': 'ہے', 'ےس': 'سے',
  'ںیم': 'میں', 'اک': 'کا', 'وک': 'کو', 'ےن': 'نے',
  'رپ': 'پر', 'ںیہ': 'ہیں', 'وج': 'جو', 'ںیہن': 'نہیں',
  'ہک': 'کہ', 'ینعی': 'یعنی', 'ہن': 'نہ', 'وت': 'تو',
  'ےیل': 'لیے', 'یھب': 'بھی', 'یسک': 'کسی', 'بج': 'جب',
  'ںیہمت': 'تمہیں', 'اھت': 'تھا', 'ےگ': 'گے', 'قح': 'حق',
  'کت': 'تک', 'ایگ': 'گیا', 'ےھت': 'تھے', 'ےب': 'بے',
  'سپ': 'پس', 'زیچ': 'چیز', 'رھپ': 'پھر', 'ہیلع': 'علیہ',
  'صخش': 'شخص', 'ےسیک': 'کیسے', 'تہب': 'بہت', 'ےئگ': 'گئے',
  'مہ': 'ہم', 'ےل': 'لے', 'ےسیج': 'جیسے', 'ایل': 'لیا',
  'دعب': 'بعد', 'ےھجم': 'مجھے', 'رگم': 'مگر', 'اہر': 'رہا',
  'یھبک': 'کبھی', 'نب': 'بن', 'نج': 'جن', 'لمع': 'عمل',
  'ےلہپ': 'پہلے', 'اتکس': 'سکتا', 'یھت': 'تھی', 'یئگ': 'گئی',
  'مسق': 'قسم', 'ےسج': 'جسے', 'ہصح': 'حصہ', 'ملع': 'علم',
  'یلع': 'علی', 'متخ': 'ختم', 'اہک': 'کہا', 'ےھچیپ': 'پیچھے',
  'انب': 'بنا', 'ریغب': 'بغیر', 'دای': 'یاد', 'ھجم': 'مجھ',
  'ریما': 'امیر', 'عمج': 'جمع', 'ہشیمہ': 'ہمیشہ', 'ہبطخ': 'خطبہ',
  'تقیقح': 'حقیقت', 'ہکلب': 'بلکہ', 'ربص': 'صبر', 'لمکم': 'مکمل',
  'تحیصن': 'نصیحت', 'ےتہک': 'کہتے', 'نیقی': 'یقین', 'ںیہک': 'کہیں',
  'یبن': 'نبی', 'شیپ': 'پیش', 'حیحص': 'صحیح', 'تعیب': 'بیعت',
  'ربخ': 'خبر', 'چنہپ': 'پہنچ', 'لکن': 'نکل', 'یتخس': 'سختی',
  'یل': 'لی', 'ںیھت': 'تھیں', 'ہنتف': 'فتنہ', 'یلم': 'ملی',
  'تلہم': 'مہلت', 'وچب': 'بچو', 'ںیکس': 'سکیں', 'ہلمح': 'حملہ',
  'اپھچ': 'چھپا', 'یبمل': 'لمبی', 'ھٹیپ': 'پیٹھ', 'کشیب': 'بیشک',
  'تنس': 'سنت', 'ےننس': 'سننے', 'ےنتف': 'فتنے', 'اتہک': 'کہتا',
  'انتج': 'جتنا', 'ٹہ': 'ہٹ', 'ڑکپ': 'پکڑ', 'یچس': 'سچی',
  'اتھجمس': 'سمجھتا', 'اھجمس': 'سمجھا', 'ڑج': 'جڑ', 'اتلچ': 'چلتا',
  'رخف': 'فخر', 'ہجیتن': 'نتیجہ', 'ےھجمس': 'سمجھے', 'ںیک': 'کیں',
  'دض': 'ضد', 'نیفص': 'صفین', 'ےنیس': 'سینے', 'التبم': 'مبتلا',
  'ںیہنج': 'جنہیں', 'تنج': 'جنت', 'ہکبج': 'جبکہ', 'تسس': 'سست',
  'تسکش': 'شکست', 'ےبلغ': 'غلبے', 'ریچ': 'چیر', 'ےننب': 'بننے',
  'وکنیھپ': 'پھینکو', 'ڑھکا': 'اکھڑ', 'ھٹیب': 'بیٹھ', 'ےلگ': 'گلے',
  'یتیھک': 'کھیتی', 'اٹیب': 'بیٹا', 'ہچب': 'بچہ', 'ںیھجمس': 'سمجھیں',
  'ےتلم': 'ملتے', 'اننس': 'سننا', 'قحتسم': 'مستحق', 'ہبتشم': 'مشتبہ',
  'ہیفخ': 'خفیہ', 'ششخب': 'بخشش', 'ضبق': 'قبض', 'ینیچ': 'چینی',
  'ہلمج': 'جملہ', 'سنھپ': 'پھنس', 'اھچیپ': 'پیچھا', 'ےنکپ': 'پکنے',
  'رگج': 'جگر', 'رجات': 'تاجر', 'لھپ': 'پھل', 'ےچنھک': 'کھنچے',
  'لمج': 'جمل', 'ےھجت': 'تجھے', 'الب': 'بلا', 'ربکا': 'اکبر',
  'خلت': 'تلخ', 'وھکل': 'لکھو', 'اکھج': 'جھکا', 'طلغ': 'غلط',
  'ہلصیف': 'فیصلہ', 'لسلسم': 'مسلسل', 'ہحلط': 'طلحہ', 'ےچب': 'بچے',
  'کمچ': 'چمک', 'تمینغ': 'غنیمت', 'ریخ': 'خیر', 'ارگ': 'اگر',
};

/// Arabic-script letters and their vowel marks only: the Arabic punctuation
/// (`،` `؛` `؟` `۔`) and the Quranic stop marks sit INSIDE the U+0600 block, so
/// a plain script range would glue them onto the word and stop it matching.
final RegExp _urduWord = RegExp(
  r'[\u0621-\u063A\u0640-\u065F\u0670\u0671-\u06D3\u06D5'
  r'\u06FA-\u06FF\u0750-\u077F\u08A0-\u08FF]+',
);

/// The Urdu of one Nahj al-Balagha paragraph, repaired.
///
/// [recordId] is `balaghatext.ID`. Any other record — a footnote row
/// (`balaghatext_hawashi`, negative ids) or an introduction
/// (`balaghatext_muqadamat`) — was not damaged, and only the word map is
/// applied to it.
String repairNahjulBalaghaUrdu(int recordId, String text) {
  if (text.isEmpty) return text;
  final correct = kNahjulBalaghaParagraphFixes[recordId];
  var repaired = text;
  // Only a paragraph that is visibly wrong is replaced: mirrored letters, or a
  // sentence that stops short of the proofread one. Everything else — including
  // the proofread database itself — passes through byte for byte.
  if (correct != null &&
      text != correct &&
      (looksScrambled(text) || _isShortenedCopy(text, correct))) {
    repaired = correct;
  }
  for (final (from, to) in kNahjulBalaghaPhraseFixes) {
    if (repaired.contains(from)) repaired = _replaceWholeWords(repaired, from, to);
  }
  return repaired.replaceAllMapped(
    _urduWord,
    (match) => kNahjulBalaghaWordFixes[match[0]!] ?? match[0]!,
  );
}

/// Replaces [from] only where it stands as whole words.
///
/// A plain `replaceAll` would also rewrite the inside of real words: the table's
/// «مت پر» … «مت کے» repair the swapped pronoun «تم», but «مت پر» is a substring
/// of «امت پر» and would have turned a correct sentence into «اتم پر». The
/// repaired database keeps «امت» on every page, so the difference matters.
String _replaceWholeWords(String text, String from, String to) {
  final buffer = StringBuffer();
  var start = 0;
  while (true) {
    final index = text.indexOf(from, start);
    if (index < 0) {
      buffer.write(text.substring(start));
      return buffer.toString();
    }
    final before = index == 0 ? '' : text[index - 1];
    final after = index + from.length >= text.length ? '' : text[index + from.length];
    buffer.write(text.substring(start, index));
    final bounded = !_urduWord.hasMatch(before) && !_urduWord.hasMatch(after);
    buffer.write(bounded ? to : from);
    start = index + from.length;
  }
}
