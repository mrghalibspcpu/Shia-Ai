import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../library_repository.dart';
import 'daily_study_screen.dart';

/// A practical shelf for small utilities, starting with the reading plan.
/// Planned items are clearly marked; tapping one does not pretend it already
/// exists or lead to a dead end.
class XploreXtraScreen extends StatelessWidget {
  const XploreXtraScreen({super.key, required this.library});

  final LibraryRepository library;

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF0A1512),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
          title: const JustifiedText('Xplore Xtra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF123A31), Color(0xFF0B1D19), Color(0xFF07100E)])),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF5E4526), Color(0xFF29231D)]), border: Border.all(color: kGold.withValues(alpha: .5))),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD992), size: 34),
                      SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        JustifiedText('چھوٹے tools، بڑا فائدہ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                        SizedBox(height: 5),
                        JustifiedText('روزمرہ مطالعے اور عبادت کے کام ایک آسان جگہ پر۔', style: TextStyle(fontSize: 12.5, height: 1.6, color: Color(0xFFE5D8C3))),
                      ])),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _XtraCard(
                  icon: Icons.event_available_rounded,
                  title: 'روزانہ مطالعہ',
                  subtitle: 'ایک وقت میں ایک سے زیادہ کتابوں کا ہدف رکھیں — قرآن اور نہج البلاغہ ساتھ ساتھ — ہر کتاب کا آج کا حصہ فوراً کھولیں اور ہر ایک کی پیش رفت و مسلسل دن محفوظ رکھیں۔ مکمل طور پر آف لائن۔',
                  accent: const Color(0xFF42A78B),
                  badge: 'ابھی دستیاب',
                  onTap: () => unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DailyStudyScreen(library: library)))),
                ),
                const SizedBox(height: 12),
                // Features that do not exist yet get no names and no
                // descriptions — one honest Coming Soon container only, so
                // nothing on this page promises what the app cannot do.
                Container(
                  key: const ValueKey<String>('xtra-coming-soon'),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.white.withValues(alpha: .045),
                    border: Border.all(color: Colors.white.withValues(alpha: .14)),
                  ),
                  child: const Column(
                    children: <Widget>[
                      Icon(Icons.hourglass_top_rounded, size: 30, color: Color(0xFFB9CEC4)),
                      SizedBox(height: 10),
                      Text(
                        'Coming Soon',
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      JustifiedText(
                        'عنقریب، ان شاء اللہ',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFFB9CEC4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _XtraCard extends StatelessWidget {
  const _XtraCard({required this.icon, required this.title, required this.subtitle, required this.accent, required this.badge, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: Colors.white.withValues(alpha: .055), border: Border.all(color: accent.withValues(alpha: .48))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(width: 48, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: accent.withValues(alpha: .19)), child: Icon(icon, color: accent, size: 25)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  Row(children: <Widget>[Expanded(child: JustifiedText(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))), const SizedBox(width: 8), Icon(onTap == null ? Icons.lock_clock_rounded : Icons.arrow_back_rounded, size: 17, color: accent)]),
                  const SizedBox(height: 6),
                  JustifiedText(subtitle, style: const TextStyle(fontSize: 12, height: 1.65, color: Color(0xFFB9CEC4))),
                  const SizedBox(height: 8),
                  Align(alignment: AlignmentDirectional.centerStart, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: accent.withValues(alpha: .16)), child: Text(badge, style: TextStyle(fontSize: 10.5, color: Color.lerp(accent, Colors.white, .3), fontWeight: FontWeight.w700)))),
                ])),
              ],
            ),
          ),
        ),
      );
}
