import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/providers/home/widget_order_provider.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';

class CustomiseHomeLayoutScreen extends ConsumerStatefulWidget {
  const CustomiseHomeLayoutScreen({super.key});

  @override
  ConsumerState<CustomiseHomeLayoutScreen> createState() =>
      CustomiseHomeLayoutScreenState();
}

class CustomiseHomeLayoutScreenState
    extends ConsumerState<CustomiseHomeLayoutScreen> {
  @override
  Widget build(BuildContext context) {
    var order = ref.watch(homeWidgetOrderProvider);
    var notifier = ref.read(homeWidgetOrderProvider.notifier);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, popResult) async {
        if (!didPop) {
          _logOrderAndPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: ColorConstants.ebony,
          elevation: 0,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Tap and hold to drag items into your preferred order',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ReorderableListView.builder(
                  itemCount: order.length,
                  itemBuilder: (context, index) {
                    var widgetType = order[index];

                    return ListTile(
                      key: ValueKey(widgetType.name),
                      leading: HugeIcon(
                        icon: HugeIcons.solidSharpMenu01,
                        color: ColorConstants.white,
                      ),
                      title: Text(_getTitleForType(widgetType)),
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) newIndex -= 1;
                    var newOrder = List.of(order);
                    var item = newOrder.removeAt(oldIndex);
                    newOrder.insert(newIndex, item);
                    notifier.updateOrder(newOrder);
                  },
                ),
              ),
            ),
            SingleBackButtonActionBar(
              onBackPressed: _logOrderAndPop,
            ),
          ],
        ),
      ),
    );
  }

  void _logOrderAndPop() {
    var order = ref.read(homeWidgetOrderProvider);
    var analytics = ref.read(analyticsServiceProvider);

    analytics.logEvent(
      name: AnalyticsEventConstants.homeWidgetOrderChanged,
      parameters: {
        'order': HomeWidgetType.toStringList(order),
        'desc': AnalyticsEventConstants.homeWidgetOrderChangedDesc,
      },
    );
    ref.read(refreshHomeAPIsProvider);
    Navigator.pop(context);
  }

  String _getTitleForType(HomeWidgetType type) {
    switch (type) {
      case HomeWidgetType.shortcuts:
        return StringConstants.shortcutsTitle;
      case HomeWidgetType.carousel:
        return StringConstants.carouselTitle;
      case HomeWidgetType.quote:
        return StringConstants.quoteTitle;
      case HomeWidgetType.products:
        return StringConstants.meditationProducts;
    }
  }
}
