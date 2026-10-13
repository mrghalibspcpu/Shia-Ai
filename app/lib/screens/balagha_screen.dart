import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../widgets/reader_kit.dart';

/// Nahj al-Balagha: khutbas, letters, wisdoms, prophetic traditions, and the
/// introductions that accompany them.
class BalaghaHomeScreen extends StatelessWidget {
  const BalaghaHomeScreen({super.key, required this.library});

  final LibraryRepository library;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const JustifiedText('نہج البلاغہ')),
      body: FutureBuilder<List<BalaghaSection>>(
        future: library.getBalaghaSections(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
          final sections = snapshot.data ?? const [];
          if (sections.isEmpty) {
            return const CollectionMessage('نہج البلاغہ دستیاب نہیں۔', icon: Icons.auto_stories_outlined);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              for (final section in sections) ...[
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.auto_stories, size: 20),
                    ),
                    title: JustifiedText(
                      section.titleUrdu,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      '${section.entryCount} عنوانات',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BalaghaSectionScreen(library: library, section: section),
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

class BalaghaSectionScreen extends StatelessWidget {
  const BalaghaSectionScreen({super.key, required this.library, required this.section});

  final LibraryRepository library;
  final BalaghaSection section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: JustifiedText(section.titleUrdu, maxLines: 1)),
      body: FutureBuilder<List<BalaghaEntry>>(
        future: library.getBalaghaEntries(section.type),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString());
          final entries = snapshot.data ?? const [];
          if (entries.isEmpty && !section.hasIntroduction) {
            return const CollectionMessage('اس حصے میں کوئی عنوان نہیں۔');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
            itemCount: entries.length + (section.hasIntroduction ? 1 : 0),
            itemBuilder: (context, index) {
              if (section.hasIntroduction && index == 0) {
                return Card(
                  color: kForest.withValues(alpha: 0.08),
                  child: ListTile(
                    leading: const Icon(Icons.import_contacts, color: kForest),
                    title: const JustifiedText('اس حصے کا مقدمہ', style: TextStyle(fontSize: 17)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BalaghaIntroductionScreen(
                        library: library,
                        type: section.type,
                        title: '${section.titleUrdu} — مقدمہ',
                      ),
                    )),
                  ),
                );
              }
              final entry = entries[index - (section.hasIntroduction ? 1 : 0)];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Text('${entry.typeNo}'),
                  ),
                  title: JustifiedText(
                    entry.title.isEmpty ? 'عنوان ${entry.typeNo}' : entry.title,
                    style: const TextStyle(fontSize: 16),
                    maxLines: 2,
                  ),
                  subtitle: entry.paragraphCount == 0
                      ? null
                      : Text(
                          '${entry.paragraphCount} فقرے',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BalaghaReaderScreen(
                      library: library,
                      type: section.type,
                      typeNo: entry.typeNo,
                      title: entry.title,
                    ),
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

class BalaghaReaderScreen extends StatelessWidget {
  const BalaghaReaderScreen({
    super.key,
    required this.library,
    required this.type,
    required this.typeNo,
    required this.title,
  });

  final LibraryRepository library;
  final int type;
  final int typeNo;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _BalaghaPassageList(
      library: library,
      title: title.isEmpty ? '${balaghaSectionTitles[type] ?? ''} $typeNo' : title,
      loader: () => library.getBalaghaEntry(type, typeNo),
      storageKey: 'balagha-$type-$typeNo',
      recordIdForLastRead: typeNo,
    );
  }
}

class BalaghaIntroductionScreen extends StatelessWidget {
  const BalaghaIntroductionScreen({
    super.key,
    required this.library,
    required this.type,
    required this.title,
  });

  final LibraryRepository library;
  final int type;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _BalaghaPassageList(
      library: library,
      title: title,
      loader: () => library.getBalaghaIntroduction(type),
      storageKey: 'balagha-intro-$type',
      recordIdForLastRead: 0,
    );
  }
}

class _BalaghaPassageList extends StatefulWidget {
  const _BalaghaPassageList({
    required this.library,
    required this.title,
    required this.loader,
    required this.storageKey,
    required this.recordIdForLastRead,
  });

  final LibraryRepository library;
  final String title;
  final Future<List<Passage>> Function() loader;
  final String storageKey;
  final int recordIdForLastRead;

  @override
  State<_BalaghaPassageList> createState() => _BalaghaPassageListState();
}

class _BalaghaPassageListState extends State<_BalaghaPassageList> {
  final BookDefinition _book = BookDefinition.bookFor(CorpusSource.balagha)!;

  List<Passage> _passages = const [];
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
      final passages = await widget.loader();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _passages = passages;
        _loading = false;
      });
      if (passages.isNotEmpty && widget.recordIdForLastRead > 0) {
        unawaited(widget.library.saveLastRead(
          bookKey: _book.key,
          recordId: passages.first.recordId,
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
        title: JustifiedText(widget.title, style: TextStyle(color: palette.foreground), maxLines: 1),
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
              : _passages.isEmpty
                  ? const CollectionMessage('اس حصے میں متن موجود نہیں۔')
                  : ListView.builder(
                      key: PageStorageKey(widget.storageKey),
                      itemCount: _passages.length,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                      itemBuilder: (context, index) => PassageCard(
                        key: ValueKey('balagha-${_passages[index].recordId}'),
                        library: widget.library,
                        book: _book,
                        passage: _passages[index],
                        palette: palette,
                        fontScale: _preferences.fontScale,
                        script: _preferences.script,
                      ),
                    ),
    );
  }
}
