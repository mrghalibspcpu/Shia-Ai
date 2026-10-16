import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../text_utils.dart' show arabicNumerals;

/// A Quran page is a *flow of ayahs*, not an ayah-by-ayah stack of cards.
/// Page/surah boundaries keep even a long surah lazy; [focusRecordId] splits a
/// page immediately before the jump target so jumping still lands on that ayah.
class MushafGroup {
  const MushafGroup(this.verses);

  final List<Passage> verses;
  int get firstRecordId => verses.first.recordId;
}

List<MushafGroup> groupMushafVerses(List<Passage> verses, {int? focusRecordId}) {
  final groups = <MushafGroup>[];
  var current = <Passage>[];
  for (final verse in verses) {
    if (current.isNotEmpty &&
        (current.first.page != verse.page ||
            current.first.containerType != verse.containerType ||
            verse.recordId == focusRecordId)) {
      groups.add(MushafGroup(current));
      current = <Passage>[];
    }
    current.add(verse);
  }
  if (current.isNotEmpty) groups.add(MushafGroup(current));
  return groups;
}

int mushafVerseNumber(Passage verse) {
  final match = RegExp(r'آیت (\d+)').firstMatch(verse.locator);
  return match == null ? verse.recordId : int.tryParse(match.group(1) ?? '') ?? verse.recordId;
}

/// Only the COMPLETE Arabic matn and discreet ayah markers: no translation,
/// commentary, footnotes, per-ayah containers or actions. SelectionArea lives
/// in the reader, around the lazily built groups, so the text is selectable.
class MushafText extends StatelessWidget {
  const MushafText({super.key, required this.group, required this.palette, required this.fontScale});

  final MushafGroup group;
  final ReaderPalette palette;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final first = group.verses.first;
    final surahBegins = mushafVerseNumber(first) == 1 && first.sectionTitle.isNotEmpty;
    final ink = palette.foreground;
    final bodyStyle = TextStyle(
      fontFamily: kArabicFont,
      fontSize: 25 * fontScale,
      height: 1.95,
      color: ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (surahBegins)
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 12),
              child: Text(
                first.sectionTitle,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: kArabicFont,
                  fontSize: 22 * fontScale,
                  color: palette.accent,
                ),
              ),
            ),
          RichText(
            key: ValueKey<String>('mushaf-page-${first.recordId}'),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
            softWrap: true,
            text: TextSpan(
              style: bodyStyle,
              children: <InlineSpan>[
                for (final verse in group.verses)
                  if (verse.arabic.trim().isNotEmpty) ...<InlineSpan>[
                    TextSpan(text: '${verse.arabic.trim().replaceAll(RegExp(r'\s+'), ' ')} '),
                    TextSpan(
                      text: '﴿${arabicNumerals(mushafVerseNumber(verse))}﴾ ',
                      style: bodyStyle.copyWith(color: palette.accent, fontSize: 20 * fontScale),
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
