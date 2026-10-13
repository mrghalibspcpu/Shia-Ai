import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../widgets/reader_kit.dart';

/// Mafatih al-Jinan: chapters, supplications, and the reader.
class DuasHomeScreen extends StatelessWidget {
  const DuasHomeScreen({super.key, required this.library});

  final LibraryRepository library;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const JustifiedText('دعائیں و اعمال')),
      body: FutureBuilder<List<DuaCategory>>(
        future: library.getDuaCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
          final categories = snapshot.data ?? const [];
          if (categories.isEmpty) {
            return const CollectionMessage('دعائیں دستیاب نہیں۔', icon: Icons.mosque_outlined);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _FeaturedDuas(library: library),
              const SizedBox(height: 16),
              for (final category in categories) ...[
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.mosque, size: 20),
                    ),
                    title: JustifiedText(
                      category.titleUrdu,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      maxLines: 2,
                    ),
                    subtitle: Text(
                      '${category.itemCount} عنوانات',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DuaCategoryScreen(library: library, category: category),
                    )),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FeaturedDuas extends StatelessWidget {
  const _FeaturedDuas({required this.library});

  final LibraryRepository library;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DuaItem>>(
      future: library.getFeaturedDuas(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const JustifiedText('منتخب دعائیں', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return SizedBox(
                    width: 178,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DuaReaderScreen(library: library, item: item),
                        )),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Icon(Icons.auto_awesome, size: 18, color: Theme.of(context).colorScheme.primary),
                              const Spacer(),
                              JustifiedText(
                                item.name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class DuaCategoryScreen extends StatelessWidget {
  const DuaCategoryScreen({super.key, required this.library, required this.category});

  final LibraryRepository library;
  final DuaCategory category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: JustifiedText(category.titleUrdu, maxLines: 1)),
      body: FutureBuilder<List<DuaItem>>(
        future: library.getDuaItems(category.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const CollectionMessage('اس حصے میں کوئی عنوان نہیں۔');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.isHeader) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                  child: JustifiedText(
                    item.name,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: kForest,
                    ),
                    maxLines: 2,
                  ),
                );
              }
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: JustifiedText(item.name, style: const TextStyle(fontSize: 16), maxLines: 2),
                  subtitle: item.lineCount == 0
                      ? null
                      : Text(
                          '${item.lineCount} سطور',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                  trailing: item.isFeatured
                      ? Icon(Icons.star, size: 18, color: kGold)
                      : const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DuaReaderScreen(library: library, item: item),
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DuaReaderScreen extends StatefulWidget {
  const DuaReaderScreen({super.key, required this.library, required this.item});

  final LibraryRepository library;
  final DuaItem item;

  @override
  State<DuaReaderScreen> createState() => _DuaReaderScreenState();
}

class _DuaReaderScreenState extends State<DuaReaderScreen> {
  final BookDefinition _book = BookDefinition.bookFor(CorpusSource.dua)!;
  final ItemScrollController _scrollController = ItemScrollController();

  List<Passage> _lines = const [];
  ReaderPreferences _preferences = const ReaderPreferences();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final preferences = await ReaderPreferences.load();
      final lines = await widget.library.getDuaLines(widget.item.rowId);
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _lines = lines;
        _loading = false;
      });
      if (lines.isNotEmpty) {
        unawaited(widget.library.saveLastRead(
          bookKey: _book.key,
          recordId: widget.item.rowId,
        ));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _preferences.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.foreground,
        title: JustifiedText(widget.item.name, style: TextStyle(color: palette.foreground), maxLines: 1),
        actions: [
          ReaderControls(
            preferences: _preferences,
            onChanged: (value) => setState(() => _preferences = value),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorPanel(error: _error!)
              : _lines.isEmpty
                  ? const CollectionMessage('اس دعا کا متن موجود نہیں۔')
                  : ScrollablePositionedList.builder(
                      key: PageStorageKey('dua-${widget.item.rowId}'),
                      itemScrollController: _scrollController,
                      itemCount: _lines.length,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                      itemBuilder: (context, index) => PassageCard(
                        key: ValueKey('dua-${widget.item.rowId}-${_lines[index].recordId}'),
                        library: widget.library,
                        book: _book,
                        passage: _lines[index],
                        // Bookmark/note the whole supplication, not one line of it.
                        stateId: widget.item.rowId,
                        palette: palette,
                        fontScale: _preferences.fontScale,
                        script: _preferences.script,
                      ),
                    ),
    );
  }
}
