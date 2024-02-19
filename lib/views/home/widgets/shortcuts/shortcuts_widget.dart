import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/home/shortcuts/shortcuts_model.dart';
import 'shortcuts_items_widget.dart';

class ShortcutsWidget extends ConsumerStatefulWidget {
  const ShortcutsWidget({super.key, required this.data});

  final List<ShortcutsModel> data;

  @override
  ConsumerState<ShortcutsWidget> createState() => _ShortcutsWidgetState();
}

class _ShortcutsWidgetState extends ConsumerState<ShortcutsWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ShortcutsItemsWidget(
      data: widget.data,
    );
  }
}
