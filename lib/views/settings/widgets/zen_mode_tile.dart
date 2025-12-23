import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/settings/settings_providers.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';

class ZenModeTile extends ConsumerWidget {
  final Widget icon;
  final String title;

  const ZenModeTile({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isZenModeEnabled = ref.watch(zenModeProvider);

    return RowItemWidget(
      icon: icon,
      title: title,
      hasUnderline: true,
      isSwitch: true,
      switchValue: isZenModeEnabled,
      onSwitchChanged: (value) {
        ref.read(zenModeProvider.notifier).setEnabled(value);
      },
    );
  }
}

