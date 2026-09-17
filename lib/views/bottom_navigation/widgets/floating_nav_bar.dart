import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/widgets/medito_icon.dart';

class FloatingNavItem {
  const FloatingNavItem({required this.icon, required this.label});

  /// SVG asset name, see [MeditoIcons].
  final String icon;
  final String label;
}

/// A bar item that is not a tab (search): tapping it opens the in-place
/// search field ([FloatingNavBar.expanded]).
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

/// Docked, full-width navigation bar anchored to the bottom edge. A frosted,
/// hairlined bar with the tabs (and the search action) spread evenly across
/// it. When [expanded] the row is replaced by the search field
/// ([expandedChild]) and a Cancel button, and the whole bar lifts above the
/// keyboard. Pair with `Scaffold(extendBody: true)` so content scrolls
/// beneath the translucent bar.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.action,
    this.actionIndex,
    this.expanded = false,
    this.expandedChild,
    this.cancelLabel,
    this.onCancel,
  });

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final FloatingNavAction? action;

  /// Where the [action] (search) sits among the tabs; appended at the end
  /// when null.
  final int? actionIndex;

  /// When true the tab row is replaced by [expandedChild] (the search field)
  /// and a Cancel button that calls [onCancel].
  final bool expanded;
  final Widget? expandedChild;
  final String? cancelLabel;
  final VoidCallback? onCancel;

  static const _barHeight = 60.0;
  static const _hairline = 0.5;
  static const _keyboardDuration = Duration(milliseconds: 180);

  /// Colours for everything drawn on the bar; see [GlassColors].
  static GlassColors colorsOf(BuildContext context) => GlassColors.of(context);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);

    // The Scaffold keeps its bottomNavigationBar slot pinned to the screen
    // edge whatever the keyboard does, so when the search field has focus the
    // bar would sit under the keyboard. Lift the whole bar by the keyboard
    // inset ourselves. Animated because Android reports the inset in one step
    // while iOS updates it per frame.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final barFill = isDark(context) ? const Color(0xFF1A1A1A) : Colors.white;

    return AnimatedPadding(
      duration: _keyboardDuration,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: barFill,
          border: Border(
            top: BorderSide(color: colors.rim, width: _hairline),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: _barHeight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: expanded && expandedChild != null
                  ? _searchRow(context, colors)
                  : _tabsRow(colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabsRow(GlassColors colors) {
    final tabs = <Widget>[
      for (var i = 0; i < items.length; i++)
        Expanded(
          child: _NavTab(
            item: items[i],
            selected: i == selectedIndex,
            colors: colors,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(i);
            },
          ),
        ),
    ];
    if (action != null) {
      final at = (actionIndex ?? tabs.length).clamp(0, tabs.length);
      tabs.insert(
        at,
        Expanded(
          child: _NavTab(
            item: FloatingNavItem(icon: action!.icon, label: action!.label),
            selected: false,
            colors: colors,
            onTap: () {
              HapticFeedback.selectionClick();
              action!.onTap();
            },
          ),
        ),
      );
    }
    return Row(key: const ValueKey('tabs'), children: tabs);
  }

  Widget _searchRow(BuildContext context, GlassColors colors) {
    return Padding(
      key: const ValueKey('search'),
      padding: const EdgeInsets.only(left: padding16, right: padding8),
      child: Row(
        children: [
          Expanded(child: expandedChild!),
          if (cancelLabel != null && onCancel != null)
            TextButton(
              onPressed: onCancel,
              child: Text(
                cancelLabel!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  height: 1.2,
                  color: colors.foreground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Colours for the navigation bar and whatever sits on it. Kept in one place
/// so the bar and the search field agree.
///
/// Monochrome, after tickets.knit.amsterdam: near-black bar with off-white
/// text and a white-10% rim in dark mode, white bar with near-black text and
/// a black-10% rim in light mode. The selected tab is the full-contrast
/// foreground; unselected tabs are muted.
class GlassColors {
  const GlassColors({
    required this.fill,
    required this.rim,
    required this.shadow,
    required this.foreground,
    required this.mutedForeground,
    required this.selectedForeground,
    required this.selectedBackground,
  });

  factory GlassColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return GlassColors(
        fill: const Color(0xFF1A1A1A).withValues(alpha: 0.86),
        rim: Colors.white.withValues(alpha: 0.10),
        shadow: Colors.black.withValues(alpha: 0.55),
        foreground: const Color(0xFFFAFAFA),
        mutedForeground: const Color(0xFFA1A1A1),
        selectedForeground: const Color(0xFF171717),
        selectedBackground: const Color(0xFFE5E5E5),
      );
    }
    return GlassColors(
      fill: Colors.white.withValues(alpha: 0.92),
      rim: Colors.black.withValues(alpha: 0.10),
      shadow: Colors.black.withValues(alpha: 0.14),
      foreground: const Color(0xFF0A0A0A),
      mutedForeground: const Color(0xFF737373),
      selectedForeground: const Color(0xFFFAFAFA),
      selectedBackground: const Color(0xFF171717),
    );
  }

  final Color fill;
  final Color rim;
  final Color shadow;
  final Color foreground;
  final Color mutedForeground;
  final Color selectedForeground;
  final Color selectedBackground;
}

/// A standard tab: icon over label, full-height, filling its slot. Selected
/// tabs use the full-contrast foreground; the rest are muted.
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final GlassColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? colors.foreground : colors.mutedForeground;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              MeditoIcon(assetName: item.icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: dmSans,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.1,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
