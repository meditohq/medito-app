import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/utils/black_friday_utils.dart';

final homeWidgetOrderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final homeWidgetOrderProvider =
    NotifierProvider<HomeWidgetOrderNotifier, List<HomeWidgetType>>(
      HomeWidgetOrderNotifier.new,
    );

class HomeWidgetOrderNotifier extends Notifier<List<HomeWidgetType>> {
  bool _productsPromoted = false;

  @override
  List<HomeWidgetType> build() {
    return _applyBlackFridayOrdering(_loadBaseOrder());
  }

  static const _defaultOrder = [
    HomeWidgetType.upNext,
    HomeWidgetType.shortcuts,
    HomeWidgetType.carousel,
    HomeWidgetType.quote,
    HomeWidgetType.products,
  ];

  List<HomeWidgetType> _loadBaseOrder() {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedOrder = prefs.getStringList(
      SharedPreferenceConstants.homeWidgetOrder,
    );
    if (savedOrder == null) return List.of(_defaultOrder);

    // A saved order only lists the sections that existed when it was saved
    // (products and upNext are both missing from older saves), so add any
    // added since instead of hiding them for good: upNext at the top,
    // anything else at the bottom. The set also drops duplicates, which
    // fromString's fallback can produce and ReorderableListView's keys
    // can't take.
    final order = {...savedOrder.map(HomeWidgetType.fromString)}.toList();
    for (final type in _defaultOrder) {
      if (order.contains(type)) continue;
      if (type == HomeWidgetType.upNext) {
        order.insert(0, type);
      } else {
        order.add(type);
      }
    }
    return order;
  }

  List<HomeWidgetType> _applyBlackFridayOrdering(
    List<HomeWidgetType> baseOrder,
  ) {
    _productsPromoted = false;
    final now = ref.read(homeWidgetOrderClockProvider)();
    if (!BlackFridayUtils.isBlackFridayWeek(now)) {
      return baseOrder;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final isDismissed = BlackFridayUtils.isBlackFridayDismissedSync(
      prefs,
      now: now,
    );
    if (isDismissed) {
      return baseOrder;
    }

    final shortcutsIndex = baseOrder.indexOf(HomeWidgetType.shortcuts);
    final productsIndex = baseOrder.indexOf(HomeWidgetType.products);

    if (shortcutsIndex == -1 || productsIndex == -1) {
      return baseOrder;
    }

    if (productsIndex <= shortcutsIndex + 1) {
      return baseOrder;
    }

    _productsPromoted = true;
    final reordered = List<HomeWidgetType>.from(baseOrder);
    reordered.removeAt(productsIndex);
    reordered.insert(shortcutsIndex + 1, HomeWidgetType.products);

    return reordered;
  }

  Future<void> updateOrder(
    List<HomeWidgetType> newOrder, {
    required HomeWidgetType movedWidget,
  }) async {
    if (listEquals(state, newOrder)) return;

    final orderToSave = List<HomeWidgetType>.of(newOrder);
    if (_productsPromoted && movedWidget != HomeWidgetType.products) {
      // Only undo our temporary move. Moving Shortcuts or another section
      // must not turn the promoted products position into a saved preference.
      final baseProductsIndex = _loadBaseOrder().indexOf(
        HomeWidgetType.products,
      );
      orderToSave.remove(HomeWidgetType.products);
      orderToSave.insert(
        baseProductsIndex.clamp(0, orderToSave.length),
        HomeWidgetType.products,
      );
    } else if (movedWidget == HomeWidgetType.products) {
      // An explicit products drag replaces the temporary position, including
      // for subsequent drags in the same editing session.
      _productsPromoted = false;
    }

    state = [...newOrder];
    await _saveOrderToPrefs(orderToSave);
  }

  Future<void> _saveOrderToPrefs(List<HomeWidgetType> order) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final stringOrder = order.map((type) => type.name).toList();
    await prefs.setStringList(
      SharedPreferenceConstants.homeWidgetOrder,
      stringOrder,
    );
  }

  void refreshOrder() {
    state = _applyBlackFridayOrdering(_loadBaseOrder());
  }
}
