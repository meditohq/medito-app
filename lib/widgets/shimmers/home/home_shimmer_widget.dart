import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/routes/routes.dart';

import '../widgets/box_shimmer_widget.dart';

const _staggerDelayMs = 280;
const _fadeInDuration = Duration(milliseconds: 350);

class _FadeInSection extends StatefulWidget {
  const _FadeInSection({required this.child});

  final Widget child;

  @override
  State<_FadeInSection> createState() => _FadeInSectionState();
}

class _FadeInSectionState extends State<_FadeInSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _fadeInDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

class HomeShimmerWidget extends ConsumerStatefulWidget {
  const HomeShimmerWidget({super.key});

  @override
  ConsumerState<HomeShimmerWidget> createState() => _HomeShimmerWidgetState();
}

class _HomeShimmerWidgetState extends ConsumerState<HomeShimmerWidget> {
  int _visibleSections = 0;
  Timer? _timer;

  static const _totalSections = 5;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: _staggerDelayMs), () {
      if (!mounted) return;
      setState(() {
        if (_visibleSections < _totalSections) {
          _visibleSections++;
          _scheduleNext();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  top: 8, bottom: 4, left: 16, right: 16),
              child: _downloadsButton(context, ref),
            ),
            if (_visibleSections >= 1)
              _FadeInSection(child: _header(context)),
            if (_visibleSections >= 2)
              _FadeInSection(child: _upNextCard(context)),
            if (_visibleSections >= 3)
              _FadeInSection(child: _shortcutsGrid(context)),
            if (_visibleSections >= 4)
              _FadeInSection(child: _featuredHeading(context)),
            if (_visibleSections >= 5)
              _FadeInSection(child: _featuredCards(context)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _downloadsButton(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => handleNavigation(
          TypeConstants.flow,
          [TypeConstants.downloads],
          context,
          ref: ref,
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
          textStyle: theme.textTheme.bodySmall,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.goToDownloads),
            Icon(Icons.chevron_right, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: BoxShimmerWidget(
              height: 24,
              width: 160,
              borderRadius: 12,
            ),
          ),
          BoxShimmerWidget(
            height: 40,
            width: 40,
            borderRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _upNextCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final backgroundColor = isDark
              ? ColorConstants.greyIsTheNewGrey
              : ColorConstants.lightCard;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          BoxShimmerWidget(
                            height: 12,
                            width: 60,
                            borderRadius: 6,
                          ),
                          SizedBox(width: 8),
                          BoxShimmerWidget(
                            height: 12,
                            width: 50,
                            borderRadius: 6,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const BoxShimmerWidget(
                        height: 22,
                        width: 180,
                        borderRadius: 8,
                      ),
                      const SizedBox(height: 6),
                      const BoxShimmerWidget(
                        height: 14,
                        width: 220,
                        borderRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const BoxShimmerWidget(
                  height: 48,
                  width: 48,
                  borderRadius: 24,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _shortcutsGrid(BuildContext context) {
    var size = MediaQuery.of(context).size;
    const columns = 4;
    const horizontalPadding = 16.0;
    const spacing = 20.0;
    const runSpacing = 12.0;
    final totalSpacing = (columns - 1) * spacing;
    final totalPadding = horizontalPadding * 2;
    final itemSize = (size.width - totalPadding - totalSpacing) / columns;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: List.generate(
          8,
          (index) => _shortcutItem(context, itemSize),
        ),
      ),
    );
  }

  Widget _shortcutItem(BuildContext context, double size) {
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final backgroundColor = isDark
                  ? ColorConstants.greyIsTheNewGrey
                  : ColorConstants.lightCard;

              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const BoxShimmerWidget(
            height: 12,
            width: 50,
            borderRadius: 6,
          ),
        ],
      ),
    );
  }

  Widget _featuredHeading(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: BoxShimmerWidget(
          height: 20,
          width: 100,
          borderRadius: 8,
        ),
      ),
    );
  }

  Widget _featuredCards(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _featuredCard(context),
        ),
      ),
    );
  }

  Widget _featuredCard(BuildContext context) {
    const cardWidth = 220.0;

    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final backgroundColor = isDark
            ? ColorConstants.greyIsTheNewGrey
            : ColorConstants.lightCard;

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: cardWidth,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const BoxShimmerWidget(
                  height: 100,
                  width: cardWidth,
                  borderRadius: 0,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BoxShimmerWidget(
                      height: 18,
                      width: 140,
                      borderRadius: 8,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: BoxShimmerWidget(
                    height: 14,
                    width: 160,
                    borderRadius: 6,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: BoxShimmerWidget(
                    height: 40,
                    width: 120,
                    borderRadius: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
