import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models.dart';
import 'reader_kit.dart';

/// The home collection's emerald / teal / blue / plum follows it into reading.
Color readerCollectionColor(BookDefinition book) => switch (book.source) {
      CorpusSource.quran => const Color(0xFF19654C),
      CorpusSource.hadith => const Color(0xFF146B70),
      CorpusSource.dua || CorpusSource.sahifa => const Color(0xFF135C78),
      CorpusSource.balagha => const Color(0xFF23563F),
      CorpusSource.fatwa => const Color(0xFF4A2260),
      // Deep aubergine, distinct from the fatawa plum and the hadith teal.
      CorpusSource.encyclopedia => const Color(0xFF4B3B78),
    };

IconData _collectionIcon(BookDefinition book) => switch (book.source) {
      CorpusSource.quran => Icons.menu_book_rounded,
      CorpusSource.hadith => Icons.format_quote_rounded,
      CorpusSource.dua || CorpusSource.sahifa => Icons.mosque_rounded,
      CorpusSource.balagha => Icons.auto_stories_rounded,
      CorpusSource.fatwa => Icons.gavel_rounded,
      CorpusSource.encyclopedia => Icons.travel_explore_rounded,
    };

/// Shared, quiet chrome for ALL readers. Only the presentation is shared: each
/// screen still owns its lazy list, scroll keys, search target and saved place.
class ReaderScaffold extends StatelessWidget {
  const ReaderScaffold({
    super.key,
    required this.book,
    required this.title,
    required this.preferences,
    required this.onPreferencesChanged,
    required this.body,
    this.subtitle,
    this.actions = const <Widget>[],
    this.headerAction,
    this.showAppearanceLabel = false,
    this.fullScreen = false,
    this.overlay,
  });

  final BookDefinition book;
  final String title;
  final String? subtitle;
  final ReaderPreferences preferences;
  final ValueChanged<ReaderPreferences> onPreferencesChanged;
  final List<Widget> actions;
  final Widget? headerAction;
  final bool showAppearanceLabel;

  /// When true the app bar and its banner are hidden: the صفحہ is the whole
  /// screen. The caller shows the small display bar (with the exit button)
  /// through [overlay].
  final bool fullScreen;

  /// A floating control strip drawn over the متن (see `ReaderDisplayMode`).
  final Widget? overlay;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final palette = preferences.palette;
    final overlayStyle = (palette.isNight ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: palette.background);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: fullScreen ? null : AppBar(
          backgroundColor: palette.background,
          foregroundColor: palette.foreground,
          systemOverlayStyle: overlayStyle,
          centerTitle: true,
          title: Text(
            book.titleUrdu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: palette.accent),
          ),
          actions: <Widget>[
            ...actions,
            ReaderControls(
              preferences: preferences,
              onChanged: onPreferencesChanged,
              showLabel: showAppearanceLabel,
            ),
            const SizedBox(width: 6),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(headerAction == null ? 102 : 146),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _ReaderBanner(
                        book: book,
                        title: title,
                        subtitle: subtitle ?? book.source.label,
                      ),
                      if (headerAction != null)
                        SizedBox(height: 44, child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: headerAction,
                        )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: fullScreen,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: body),
                  if (overlay != null) Positioned.fill(child: overlay!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderBanner extends StatelessWidget {
  const _ReaderBanner({required this.book, required this.title, required this.subtitle});

  final BookDefinition book;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = readerCollectionColor(book);
    return Container(
      key: const ValueKey<String>('reader-banner'),
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[color, Color.lerp(color, Colors.black, 0.48)!],
        ),
        border: Border.all(color: kGold, width: 1.1),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kGold.withValues(alpha: 0.65)),
            ),
            child: Icon(_collectionIcon(book), size: 24, color: const Color(0xFFEBD5A8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width.clamp(240.0, 700.0).toDouble() - 110,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: kUrduFont,
                        fontSize: 20,
                        height: 1.3,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 12, height: 1.3, color: Color(0xFFEBD5A8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
