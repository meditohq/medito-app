import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/home/widget_order_provider.dart';

class CustomiseHomeLayoutBottomSheet extends ConsumerWidget {
  const CustomiseHomeLayoutBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(homeWidgetOrderProvider);
    final notifier = ref.read(homeWidgetOrderProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            StringConstants.customiseHomeLayout,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: order.length,
              itemBuilder: (context, index) {
                final widgetType = order[index];
                return ListTile(
                  key: ValueKey(widgetType),
                  leading: HugeIcon(
                    icon: HugeIcons.bulkRoundedHandGrip,
                    color: ColorConstants.white,
                  ),
                  title: Text(_getTitleForType(widgetType)),
                );
              },
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex -= 1;
                final newOrder = List.of(order);
                final item = newOrder.removeAt(oldIndex);
                newOrder.insert(newIndex, item);
                notifier.updateOrder(newOrder);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getTitleForType(String type) {
    switch (type) {
      case 'shortcuts':
        return StringConstants.shortcutsTitle;
      case 'carousel':
        return StringConstants.carouselTitle;
      case 'quote':
        return StringConstants.quoteTitle;
      default:
        return '';
    }
  }
}
