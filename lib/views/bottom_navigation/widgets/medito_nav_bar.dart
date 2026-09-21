import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/widgets/medito_icon.dart';

class MeditoNavItem {
  const MeditoNavItem({required this.icon, required this.label});

  /// SVG asset name, see [MeditoIcons].
  final String icon;
  final String label;
}

/// A bar item that is not a tab (search): tapping it opens search.
class MeditoNavAction {
  const MeditoNavAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
}

/// Docked, full-width navigation bar anchored to the bottom edge: a solid bar
/// with a top hairline and the tabs (plus the search action) spread evenly
/// across it, each icon over label. Search opens a floating field above the
/// keyboard rather than living in this bar.
class MeditoNavBar extends StatelessWidget {
  const MeditoNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.action,
    this.actionIndex,
  });

  final List<MeditoNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final MeditoNavAction? action;

  /// Where the [action] (search) sits among the tabs; appended at the end
  /// when null.
  final int? actionIndex;

  static const _barHeight = 60.0;
  static const _hairline = 0.5;

  /// Colours for the bar and the floating search field; see [GlassColors].
  static GlassColors colorsOf(BuildContext context) => GlassColors.of(context);

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barFill = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: barFill,
        border: Border(
          top: BorderSide(color: colors.rim, width: _hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(height: _barHeight, child: _tabsRow(colors)),
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
            item: MeditoNavItem(icon: action!.icon, label: action!.label),
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
    return Row(children: tabs);
  }
}

/// Colours for the navigation bar and the floating search field. Kept in one
/// place so they agree.
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
  });

  factory GlassColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return GlassColors(
        fill: const Color(0xFF1A1A1A).withValues(alpha: 0.92),
        rim: Colors.white.withValues(alpha: 0.10),
        shadow: Colors.black.withValues(alpha: 0.55),
        foreground: const Color(0xFFFAFAFA),
        mutedForeground: const Color(0xFFA1A1A1),
      );
    }
    return GlassColors(
      fill: Colors.white.withValues(alpha: 0.96),
      rim: Colors.black.withValues(alpha: 0.10),
      shadow: Colors.black.withValues(alpha: 0.16),
      foreground: const Color(0xFF0A0A0A),
      mutedForeground: const Color(0xFF737373),
    );
  }

  final Color fill;
  final Color rim;
  final Color shadow;
  final Color foreground;
  final Color mutedForeground;
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

  final MeditoNavItem item;
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
                  fontFamily: googleSans,
                  fontSize: 12,
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
