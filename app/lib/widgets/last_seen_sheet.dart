import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import 'resume_card.dart';

/// Every saved reading position, most recent first.
///
/// One `SharedPreferences` pass: each book's own entry, plus the global
/// آخری مطالعہ when its book has no entry of its own (pre-1.5 installs), so
/// the newest position is never listed twice.
Future<List<LastReadEntry>> loadLastSeenEntries(LibraryRepository library) async {
  final global = await library.getLastRead();
  final perBook = await library.getLastReads();
  final entries = <LastReadEntry>[];
  final seen = <String>{};
  for (final entry in perBook) {
    final book = entry.book;
    if (book == null || !library.isInstalled(book)) continue;
    entries.add(entry);
    seen.add(entry.bookKey);
  }
  final latestBook = global?.book;
  if (global != null &&
      latestBook != null &&
      !seen.contains(global.bookKey) &&
      library.isInstalled(latestBook)) {
    entries.insert(0, global);
  }
  return entries;
}

/// The bottom panel's **آخری مطالعہ** button: the complete history in a sheet.
///
/// Tapping an entry re-opens that exact spot (the sheet closes as the reader
/// opens). An empty history gets a short note instead of an empty sheet.
Future<void> showLastSeenSheet(
  BuildContext context, {
  required LibraryRepository library,
  VoidCallback? onOpened,
}) async {
  final entries = await loadLastSeenEntries(library);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      // A bounded box keeps the sheet honest: a short history sits on a short
      // sheet, a long one scrolls instead of running off the screen.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 0, 6, 10),
              child: JustifiedText(
                'تمام آخری مطالعہ',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 4, 6, 12),
                child: JustifiedText(
                  'ابھی کوئی آخری مطالعہ محفوظ نہیں ہوا۔ کوئی کتاب کھولیں گے تو وہ یہاں دکھائی دے گی۔',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            for (final entry in entries)
              LastReadTile(
                library: library,
                entry: entry,
                title: entry.book?.titleUrdu ?? 'آخری مطالعہ',
                showBookName: false,
                // The reader was opened from the sheet, so the sheet goes away
                // with it and the stack stays tidy.
                onOpened: () {
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  onOpened?.call();
                },
              ),
          ],
        ),
      ),
    ),
  );
}
