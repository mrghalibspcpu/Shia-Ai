import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../widgets/resume_card.dart';
import 'duas_screen.dart';
import 'library_screen.dart' show ChapterListScreen;

/// The screen behind the single "مفاتیح الجنان و صحیفہ سجادیہ" library tile.
///
/// The two prayer books are one entry on the home row — like the fatawa — and
/// the reader picks the book here: Mafatih al-Jinan opens its chapters of
/// duas, ziyarat and a'mal, Sahifa Sajjadiyya opens its list of duas. Each
/// book keeps its own "continue reading" row.
class DuaCollectionScreen extends StatefulWidget {
  const DuaCollectionScreen({
    super.key,
    required this.library,
    this.onOpenData,
  });

  final LibraryRepository library;
  final VoidCallback? onOpenData;

  @override
  State<DuaCollectionScreen> createState() => _DuaCollectionScreenState();
}

class _DuaCollectionScreenState extends State<DuaCollectionScreen> {
  /// Re-reads the saved positions after a book is closed.
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const JustifiedText(kDuaCollectionTitle, maxLines: 1)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const JustifiedText(
            kDuaCollectionHint,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          JustifiedText(
            'دعاؤں کی دونوں کتابیں ایک جگہ: مفاتیح الجنان میں روزانہ کی دعائیں، زیارات، '
            'تعقیبات اور مہینوں کے اعمال؛ صحیفہ سجادیہ میں امام زین العابدین (ع) کی دعائیں۔',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (final book in duaCollectionBooks) ...[
            _DuaBookCard(
              library: widget.library,
              book: book,
              onOpenData: widget.onOpenData,
              onClosed: _refresh,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _DuaBookCard extends StatelessWidget {
  const _DuaBookCard({
    required this.library,
    required this.book,
    required this.onClosed,
    this.onOpenData,
  });

  final LibraryRepository library;
  final BookDefinition book;
  final VoidCallback onClosed;
  final VoidCallback? onOpenData;

  bool get _isMafatih => book.source == CorpusSource.dua;

  Future<void> _open(BuildContext context) async {
    if (!library.isInstalled(book)) {
      onOpenData?.call();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _isMafatih
          ? DuasHomeScreen(library: library)
          : ChapterListScreen(library: library, book: book),
    ));
    onClosed();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final installed = library.isInstalled(book);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BookCover(mafatih: _isMafatih),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        JustifiedText(
                          book.titleUrdu,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          book.titleLatin,
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 11.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        JustifiedText(
                          book.description,
                          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 6),
                        if (!installed)
                          JustifiedText(
                            'ابھی نصب نہیں — ڈاؤن لوڈ کریں',
                            style: TextStyle(fontSize: 12.5, color: colors.error),
                          )
                        else
                          _BookCount(library: library, book: book, mafatih: _isMafatih),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _open(context),
                icon: Icon(installed ? Icons.menu_book : Icons.download_outlined, size: 18),
                label: Text(
                  installed ? (_isMafatih ? 'مفاتیح الجنان کھولیں' : 'صحیفہ سجادیہ کھولیں') : 'ڈاؤن لوڈ کریں',
                ),
              ),
              if (installed) ...[
                const SizedBox(height: 10),
                ResumeCard(
                  library: library,
                  book: book,
                  margin: EdgeInsets.zero,
                  onOpened: onClosed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "N عنوانات" for Mafatih, "N دعائیں" for Sahifa.
class _BookCount extends StatelessWidget {
  const _BookCount({required this.library, required this.book, required this.mafatih});

  final LibraryRepository library;
  final BookDefinition book;
  final bool mafatih;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 12.5, color: colors.primary, fontWeight: FontWeight.w600);
    if (mafatih) {
      return FutureBuilder<int>(
        future: library.countRecords(book),
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          if (count <= 0) return const SizedBox.shrink();
          return JustifiedText('$count عنوانات', style: style);
        },
      );
    }
    return FutureBuilder<List<Map<String, Object?>>>(
      future: library.getChapters(book),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        if (count <= 0) return const SizedBox.shrink();
        return JustifiedText('$count دعائیں', style: style);
      },
    );
  }
}

/// A small painted cover: gold for Mafatih, emerald for Sahifa, with the
/// book's Arabic name.
class _BookCover extends StatelessWidget {
  const _BookCover({required this.mafatih});

  final bool mafatih;

  @override
  Widget build(BuildContext context) {
    final colors = mafatih
        ? const <Color>[Color(0xFF7A5418), kGold]
        : const <Color>[kForestDark, kForest];
    return Container(
      width: 84,
      height: 108,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        border: Border.all(color: kGold.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(mafatih ? Icons.mosque : Icons.auto_stories, color: Colors.white, size: 30),
          const SizedBox(height: 6),
          Text(
            mafatih ? 'مفاتيح الجنان' : 'الصحيفة السجادية',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontFamily: kArabicFont,
              fontSize: 12.5,
              height: 1.3,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
