import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/dnd_provider.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';

class DndSettingTile extends ConsumerWidget {
  final Widget icon;
  final String title;
  final bool hasUnderline;

  const DndSettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.hasUnderline = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDndEnabled = ref.watch(dndProvider);

    return RowItemWidget(
      icon: icon,
      title: title,
      hasUnderline: hasUnderline,
      isSwitch: true,
      switchValue: isDndEnabled,
      onSwitchChanged: (value) {
        ref.read(dndProvider.notifier).toggleDnd(value);
      },
    );
  }
}
