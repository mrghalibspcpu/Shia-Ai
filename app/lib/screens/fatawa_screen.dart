import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../widgets/resume_card.dart';
import 'library_screen.dart' show ChapterListScreen;

/// The screen behind the single "دینی مسائل (احکام و فتاویٰ)" library tile.
///
/// The two Urdu fatawa databases are one entry in the library: the reader picks
/// a marja here and then browses only that marja's questions, instead of
/// guessing which of two identical-looking tiles to open.
class FatawaCollectionScreen extends StatelessWidget {
  const FatawaCollectionScreen({
    super.key,
    required this.library,
    this.onOpenData,
  });

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const JustifiedText(kFatawaCollectionTitle, maxLines: 1)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
          const SizedBox(height: 16),
          for (final book in fatawaBooks) ...[
            _MarjaCard(library: library, book: book, onOpenData: onOpenData),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _MarjaCard extends StatelessWidget {
  const _MarjaCard({
    required this.library,
    required this.book,
    this.onOpenData,
  });

  final LibraryRepository library;
  final BookDefinition book;
  final VoidCallback? onOpenData;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final installed = library.isInstalled(book);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MarjaPortrait(book: book),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      JustifiedText(
                        book.marjaName.isEmpty ? book.titleUrdu : book.marjaName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.titleLatin,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<int>(
                        future: library.countRecords(book),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          if (!installed || count == 0) {
                            return JustifiedText(
                              'ابھی نصب نہیں — ڈاؤن لوڈ کریں',
                              style: TextStyle(fontSize: 12, color: colors.error),
                            );
                          }
                          return JustifiedText(
                            '$count مسائل و احکام',
                            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (!installed) {
                        onOpenData?.call();
                        return;
                      }
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChapterListScreen(library: library, book: book),
                      ));
                    },
                    icon: Icon(installed ? Icons.menu_book : Icons.download_outlined, size: 18),
                    label: Text(installed ? 'مسائل دیکھیں' : 'ڈاؤن لوڈ کریں'),
                  ),
                ),
              ],
            ),
            if (installed) ...[
              const SizedBox(height: 10),
              ResumeCard(
                library: library,
                book: book,
                margin: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
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
        width: 84,
        height: 104,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [kForestDark, kForest]),
        ),
        child: const Icon(Icons.menu_book, color: Colors.white, size: 34),
      );
    }
    return Container(
      width: 84,
      height: 104,
      decoration: BoxDecoration(
        border: Border.all(color: kGold.withValues(alpha: 0.55), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(asset, fit: BoxFit.cover,
        cacheWidth: 252, cacheHeight: 312),
    );
  }
}
