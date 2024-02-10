import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/home/home_provider.dart';
import 'shortcuts_items_widget.dart';

class ShortcutsWidget extends ConsumerStatefulWidget {
  const ShortcutsWidget({super.key});

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
    var response = ref.watch(fetchShortcutsProvider);

    return response.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: true,
      data: (data) => ShortcutsItemsWidget(
        data: data,
      ),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(fetchShortcutsProvider),
        isLoading: response.isLoading,
        isScaffold: false,
      ),
      loading: () => const ShortcutsShimmerWidget(),
    );
  }
}