import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../widgets/resume_card.dart';
import 'library_screen.dart' show ChapterListScreen;

/// The screen behind the single "دینی مسائل (احکام و فتاویٰ)" library tile.
///
/// The Urdu fatawa databases are one entry in the library: the reader picks a
/// marja here, in a grid, and then browses only that marja's questions. Each
/// tile keeps that book's own last-seen row, refreshed when the book closes.
class FatawaCollectionScreen extends StatefulWidget {
  const FatawaCollectionScreen({
    super.key,
    required this.library,
    this.onOpenData,
  });

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  State<FatawaCollectionScreen> createState() => _FatawaCollectionScreenState();
}

class _FatawaCollectionScreenState extends State<FatawaCollectionScreen> {
  var _generation = 0;

  Future<void> _open(BookDefinition book) async {
    if (!widget.library.isInstalled(book)) {
      widget.onOpenData?.call();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChapterListScreen(library: widget.library, book: book),
    ));
    if (mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final books = fatawaBooks;
    return Scaffold(
      appBar: AppBar(title: const JustifiedText(kFatawaCollectionTitle, maxLines: 1)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                JustifiedText(
                  kFatawaCollectionHint,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                JustifiedText(
                  'ہر سوال کے جواب کے ساتھ اصل سرکاری صفحے کا لنک موجود ہے — '
                  'بٹن دبا کر آپ خود تصدیق کر سکتے ہیں کہ یہ مسئلہ ماخذ میں اسی طرح درج ہے۔',
                  style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return _MarjaCard(
                  key: ValueKey<String>('${book.key}-$_generation'),
                  library: widget.library,
                  book: book,
                  onOpen: () => _open(book),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MarjaCard extends StatelessWidget {
  const _MarjaCard({
    super.key,
    required this.library,
    required this.book,
    required this.onOpen,
  });

  final LibraryRepository library;
  final BookDefinition book;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final installed = library.isInstalled(book);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MarjaPortrait(book: book),
              ),
              const SizedBox(height: 8),
              JustifiedText(
                book.marjaName.isEmpty ? book.titleUrdu : book.marjaName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              FutureBuilder<int>(
                future: library.countRecords(book),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (!installed || count == 0) {
                    return JustifiedText(
                      'ابھی نصب نہیں',
                      style: TextStyle(fontSize: 11, color: colors.error),
                      maxLines: 1,
                    );
                  }
                  return JustifiedText(
                    '$count مسائل',
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                    maxLines: 1,
                  );
                },
              ),
              if (installed) ...[
                const SizedBox(height: 6),
                _LastSeenChip(library: library, book: book),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of where this book was left, tappable into that passage.
class _LastSeenChip extends StatelessWidget {
  const _LastSeenChip({required this.library, required this.book});

  final LibraryRepository library;
  final BookDefinition book;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LastReadEntry?>(
      future: library.getLastReadFor(book.key),
      builder: (context, snapshot) {
        final entry = snapshot.data;
        if (entry == null) return const SizedBox.shrink();
        final label = entry.referenceOrTitle.isEmpty ? 'جاری رکھیں' : entry.referenceOrTitle;
        return Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () => openLastRead(context, library, entry, includeCollection: false),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11.5, color: kGold, fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}

class _MarjaPortrait extends StatelessWidget {
  const _MarjaPortrait({required this.book});

  final BookDefinition book;

  @override
  Widget build(BuildContext context) {
    final asset = book.imageAsset;
    if (asset == null) {
      return Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          gradient: LinearGradient(colors: [kForestDark, kForest]),
        ),
        child: const Icon(Icons.menu_book, color: Colors.white, size: 34),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withValues(alpha: 0.55), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(asset, fit: BoxFit.cover, cacheWidth: 360, cacheHeight: 440),
    );
  }
}
