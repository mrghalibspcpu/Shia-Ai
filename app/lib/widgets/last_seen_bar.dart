import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import '../models.dart';
import 'resume_card.dart';

/// Every saved position in one slim bar.
///
/// The home screen used to stack one full-width card per book under
/// **ہر کتاب کا آخری مقام**, which pushed the actual library below the fold.
/// The same information now lives in a single 54 dp strip: the label stays put
/// and the books scroll through it horizontally, most recent first (nearest the
/// right edge, where an Urdu reader starts). Each chip shows the book and when
/// it was left on its first line and the locator on its second, so nothing is
/// squeezed. Tapping a chip re-opens that exact spot; tapping the label opens
/// the complete history, every entry as a full card.
///
/// The widget is deliberately cheap: the caller hands over an already-loaded
/// list (one `SharedPreferences` read for the whole bar, never one per chip),
/// and the chips are built lazily by [ListView.builder] so a long reading
/// history costs nothing on first paint.
class LastSeenBar extends StatelessWidget {
  const LastSeenBar({
    super.key,
    required this.library,
    required this.entries,
    this.onOpened,
  });

  /// Height of the strip — thin enough to leave the library in view.
  static const double barHeight = 54;

  final LibraryRepository library;

  /// Saved positions, most recently read first. Renders nothing when empty.
  final List<LastReadEntry> entries;

  /// Called after a chip (or the sheet) re-opens a book, so the caller can
  /// reload the list.
  final VoidCallback? onOpened;

  void _open(BuildContext context, LastReadEntry entry) {
    openLastRead(context, library, entry).then((_) => onOpened?.call());
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: barHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Tooltip(
              message: 'تمام آخری مطالعہ کھولیں',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showAll(context),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 17, color: scheme.primary),
                      const SizedBox(width: 5),
                      Text(
                        'آخری مطالعہ',
                        style: TextStyle(
                          fontFamily: kUrduFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down_rounded, size: 19, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 26, color: scheme.outlineVariant.withValues(alpha: 0.6)),
            Expanded(
              // Index 0 is the newest position and a horizontal list in an RTL
              // context starts at the right edge — which is exactly where a
              // reader looks first, so the list is deliberately NOT reversed.
              child: ListView.separated(
                key: const PageStorageKey('last-seen-strip'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.only(start: 10, end: 8),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _LastSeenChip(
                  entry: entries[index],
                  latest: index == 0,
                  onTap: () => _open(context, entries[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAll(BuildContext context) {
    return showModalBottomSheet<void>(
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
              for (final entry in entries)
                LastReadTile(
                  library: library,
                  entry: entry,
                  title: entry.book?.titleUrdu ?? 'آخری مطالعہ',
                  showBookName: false,
                  // Closing the sheet as the reader returns keeps the stack
                  // tidy: the reader was opened from the sheet, so the sheet
                  // goes away with it.
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
}

/// One book inside the strip: name, where the reader stopped, and when.
class _LastSeenChip extends StatelessWidget {
  const _LastSeenChip({required this.entry, required this.latest, required this.onTap});

  final LastReadEntry entry;

  /// The newest position — the one **جاری رکھیں** would reopen — is filled so
  /// it stands out without needing a second card.
  final bool latest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final book = entry.book;
    if (book == null) return const SizedBox.shrink();
    final time = entry.timeLabel.trim();
    final detail = entry.referenceOrTitle;
    final titleColor = latest ? scheme.onPrimary : scheme.onSurface;
    final detailColor = latest
        ? scheme.onPrimary.withValues(alpha: 0.82)
        : scheme.onSurfaceVariant;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Material(
          color: latest
              ? scheme.primary
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: latest
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    time.isEmpty ? book.titleUrdu : '${book.titleUrdu} · $time',
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kUrduFont,
                      fontSize: 12.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kUrduFont,
                        fontSize: 11.5,
                        height: 1.15,
                        color: detailColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
