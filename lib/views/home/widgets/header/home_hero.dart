import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/widgets/network_image_widget.dart';

import '../stats/streak_circle.dart';

/// How far the hero image bleeds above its box. At rest this sits above the
/// viewport (clipped); on pull-to-refresh the scroll view offsets down and
/// this pre-painted band fills the gap with more image instead of the page
/// background.
const double _kOverscrollBleed = 260.0;

/// Cover of the pinned pack, or null while it loads or has none. Shared by
/// [HomeHero] and the home list, which hands its first section to the hero
/// whenever there is an image to lay it over.
final homeHeroCoverProvider = Provider.autoDispose<String?>((ref) {
  final cover = ref
      .watch(upNextProvider)
      .whenOrNull(data: (data) => data.pack.coverUrl);
  return (cover == null || cover.isEmpty) ? null : cover;
});

/// Home's top section: the pinned pack's cover as a full-bleed image that
/// runs under the status bar, with the streak pill top right.
///
/// With a [child] (Your Path or the quote, when the user put it first) the
/// image takes at least half the screen and the section is laid over its
/// lower part. Without one the image is a short banner behind the pill only,
/// and the first section renders below it on the page as usual. With no
/// cover at all it is just the pill row.
class HomeHero extends ConsumerWidget {
  const HomeHero({
    super.key,
    required this.onStatsButtonTap,
    this.child,
    this.announcement,
  });

  final VoidCallback onStatsButtonTap;

  /// The section laid over the image. Rendered inside an on-image theme:
  /// white text, dark translucent cards, no page-coloured fades.
  final Widget? child;

  /// Announcement card, shown above [child] over the image (below the streak
  /// pill). Only used when there is an overlaid section; in banner mode the
  /// home list places it under the hero instead. Collapses itself when there
  /// is nothing to show.
  final Widget? announcement;

  /// Space reserved for the status bar and streak pill above [child].
  static const _headerReserve = 72.0;

  /// Banner mode: pill row plus room for the fade into the page.
  static const _bannerHeight = 132.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final coverUrl = ref.watch(homeHeroCoverProvider);

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        padding16,
        topInset + (size.width >= 600 ? 24 : padding12),
        size.width >= 600 ? 32 : padding16,
        0,
      ),
      // Just the streak pill, top right; the section title carries the hero.
      child: Align(
        alignment: Alignment.centerRight,
        child: StreakCircle(onTap: onStatsButtonTap),
      ),
    );

    if (coverUrl == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: header,
        ),
      );
    }

    final overlay = child != null;
    // Overlay covers sit a little under half the screen: enough for a large
    // image, without leaving a big empty band above the section on sparse
    // covers.
    final minHeight = overlay
        ? (size.height * 0.42).clamp(340.0, 420.0)
        : topInset + _bannerHeight;

    // Status bar glyphs follow the theme: the top of the image is darkened
    // in dark mode and whitened in light mode, so the tab scaffold's own
    // style already reads on both.
    return SliverToBoxAdapter(
      child: Stack(
        // The backdrop image bleeds above the box; don't clip it here.
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: _HeroBackdrop(coverUrl: coverUrl, banner: !overlay),
          ),
          // Floor for the stack height: with an overlay a short section
          // still gets a big image; as a banner this is the whole height.
          SizedBox(height: minHeight, width: double.infinity),
          if (overlay)
            Padding(
              padding: EdgeInsets.only(
                top: topInset + _headerReserve,
                bottom: padding8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Own colours, so kept outside the on-image theme.
                  ?announcement,
                  _OnImageTheme(child: child!),
                ],
              ),
            ),
          Positioned(top: 0, left: 0, right: 0, child: header),
        ],
      ),
    );
  }
}

/// The cover plus its scrims, tinted toward the page colour at both ends:
/// near-black in dark mode (white text on it), white in light mode (dark text
/// on it). The top carries the status bar and streak pill, the bottom the
/// section, and the image dissolves into the page instead of a dark band
/// meeting a white one. A short seam finishes the edge.
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.coverUrl, required this.banner});

  final String coverUrl;

  /// Short banner behind the pill only: one even scrim, shorter seam.
  final bool banner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = theme.scaffoldBackgroundColor;
    final isDark = theme.brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;
    // What both ends fade toward: the page itself.
    final base = isDark ? Colors.black : page;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Image AND the top darkening bleed above the box together, so a
        // pull-to-refresh reveals more of the darkened image with no seam
        // where a box-anchored scrim would have ended.
        Positioned(
          top: -_kOverscrollBleed,
          left: 0,
          right: 0,
          bottom: 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetworkImageWidget(url: coverUrl, shouldCache: true),
              // Pixel-anchored to the top of the bleed: dark across the whole
              // bleed and the status-bar/pill area, then faded to nothing.
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: _kOverscrollBleed + topInset + 130,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.72, 1.0],
                        colors: [
                          base.withValues(alpha: 0.55),
                          base.withValues(alpha: 0.4),
                          base.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Box-anchored lower scrim.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: banner
                // Banner mode: the whole lower half eases the image into the
                // page over a long, soft ramp rather than a short hard seam.
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.3, 0.55, 0.78, 1.0],
                    colors: [
                      page.withValues(alpha: 0.0),
                      page.withValues(alpha: 0.12),
                      page.withValues(alpha: 0.4),
                      page.withValues(alpha: 0.78),
                      page,
                    ],
                  )
                // Overlay mode: transparent at the top (the bleed layer
                // handles that), darkening toward the section.
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.45, 1.0],
                    colors: [
                      base.withValues(alpha: 0.0),
                      base.withValues(alpha: isDark ? 0.5 : 0.6),
                      base.withValues(alpha: isDark ? 0.8 : 0.96),
                    ],
                  ),
          ),
        ),
        // Overlay mode keeps a short seam so the image never ends on a hard
        // edge; banner mode's full-height ramp already reaches the page.
        if (!banner)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [page.withValues(alpha: 0), page],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Re-themes a home section for life on the lower half of the hero, which
/// fades toward the page colour: white text and near-opaque dark cards in
/// dark mode, near-black text and near-opaque white cards in light mode. The
/// page colour is made transparent so edge fades (the carousel's) disappear
/// instead of drawing bars across the image.
class _OnImageTheme extends StatelessWidget {
  const _OnImageTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF0A0A0A);
    final card = isDark
        ? const Color(0xFF1A1A1A).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.86);
    return Theme(
      data: theme.copyWith(
        cardColor: card,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: theme.colorScheme.copyWith(
          onSurface: foreground,
          onSurfaceVariant: foreground.withValues(alpha: 0.75),
        ),
        textTheme: theme.textTheme.apply(
          bodyColor: foreground,
          displayColor: foreground,
        ),
      ),
      child: child,
    );
  }
}
