import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/settings/settings_providers.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';

class WidgetOptionTile extends ConsumerWidget {
  final Widget icon;
  final String title;
  final VoidCallback onTap;

  const WidgetOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSeenWidget = ref.watch(widgetOptionSeenProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        RowItemWidget(
          icon: icon,
          title: title,
          hasUnderline: true,
          onTap: onTap,
        ),
        if (!hasSeenWidget)
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

