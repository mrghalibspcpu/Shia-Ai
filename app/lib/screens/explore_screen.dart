import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/more_features.dart';

/// The **Xplore** screen.
///
/// It is deliberately a *screen*, not a bottom sheet: 1.20 opened a plain list
/// from the dock, which felt like a settings dialog and looked nothing like the
/// rest of the app. This page borrows the home screen's language — a deep
/// gradient behind translucent cards, a large Urdu title, coloured medallions
/// and a gold hairline — while staying clearly different: **one** hero card for
/// the newest shelf, then a two-column grid of everything else, no prayer strip,
/// no dial.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, required this.features});

  final List<MoreFeature> features;

  /// The first entry is the hero (نئی کتابیں); the rest fill the grid.
  MoreFeature? get _hero => features.isEmpty ? null : features.first;
  List<MoreFeature> get _rest => features.length <= 1 ? const <MoreFeature>[] : features.sublist(1);

  @override
  Widget build(BuildContext context) {
    final hero = _hero;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0A1512),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        title: const JustifiedText(
          'ایکسپلور',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[Color(0xFF123A31), Color(0xFF0B1D19), Color(0xFF07100E)],
            stops: <double>[0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: <Widget>[
              const _ExploreHeader(),
              const SizedBox(height: 18),
              if (hero != null) _HeroCard(feature: hero),
              if (_rest.isNotEmpty) ...<Widget>[
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: JustifiedText(
                    'مزید خصوصیات',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFBFD8CC)),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 520 ? 3 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rest.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.86,
                      ),
                      itemBuilder: (context, index) => _FeatureTile(feature: _rest[index]),
                    );
                  },
                ),
              ],
              const SizedBox(height: 18),
              const _ExploreFootnote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFF1E4F42), Color(0xFF14332C)],
        ),
        border: Border.all(color: kGold.withValues(alpha: 0.42), width: 1.1),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFC59A50), Color(0xFF8E6A2C)],
                  ),
                ),
                child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF1B1206), size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    JustifiedText(
                      'Xplore',
                      style: TextStyle(
                        fontFamily: kDigitFont,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    JustifiedText(
                      'وہ سب کچھ جو پانچ بٹنوں سے باہر ہے',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFFB6D2C5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: kGold.withValues(alpha: 0.35)),
          const SizedBox(height: 12),
          const JustifiedText(
            'کتابیں، اوقات، تسبیح، رویتِ ہلال اور تقویم — ایک ہی جگہ، اسی پڑھنے کے انداز میں۔',
            style: TextStyle(fontSize: 13, height: 1.7, color: Color(0xFFD3E6DC)),
          ),
        ],
      ),
    );
  }
}

/// The newest shelf, full width: a photograph-free gradient card with the icon
/// on one side and the promise of the shelf on the other.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.feature});

  final MoreFeature feature;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: feature.onOpen,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[
                Color.lerp(feature.color, Colors.white, 0.16)!,
                Color.lerp(feature.color, Colors.black, 0.34)!,
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  child: Icon(feature.icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      JustifiedText(
                        feature.title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 5),
                      JustifiedText(
                        feature.subtitle,
                        style: TextStyle(fontSize: 12.5, height: 1.6, color: Colors.white.withValues(alpha: 0.86)),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'کھولیں',
                            style: TextStyle(
                              fontFamily: kUrduFont,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_back_rounded, size: 17, color: Colors.white.withValues(alpha: 0.95)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});

  final MoreFeature feature;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: feature.onOpen,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.09),
                Colors.white.withValues(alpha: 0.035),
              ],
            ),
            border: Border.all(color: feature.color.withValues(alpha: 0.55), width: 1.1),
            boxShadow: <BoxShadow>[
              BoxShadow(color: feature.color.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 14, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color.lerp(feature.color, Colors.white, 0.30)!,
                          feature.color,
                        ],
                      ),
                    ),
                    child: Icon(feature.icon, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(height: 12),
                JustifiedText(
                  feature.title,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
                  maxLines: 2,
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: JustifiedText(
                    feature.subtitle,
                    style: const TextStyle(fontSize: 11, height: 1.55, color: Color(0xFFAEC9BD)),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Container(height: 1.4, width: 26, color: kGold.withValues(alpha: 0.85)),
                    const Spacer(),
                    const Icon(Icons.chevron_left, size: 18, color: Color(0xFFBFD8CC)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreFootnote extends StatelessWidget {
  const _ExploreFootnote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: JustifiedText(
        'ہر خصوصیت اسی لائبریری اور اسی مقام کے حساب سے چلتی ہے — کوئی الگ اکاؤنٹ یا '
        'لاگ اِن درکار نہیں۔',
        style: TextStyle(fontSize: 11.5, height: 1.7, color: Color(0xFF8FAA9E)),
      ),
    );
  }
}
