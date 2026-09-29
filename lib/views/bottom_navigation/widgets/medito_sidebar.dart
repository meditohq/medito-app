import 'package:flutter/material.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'medito_nav_bar.dart';

/// The same destinations as the phone bar, sized to the available window.
class MeditoSidebar extends StatelessWidget {
  const MeditoSidebar({
    super.key,
    required this.extended,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final bool extended;
  final List<MeditoNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: extended ? 200 : 88,
          height: double.infinity,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? 12 : 8,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      selected: selectedIndex == i,
                      child: Material(
                        color: selectedIndex == i
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onSelected(i),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: extended ? 16 : 8,
                              vertical: 16,
                            ),
                            child: extended
                                ? Row(
                                    children: [
                                      MeditoIcon(assetName: items[i].icon),
                                      const SizedBox(width: 16),
                                      Expanded(child: Text(items[i].label)),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      MeditoIcon(assetName: items[i].icon),
                                      const SizedBox(height: 6),
                                      Text(
                                        items[i].label,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
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
