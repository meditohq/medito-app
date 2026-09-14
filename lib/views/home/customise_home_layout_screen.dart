import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/home/widget_order_provider.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/widgets/medito_icon.dart';

class CustomiseHomeLayoutScreen extends ConsumerStatefulWidget {
  const CustomiseHomeLayoutScreen({super.key});

  @override
  ConsumerState<CustomiseHomeLayoutScreen> createState() =>
      CustomiseHomeLayoutScreenState();
}

class CustomiseHomeLayoutScreenState
    extends ConsumerState<CustomiseHomeLayoutScreen> {
  /// Order when the screen opened, so leaving without dragging anything is
  /// not reported as a change.
  late final List<HomeWidgetType> _initialOrder;

  @override
  void initState() {
    super.initState();
    _initialOrder = List.of(ref.read(homeWidgetOrderProvider));
    FirebaseAnalyticsService().logScreenView(
      screenName: 'CustomiseHomeLayoutScreen',
    );
  }

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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      leading: MeditoIcon(
                        assetName: MeditoIcons.dragHandle,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: Text(_getTitleForType(widgetType)),
                    );
                  },
                  onReorderItem: (oldIndex, newIndex) {
                    var newOrder = List.of(order);
                    var item = newOrder.removeAt(oldIndex);
                    newOrder.insert(newIndex, item);
                    notifier.updateOrder(newOrder);
                  },
                ),
              ),
            ),
            SingleBackButtonActionBar(onBackPressed: _logOrderAndPop),
          ],
        ),
      ),
    );
  }

  void _logOrderAndPop() {
    final order = ref.read(homeWidgetOrderProvider);

    if (!listEquals(order, _initialOrder)) {
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.homeWidgetOrderChanged,
            parameters: {
              AnalyticsEventConstants.paramHomeWidgetOrder:
                  HomeWidgetType.toStringList(order).join(','),
              AnalyticsEventConstants.paramHomeWidgetFirst: order.first.name,
              'desc': AnalyticsEventConstants.homeWidgetOrderChangedDesc,
            },
          );
    }
    ref.read(refreshHomeAPIsProvider);
    Navigator.pop(context);
  }

  String _getTitleForType(HomeWidgetType type) {
    switch (type) {
      case HomeWidgetType.shortcuts:
        return AppLocalizations.of(context)!.shortcutsTitle;
      case HomeWidgetType.carousel:
        return AppLocalizations.of(context)!.carouselTitle;
      case HomeWidgetType.quote:
        return AppLocalizations.of(context)!.quoteTitle;
      case HomeWidgetType.products:
        return AppLocalizations.of(context)!.meditationProducts;
      case HomeWidgetType.upNext:
        return AppLocalizations.of(context)!.upNextTitle;
    }
  }
}
