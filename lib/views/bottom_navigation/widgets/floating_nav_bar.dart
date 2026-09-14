import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/widgets/medito_icon.dart';

class FloatingNavItem {
  const FloatingNavItem({required this.icon, required this.label});

  /// SVG asset name, see [MeditoIcons].
  final String icon;
  final String label;
}

/// The detached round button beside the pill. Tapping it expands the button
/// into a full-width field ([FloatingNavBar.expanded]) while the pill folds
/// away, the way the iOS 26 tab bar search works.
class FloatingNavAction {
  const FloatingNavAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
}

/// Frosted pill that floats above the page content instead of a full-width
/// bar. The selected item expands into a tinted chip with its label; the
/// others are icon-only. Pair with `Scaffold(extendBody: true)` so content
/// scrolls underneath and the blur has something to blur.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.action,
    this.expanded = false,
    this.expandedChild,
  });

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final FloatingNavAction? action;

  /// When true the pill collapses and the action capsule stretches across
  /// the bar showing [expandedChild] (the search field).
  final bool expanded;
  final Widget? expandedChild;

  static const pillRadius = 100.0;
  static const capsuleSize = 58.0;
  static const _blurSigma = 24.0;
  static const _hairline = 0.5;
  static const _duration = Duration(milliseconds: 260);
  static const _morphDuration = Duration(milliseconds: 340);
  static const _morphCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final pill = _Glass(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              _NavChip(
                item: items[i],
                selected: i == selectedIndex,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(i);
                },
              ),
          ],
        ),
      ),
    );

    // A Row, not Center: the Scaffold offers this slot the full screen height
    // as its max constraint and Center would expand to fill it.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: padding12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: padding24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Folds to zero width (and fades) while search is expanded.
                ClipRect(
                  child: AnimatedAlign(
                    duration: _morphDuration,
                    curve: _morphCurve,
                    alignment: Alignment.centerRight,
                    // heightFactor keeps the Align hugging the pill; without
                    // it the Align fills the slot's full-screen max height.
                    heightFactor: 1,
                    widthFactor: expanded ? 0 : 1,
                    child: AnimatedOpacity(
                      duration: _duration,
                      opacity: expanded ? 0 : 1,
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: action != null ? padding12 : 0,
                        ),
                        child: pill,
                      ),
                    ),
                  ),
                ),
                if (action != null)
                  _ActionCapsule(
                    action: action!,
                    expanded: expanded,
                    // The glass hairline sits outside the animated box.
                    expandedWidth: constraints.maxWidth - 2 * _hairline,
                    child: expandedChild,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Frosted, hairlined, softly shadowed capsule shared by the pill and the
/// action capsule.
class _Glass extends StatelessWidget {
  const _Glass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.cardColor.withValues(alpha: isDark ? 0.82 : 0.88);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FloatingNavBar.pillRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FloatingNavBar.pillRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: FloatingNavBar._blurSigma,
            sigmaY: FloatingNavBar._blurSigma,
          ),
          child: HomeGradientBorder(
            backgroundColor: surface,
            borderRadius: FloatingNavBar.pillRadius,
            borderWidth: FloatingNavBar._hairline,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Round icon button that stretches into a full-width capsule holding
/// [child] when [expanded].
class _ActionCapsule extends StatelessWidget {
  const _ActionCapsule({
    required this.action,
    required this.expanded,
    required this.expandedWidth,
    this.child,
  });

  final FloatingNavAction action;
  final bool expanded;
  final double expandedWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return _Glass(
      child: AnimatedContainer(
        duration: FloatingNavBar._morphDuration,
        curve: FloatingNavBar._morphCurve,
        width: expanded ? expandedWidth : FloatingNavBar.capsuleSize,
        height: FloatingNavBar.capsuleSize,
        child: AnimatedSwitcher(
          duration: FloatingNavBar._duration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: expanded && child != null
              ? KeyedSubtree(key: const ValueKey('expanded'), child: child!)
              : Semantics(
                  key: const ValueKey('collapsed'),
                  button: true,
                  label: action.label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      action.onTap();
                    },
                    child: Center(
                      child: ExcludeSemantics(
                        child: MeditoIcon(
                          assetName: action.icon,
                          color: onSurface,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.brandPurple;
    final iconColor = selected ? accent : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: FloatingNavBar._duration,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? padding16 : padding14,
              vertical: padding12,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(FloatingNavBar.pillRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MeditoIcon(assetName: item.icon, color: iconColor, size: 22),
                AnimatedSize(
                  duration: FloatingNavBar._duration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            item.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                              height: 1.2,
                              color: accent,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
