import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/home/shortcuts/shortcuts_model.dart';
import 'shortcuts_items_widget.dart';

class ShortcutsWidget extends ConsumerWidget {
  const ShortcutsWidget({super.key, required this.data});

  final List<ShortcutsModel> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShortcutsItemsWidget(
      data: data,
    );
  }
}
