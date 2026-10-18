import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../reader_navigation.dart';
import '../widgets/reader_kit.dart';
import '../widgets/chapter_wallpaper.dart';
import 'library_screen.dart';

/// **Xplore → نئی کتابیں**: the books that joined the library after the
/// original corpus.
///
/// The first of them is the Shia Urdu Wikipedia collection: 1,588 articles
/// stored as their ordered sections, with the exact Wikipedia page (and, where
/// it exists, the exact section anchor) attached to every card so any sentence
/// can be verified at its source. Browse it by category, by the twelve Imams,
/// by curated topic — or search inside it.
class NewBooksScreen extends StatelessWidget {
  const NewBooksScreen({
    super.key,
    required this.library,
    this.onOpenData,
  });

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const JustifiedText('نئی کتابیں')),
      body: ValueListenableBuilder<int>(
        valueListenable: library.catalogVersion,
        builder: (context, _, __) {
          final books = BookDefinition.newBooks;
          return ListView(
            key: const PageStorageKey<String>('new-books-list'),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: <Widget>[
              const _IntroCard(),
              const SizedBox(height: 14),
              for (final book in books) ...<Widget>[
                _NewBookCard(
                  book: book,
                  installed: library.isInstalled(book),
                  onOpen: () => unawaited(Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WikiBrowseScreen(
                        library: library,
                        book: book,
                        onOpenData: onOpenData,
                      ),
                    ),
                  )),
                  onDownload: onOpenData,
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChapterWallpaperCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.auto_stories_rounded, size: 20, color: scheme.secondary),
                const SizedBox(width: 7),
                const Expanded(
                  child: JustifiedText(
                    'کتابوں کی نئی کھیپ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            JustifiedText(
              'قرآن، حدیث، دعا اور فتاویٰ کے ساتھ اب اردو ویکیپیڈیا کا منتخب شیعہ ذخیرہ '
              'بھی اسی لائبریری میں — اسی پڑھنے کے انداز، تلاش اور آخری مطالعہ کے ساتھ۔',
              style: TextStyle(fontSize: 13.5, height: 1.6, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewBookCard extends StatelessWidget {
  const _NewBookCard({
    required this.book,
    required this.installed,
    required this.onOpen,
    this.onDownload,
  });

  final BookDefinition book;
  final bool installed;
  final VoidCallback onOpen;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final accent = bookAccent(book);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: installed ? onOpen : onDownload,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[accent.withValues(alpha: 0.20), accent.withValues(alpha: 0.05)],
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    JustifiedText(
                      book.titleUrdu,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 3),
                    JustifiedText(
                      book.description,
                      maxLines: 2,
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: <Widget>[
                        Icon(
                          installed ? Icons.check_circle_rounded : Icons.download_rounded,
                          size: 15,
                          color: installed ? accent : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          installed ? 'کھولیں — اقسام، ائمہ اور تلاش' : 'ڈاؤن لوڈ درکار',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}

/// The browser for the Wikipedia collection: the twelve Imams, curated topics,
/// the eleven categories, and an in-book search.
class WikiBrowseScreen extends StatefulWidget {
  const WikiBrowseScreen({
    super.key,
    required this.library,
    required this.book,
    this.onOpenData,
  });

  final LibraryRepository library;
  final BookDefinition book;
  final VoidCallback? onOpenData;

  @override
  State<WikiBrowseScreen> createState() => _WikiBrowseScreenState();
}

class _WikiBrowseScreenState extends State<WikiBrowseScreen> {
  final TextEditingController _search = TextEditingController();
  late Future<List<Map<String, Object?>>> _categories;
  Future<List<Map<String, Object?>>>? _imams;
  Future<List<Map<String, Object?>>>? _topics;
  Future<({int articles, int sections, int references})>? _stats;

  String _query = '';
  bool _searching = false;
  List<SearchHit> _hits = const <SearchHit>[];
  int _total = 0;
  String? _searchError;

  BookDefinition get _book => widget.book;

  @override
  void initState() {
    super.initState();
    _categories = widget.library.getChapters(_book);
    _imams = widget.library.getWikiImams();
    _topics = widget.library.getWikiTopics();
    _stats = widget.library.wikiStats();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _hits = const <SearchHit>[];
        _total = 0;
        _searchError = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _query = query;
      _searching = true;
      _searchError = null;
    });
    try {
      final page = await widget.library.searchPage(
        query,
        bookKey: _book.key,
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        _hits = page.hits;
        _total = page.total;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searchError = error.toString();
        _searching = false;
      });
    }
  }

  void _openArticle(int articleId, String title) {
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReaderScreen(
        library: widget.library,
        book: _book,
        sectionId: articleId,
        sectionTitle: title,
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: JustifiedText(_book.titleUrdu, maxLines: 1),
      ),
      body: ListView(
        key: const PageStorageKey<String>('wiki-browse'),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        children: <Widget>[
          _header(scheme),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => unawaited(_runSearch(value)),
            decoration: InputDecoration(
              hintText: 'اس ذخیرے میں تلاش کریں — مثلاً: غدیر، کربلا، امامت',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'تلاش',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => unawaited(_runSearch(_search.text)),
              ),
            ),
          ),
          if (_query.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _searchResults(scheme),
          ],
          const SizedBox(height: 16),
          // The twelve Imams, in order.
          FutureBuilder<List<Map<String, Object?>>>(
            future: _imams,
            builder: (context, snapshot) {
              final imams = snapshot.data ?? const <Map<String, Object?>>[];
              if (imams.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _SectionLabel('ائمہ اثنا عشر'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imams.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final row = imams[index];
                        final number = _int(row['number']) ?? index + 1;
                        final articleId = _int(row['article_id']);
                        final title = (row['title'] ?? '').toString();
                        return _ImamChip(
                          number: number,
                          title: title,
                          onTap: articleId == null
                              ? null
                              : () => _openArticle(articleId, title),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
          FutureBuilder<List<Map<String, Object?>>>(
            future: _topics,
            builder: (context, snapshot) {
              final topics = snapshot.data ?? const <Map<String, Object?>>[];
              if (topics.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _SectionLabel('منتخب موضوعات'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final topic in topics)
                        ActionChip(
                          avatar: Icon(Icons.label_important_outline, size: 16, color: scheme.primary),
                          label: Text((topic['title'] ?? '').toString()),
                          onPressed: () {
                            final id = _int(topic['article_id']);
                            if (id != null) {
                              _openArticle(id, (topic['article_title'] ?? topic['title'] ?? '').toString());
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
          const _SectionLabel('اقسام'),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, Object?>>>(
            future: _categories,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final categories = snapshot.data ?? const <Map<String, Object?>>[];
              if (categories.isEmpty) {
                return const CollectionMessage('اقسام دستیاب نہیں۔');
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.2,
                ),
                itemBuilder: (context, index) {
                  final row = categories[index];
                  final id = _int(row['cid']) ?? _int(row['ID']);
                  final title = (row['title'] ?? '').toString();
                  final count = _int(row['count']) ?? 0;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: id == null
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => SectionListScreen(
                                  library: widget.library,
                                  book: _book,
                                  chapterId: id,
                                  chapterTitle: title,
                                ),
                              )),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  JustifiedText(
                                    title,
                                    maxLines: 1,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$count مضامین',
                                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_left, size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          _attribution(scheme),
        ],
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    return FutureBuilder<({int articles, int sections, int references})>(
      future: _stats,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        return ChapterWallpaperCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.travel_explore_rounded, size: 21, color: scheme.secondary),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: JustifiedText(
                        'شیعہ اردو ویکیپیڈیا',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                JustifiedText(
                  'عقائد، ائمہ، تاریخ، واقعات، کتب، شخصیات اور مقامات — ہر مضمون اپنے اصل '
                  'ویکیپیڈیا ماخذ اور CC BY-SA 4.0 انتساب کے ساتھ۔ کسی بھی کارڈ کے نیچے «ماخذ» '
                  'دبا کر وہی صفحہ براہِ راست کھل جاتا ہے۔',
                  style: TextStyle(fontSize: 13, height: 1.6, color: scheme.onSurfaceVariant),
                ),
                if (stats != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      _Stat(label: 'مضامین', value: stats.articles),
                      _Stat(label: 'حصے', value: stats.sections),
                      _Stat(label: 'ماخذ', value: stats.references),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _searchResults(ColorScheme scheme) {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_searchError != null) {
      return CollectionMessage('تلاش میں مسئلہ: $_searchError');
    }
    if (_hits.isEmpty) {
      return const CollectionMessage('اس لفظ کے ساتھ کوئی متن نہیں ملا۔');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '$_total مقامات ملے — $_query',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.primary),
        ),
        const SizedBox(height: 6),
        for (final hit in _hits)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              title: JustifiedText(
                hit.passage.sectionTitle.isEmpty ? hit.book.titleUrdu : hit.passage.sectionTitle,
                maxLines: 1,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              subtitle: JustifiedText(
                hit.passage.urdu,
                maxLines: 3,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: scheme.onSurfaceVariant),
              ),
              onTap: () async {
                await pushReaderFor(
                  context,
                  library: widget.library,
                  book: hit.book,
                  passage: hit.passage,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _attribution(ColorScheme scheme) {
    return GlassFootnote(
      text: 'ماخذ: اردو ویکیپیڈیا (ur.wikipedia.org) — CC BY-SA 4.0۔ متن بغیر تبدیلی کے '
          'محفوظ ہے؛ ہر مضمون کا اصل صفحہ اور revision لنک کارڈ پر موجود ہے۔ یہ ذخیرہ '
          'مطالعے کے لیے ہے، مکمل ویکیپیڈیا کا دعویٰ نہیں۔',
    );
  }
}

/// A small note line at the bottom of a browse page.
class GlassFootnote extends StatelessWidget {
  const GlassFootnote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: JustifiedText(
        text,
        style: TextStyle(fontSize: 11.5, height: 1.55, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        JustifiedText(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            '$value',
            style: TextStyle(
              fontFamily: kDigitFont,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ImamChip extends StatelessWidget {
  const _ImamChip({required this.number, required this.title, this.onTap});

  final int number;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 132,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontFamily: kDigitFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('امام', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 6),
                JustifiedText(
                  title,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
