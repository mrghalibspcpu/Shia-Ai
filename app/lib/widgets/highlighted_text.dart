import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app_theme.dart' show kArabicFont, kUrduFont, kGold;
import '../text_utils.dart' show searchMatchRanges;

/// Shared search/reader typography. No per-word SelectableText objects: the
/// reader's SelectionArea handles selection without eager paragraph layouts.
class HighlightedText extends StatefulWidget {
  const HighlightedText(this.text, {super.key, required this.query, this.style,
    this.maxLines, this.arabic = false, this.scrollToMatch = false});
  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final bool arabic;
  final bool scrollToMatch;

  @override
  State<HighlightedText> createState() => _HighlightedTextState();
}

class _HighlightedTextState extends State<HighlightedText> {
  final GlobalKey _textKey = GlobalKey();
  late List<({int start, int end})> _ranges;

  @override
  void initState() { super.initState(); _update(); }

  @override
  void didUpdateWidget(covariant HighlightedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text || widget.query != oldWidget.query ||
        widget.scrollToMatch != oldWidget.scrollToMatch) _update();
  }

  // Text adds selection/MouseRegion wrappers inside SelectionArea, so its
  // first render object is not necessarily the paragraph itself.
  RenderParagraph? _findParagraph(RenderObject? object) {
    if (object is RenderParagraph) return object;
    RenderParagraph? found;
    object?.visitChildren((child) { found ??= _findParagraph(child); });
    return found;
  }

  void _update() {
    _ranges = searchMatchRanges(widget.text, widget.query);
    if (!widget.scrollToMatch || _ranges.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _textKey.currentContext;
      final render = _findParagraph(context?.findRenderObject());
      if (context == null || render == null || !render.attached) return;
      final match = _ranges.first;
      final boxes = render.getBoxesForSelection(TextSelection(baseOffset: match.start, extentOffset: match.end));
      final scrollable = Scrollable.maybeOf(context);
      if (boxes.isNotEmpty && scrollable != null) {
        final viewport = RenderAbstractViewport.maybeOf(render);
        if (viewport == null) return;
        final position = scrollable.position;
        final offset = viewport.getOffsetToReveal(render, 0.15, rect: boxes.first.toRect()).offset;
        position.jumpTo(offset.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontFamily: widget.arabic ? kArabicFont : kUrduFont,
      fontSize: widget.arabic ? 22 : 19, height: widget.arabic ? 1.8 : 1.6)
        .merge(widget.style).copyWith(letterSpacing: widget.arabic ? 0 : widget.style?.letterSpacing);
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in _ranges) {
      if (match.start > start) spans.add(TextSpan(text: widget.text.substring(start, match.start)));
      spans.add(TextSpan(text: widget.text.substring(match.start, match.end),
        style: TextStyle(backgroundColor: kGold.withValues(alpha: 0.4), fontWeight: FontWeight.w700)));
      start = match.end;
    }
    if (start < widget.text.length) spans.add(TextSpan(text: widget.text.substring(start)));
    return Text.rich(TextSpan(style: base, children: spans), key: _textKey,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
      textAlign: TextAlign.justify, textDirection: TextDirection.rtl);
  }
}
