import 'package:flutter/material.dart';

import '../app_theme.dart';

/// One item in the **مزید** sheet.
///
/// The sheet is a plain list: a new extra is one more [MoreFeature] in the list
/// the caller passes, and nothing else changes.
class MoreFeature {
  const MoreFeature({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// Runs after the sheet has closed, so the feature never opens underneath it.
  final VoidCallback onOpen;
}

/// Shows the **Xplore** sheet: every feature that is not one of the five buttons
/// of the bottom panel. Tapping an item closes the sheet first and then runs
/// that item's action.
Future<void> showMoreFeaturesSheet(
  BuildContext context, {
  required List<MoreFeature> features,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 0, 6, 12),
              child: JustifiedText(
                'Xplore — ایکسپلور',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
            // The list is longer than the sheet on a short phone, and a large
            // system font makes it longer still: it scrolls inside whatever
            // height is left.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final feature in features)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: feature.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(feature.icon, color: feature.color),
                          ),
                          title: JustifiedText(
                            feature.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: JustifiedText(feature.subtitle, maxLines: 2),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            feature.onOpen();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
