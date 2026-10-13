import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import 'library_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.library, required this.onOpenAi});

  final LibraryRepository library;
  final void Function(BookDefinition book, Passage passage) onOpenAi;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _results = [];
  bool _loading = false;
  String? _error;
  String _language = 'all';
  String? _bookKey;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() { _results = []; _loading = false; _error = null; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    _debounce = Timer(const Duration(milliseconds: 280), () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    _debounce?.cancel();
    final request = ++_requestId;
    setState(() { _loading = true; _error = null; });
    try {
      final results = await widget.library.search(
        value,
        limit: 40,
        bookKey: _bookKey,
        language: _language,
      );
      if (!mounted || request != _requestId) return;
      setState(() { _results = results; _loading = false; });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _chooseBook() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.all(18), child: JustifiedText('کتاب منتخب کریں', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            ListTile(title: const Text('تمام کتب'), trailing: _bookKey == null ? const Icon(Icons.check) : null, onTap: () => Navigator.pop(context, '')),
            for (final book in BookDefinition.all)
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
    setState(() => _bookKey = selected.isEmpty ? null : selected);
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
              autofocus: false,
              onChanged: _scheduleSearch,
              onSubmitted: _runSearch,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'اردو یا عربی لفظ لکھیں',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(onPressed: () { _controller.clear(); _scheduleSearch(''); }, icon: const Icon(Icons.close)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                  label: Text(selectedBook?.titleUrdu ?? 'تمام کتب', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _results.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(22), child: JustifiedText(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))));
    }
    if (_controller.text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.manage_search, size: 58, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const JustifiedText('تمام کتب میں عربی اور اردو عبارت تلاش کریں۔', style: TextStyle(fontSize: 18),),
              const SizedBox(height: 6),
              Text('96 ہزار سے زائد روایات، مقامی فہرست کے ساتھ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    if (!_loading && _results.isEmpty) {
      return const Center(child: JustifiedText('اس تلاش کے مطابق کوئی نتیجہ نہیں ملا۔', style: TextStyle(fontSize: 18)));
    }
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: _results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _SearchResultCard(
            hit: _results[index],
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ReaderScreen(
                library: widget.library,
                book: _results[index].book,
                recordId: _results[index].passage.recordId,
                sectionTitle: _results[index].passage.sectionTitle,
                onOpenAi: widget.onOpenAi,
              ),
            )),
          ),
        ),
        if (_loading)
          const Positioned(left: 16, right: 16, top: 0, child: LinearProgressIndicator(minHeight: 2)),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final passage = hit.passage;
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
                  Expanded(child: JustifiedText(hit.book.titleUrdu, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1)),
                  const SizedBox(width: 6),
                  Text('حدیث ${passage.recordId}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
              if (passage.sectionTitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                JustifiedText(passage.sectionTitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 1),
              ],
              if (passage.arabic.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(passage.arabic, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.justify,
                      style: const TextStyle(fontFamily: kArabicFont, fontSize: 18, height: 1.65)),
                ),
              ],
              if (passage.urdu.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                JustifiedText(passage.urdu, maxLines: 3, style: const TextStyle(fontSize: 17, height: 1.55)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: JustifiedText(hit.citation, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 2)),
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
