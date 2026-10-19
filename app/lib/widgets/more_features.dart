import 'package:flutter/material.dart';

/// One tile on the **Xplore** screen.
///
/// The screen is data-driven: a new extra is one more [MoreFeature] in the list
/// the app passes, and nothing else changes.
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
