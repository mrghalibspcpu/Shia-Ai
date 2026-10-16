import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../text_utils.dart' show searchMatchRanges, searchSnippet;
import '../reader_navigation.dart';
import '../widgets/reader_kit.dart';
import '../widgets/highlighted_text.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.library,
    this.onOpenData,
    this.autofocus = false,
  });

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  /// True when the screen was opened from the dashboard's search bar: the
  /// reader is already reaching for the keyboard, so the field takes focus.
  final bool autofocus;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _results = [];
  List<String> _history = [];
  bool _loading = false;
  String? _error;
  String _language = 'all';
  String? _bookKey;
  CorpusSource? _source;
  int _requestId = 0;
  int _total = 0;
  String _resultQuery = '';
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _history = prefs.getStringList('search_history') ?? const []);
  }

  Future<void> _remember(String query) async {
    final value = query.trim();
    if (value.isEmpty) return;
    final next = [value, ..._history.where((item) => item != value)].take(12).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', next);
    if (mounted) setState(() => _history = next);
  }

  /// Removes ONE remembered search (the × on its chip).
  Future<void> _forget(String query) async {
    final next = _history.where((item) => item != query).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', next);
    if (mounted) setState(() => _history = next);
  }

  /// Clears the whole history ("سب حذف کریں").
  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', const <String>[]);
    if (mounted) setState(() => _history = const <String>[]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    ++_requestId; // Invalidate in-flight work immediately, including clear.
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 220), () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    _debounce?.cancel();
    _loadingMore = false;
    final query = value.trim();
    final request = ++_requestId;
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.library.searchPage(
        query,
        limit: 40,
        bookKey: _bookKey,
        language: _language,
        source: _source,
      );
      if (!mounted || request != _requestId) return;
      setState(() {
        _results = page.hits;
        _total = page.total;
        _resultQuery = query;
        _loadingMore = false;
        _loading = false;
      });
      if (query.length >= 3 && page.hits.isNotEmpty) unawaited(_remember(query));
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    final request = _requestId;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.library.searchPage(_resultQuery, offset: _results.length,
        bookKey: _bookKey, language: _language, source: _source);
      if (!mounted || request != _requestId) return;
      setState(() { _results.addAll(page.hits); _total = page.total; _loadingMore = false; });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _chooseBook() async {
    final books = widget.library.installedBooks;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: JustifiedText(
                'کتاب منتخب کریں',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const JustifiedText('تمام کتب'),
              trailing: _bookKey == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final book in books)
              ListTile(
                title: JustifiedText(book.titleUrdu),
                trailing: _bookKey == book.key ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, book.key),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      _bookKey = selected.isEmpty ? null : selected;
      _source = null;
    });
    if (_controller.text.trim().isNotEmpty) _runSearch(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final selectedBook = BookDefinition.byKey(_bookKey);
    return Scaffold(
      appBar: AppBar(title: const JustifiedText('متن میں تلاش')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              onChanged: _scheduleSearch,
              onSubmitted: _runSearch,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'اردو یا عربی لفظ لکھیں',
                prefixIcon: IconButton(
                  tooltip: 'تلاش',
                  onPressed: () => _runSearch(_controller.text),
                  icon: const Icon(Icons.search),
                ),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          _scheduleSearch('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ChoiceChip(
                  label: const Text('تمام مصادر'),
                  selected: _source == null && _bookKey == null,
                  onSelected: (_) {
                    setState(() {
                      _source = null;
                      _bookKey = null;
                    });
                    if (_controller.text.trim().isNotEmpty) _runSearch(_controller.text);
                  },
                ),
                for (final source in CorpusSource.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(source.label),
                    selected: _source == source && _bookKey == null,
                    onSelected: (_) {
                      setState(() {
                        _source = source;
                        _bookKey = null;
                      });
                      if (_controller.text.trim().isNotEmpty) _runSearch(_controller.text);
                    },
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('سب'), icon: Icon(Icons.language)),
                        ButtonSegment(value: 'arabic', label: Text('عربی'), icon: Icon(Icons.text_fields)),
                        ButtonSegment(value: 'urdu', label: Text('اردو'), icon: Icon(Icons.translate)),
                      ],
                      selected: {_language},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        setState(() => _language = selection.first);
                        if (_controller.text.trim().isNotEmpty) _runSearch(_controller.text);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _chooseBook,
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: Text(
                    selectedBook?.titleUrdu ?? 'کتاب چنیں',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<IndexBuildState>(
            valueListenable: widget.library.indexProgress,
            builder: (context, state, _) {
              if (!state.active) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      state.message,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: state.progress <= 0 ? null : state.progress),
                    const SizedBox(height: 4),
                    Text(
                      'تلاش ابھی جزوی ہے — فہرست مکمل ہونے پر نتائج بڑھ جائیں گے۔',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_controller.text.trim().isNotEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _results.isEmpty ? 'کوئی نتیجہ نہیں' : '$_total نتائج — ${_results.length} دکھائے گئے',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
            ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _results.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorPanel(error: _error!);
    if (_controller.text.trim().isEmpty) {
      final missing = BookDefinition.all.length - widget.library.installedBooks.length;
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        children: [
          Icon(Icons.manage_search, size: 58, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const JustifiedText(
            'قرآن، صحیفہ سجادیہ، فتاویٰ، دعائیں، نہج البلاغہ اور تمام کتبِ احادیث میں عربی و اردو عبارت تلاش کریں۔',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<IndexBuildState>(
            valueListenable: widget.library.indexProgress,
            builder: (context, state, _) => Text(
              state.active
                  ? '${widget.library.installedBooks.length} کتب دستیاب ہیں — تلاش کی فہرست تیار ہو رہی ہے'
                  : '${widget.library.installedBooks.length} کتب کی مقامی فہرست تیار ہے',
              textDirection: TextDirection.rtl,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          if (missing > 0 && widget.onOpenData != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: widget.onOpenData,
              icon: const Icon(Icons.download_outlined),
              label: Text('$missing کتب ابھی باقی ہیں — ڈاؤن لوڈ کریں'),
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: JustifiedText('حالیہ تلاشیں', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: () => unawaited(_clearHistory()),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('سب حذف کریں', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _history)
                  InputChip(
                    label: Text(item),
                    deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    deleteButtonTooltipMessage: 'یہ تلاش حذف کریں',
                    onDeleted: () => unawaited(_forget(item)),
                    onPressed: () {
                      _controller.text = item;
                      _controller.selection = TextSelection.collapsed(offset: item.length);
                      _runSearch(item);
                    },
                  ),
              ],
            ),
          ],
        ],
      );
    }
    if (!_loading && _results.isEmpty) {
      return const CollectionMessage(
        'اس تلاش کے مطابق کوئی نتیجہ نہیں ملا۔ دوسرا لفظ یا مختصر کلیدی لفظ آزمائیں۔',
        icon: Icons.search_off,
      );
    }
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: _results.length + (_results.length < _total ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == _results.length) return Center(child: TextButton.icon(
              onPressed: _loadingMore || _loading ? null : _loadMore,
              icon: const Icon(Icons.expand_more),
              label: Text(_loadingMore ? 'مزید نتائج آ رہے ہیں…' : 'مزید نتائج دکھائیں'),
            ));
            return _SearchResultCard(
            hit: _results[index],
            query: _resultQuery,
            onTap: () => pushReaderFor(
              context,
              library: widget.library,
              book: _results[index].book,
              passage: _results[index].passage,
              searchQuery: _resultQuery,
            ),
          );
          },
        ),
        if (_loading)
          const Positioned(left: 16, right: 16, top: 0, child: LinearProgressIndicator(minHeight: 2)),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.hit, required this.onTap, required this.query});

  final SearchHit hit;
  final VoidCallback onTap;
  final String query;

  @override
  Widget build(BuildContext context) {
    final passage = hit.passage;
    final candidates = [passage.urdu, passage.commentary, passage.footnote, passage.arabic];
    final body = candidates.firstWhere((text) => searchMatchRanges(text, query).isNotEmpty,
      orElse: () => candidates.firstWhere((text) => text.isNotEmpty, orElse: () => ''));
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: JustifiedText(
                      hit.book.titleUrdu,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      // A readable locator or the section name — never the
                      // raw database row id (e.g. Parags.ID 562276), which
                      // readers mistook for a hadith number.
                      passage.locator.isNotEmpty
                          ? passage.locator
                          : (passage.sectionTitle.isNotEmpty
                              ? passage.sectionTitle
                              : passage.chapterTitle),
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              if (passage.sectionTitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                JustifiedText(
                  passage.sectionTitle,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  maxLines: 1,
                ),
              ],
              if (passage.arabic.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                HighlightedText(
                  searchSnippet(passage.arabic, query),
                  query: query,
                  arabic: true,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: kArabicFont, fontSize: 18, height: 1.65, letterSpacing: 0),
                ),
              ],
              if (body.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                HighlightedText(
                  searchSnippet(body, query),
                  query: query,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: kUrduFont, fontSize: 17, height: 1.5),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: JustifiedText(
                      hit.citation,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      maxLines: 5,
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
