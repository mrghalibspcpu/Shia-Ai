import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import '../reader_navigation.dart';

/// Re-opens the position a reader left off at.
///
/// Every reader writes two things when it saves progress (see
/// `LibraryRepository.saveLastRead`): the global entry, which powers the
/// "آخری مطالعہ" card on the home screen, and one entry per book. This widget
/// renders the second kind — so the Quran remembers its own surah while
/// Mafatih, Sahifa, Nahj al-Balagha and each hadith book remember theirs.
Future<void> openLastRead(
  BuildContext context,
  LibraryRepository library,
  LastReadEntry entry,
) async {
  final book = entry.book;
  if (book == null || !library.isInstalled(book) || !context.mounted) return;
  await pushReaderFor(
    context,
    library: library,
    book: book,
    recordId: entry.recordId,
    sectionId: entry.sectionId,
  );
}

/// "جاری رکھیں" for one book. Renders nothing when that book has no history.
class ResumeCard extends StatelessWidget {
  const ResumeCard({
    super.key,
    required this.library,
    required this.book,
    this.margin = const EdgeInsets.only(bottom: 10),
    this.onOpened,
  });

  final LibraryRepository library;
  final BookDefinition book;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LastReadEntry?>(
      future: library.getLastReadFor(book.key),
      builder: (context, snapshot) {
        final entry = snapshot.data;
        if (entry == null) return const SizedBox.shrink();
        return LastReadTile(
          library: library,
          entry: entry,
          margin: margin,
          title: 'جاری رکھیں',
          onOpened: onOpened,
        );
      },
    );
  }
}

/// One saved position as a tappable card: book, reference, and when it was left.
class LastReadTile extends StatelessWidget {
  const LastReadTile({
    super.key,
    required this.library,
    required this.entry,
    this.title = 'آخری مطالعہ',
    this.margin = const EdgeInsets.only(bottom: 10),
    this.showBookName = true,
    this.onOpened,
    this.onBeforeOpen,
    this.openContext,
  });

  final LibraryRepository library;
  final LastReadEntry entry;
  final String title;
  final EdgeInsetsGeometry margin;

  /// Runs first on tap, before the reader opens (a sheet closes here).
  final VoidCallback? onBeforeOpen;

  /// Where the reader is opened from. A sheet passes the page underneath, since
  /// its own context is gone once the sheet has closed.
  final BuildContext? openContext;

  /// False when the caller already prints the book name as the title.
  final bool showBookName;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    final book = entry.book;
    if (book == null) return const SizedBox.shrink();
    final subtitle = <String>[
      if (showBookName) book.titleUrdu,
      if (entry.referenceOrTitle.isNotEmpty) entry.referenceOrTitle,
      if (entry.timeLabel.isNotEmpty) entry.timeLabel,
    ].join(' — ');
    return Card(
      margin: margin,
      child: ListTile(
        leading: const Icon(Icons.history_toggle_off, color: kForest),
        title: JustifiedText(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: JustifiedText(subtitle, maxLines: 2),
        trailing: const Icon(Icons.chevron_left),
        onTap: () async {
          onBeforeOpen?.call();
          await openLastRead(openContext ?? context, library, entry);
          onOpened?.call();
        },
      ),
    );
  }
}
