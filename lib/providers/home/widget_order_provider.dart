import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/utils/black_friday_utils.dart';

final homeWidgetOrderProvider =
    NotifierProvider<HomeWidgetOrderNotifier, List<HomeWidgetType>>(
      HomeWidgetOrderNotifier.new,
    );

/// The order to store after the user arranges Home during Black Friday week.
///
/// Black Friday lifts `products` up to sit directly under Shortcuts. Saving the
/// visible list as it stands therefore turns the promo arrangement into the
/// user's own order, and it survives the week. Put `products` back in the slot
/// it held in [baseOrder], the order that was on disk before the promo was
/// applied, and keep the user's placement of every other section.
///
/// When `products` is not directly under Shortcuts, the user moved it there
/// themselves, so the visible list is returned unchanged.
///
/// The previous version guessed the slot from the sections after Shortcuts, so
/// for a default order (`products` last) it reinserted `products` exactly where
/// Black Friday had put it: the saved order never changed.
List<HomeWidgetType> restoreBaseOrderFromBlackFridayOrder(
  List<HomeWidgetType> blackFridayOrder, {
  required List<HomeWidgetType> baseOrder,
}) {
  final productsIndex = blackFridayOrder.indexOf(HomeWidgetType.products);
  final shortcutsIndex = blackFridayOrder.indexOf(HomeWidgetType.shortcuts);
  if (productsIndex == -1 ||
      shortcutsIndex == -1 ||
      productsIndex != shortcutsIndex + 1) {
    return blackFridayOrder;
  }

  final baseProductsIndex = baseOrder.indexOf(HomeWidgetType.products);
  if (baseProductsIndex == -1) return blackFridayOrder;

  final restored = List<HomeWidgetType>.from(blackFridayOrder)
    ..remove(HomeWidgetType.products);
  restored.insert(
    baseProductsIndex.clamp(0, restored.length),
    HomeWidgetType.products,
  );
  return restored;
}

class HomeWidgetOrderNotifier extends Notifier<List<HomeWidgetType>> {
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
    final now = DateTime.now();
    if (!BlackFridayUtils.isBlackFridayWeek(now)) {
      return baseOrder;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final isDismissed = BlackFridayUtils.isBlackFridayDismissedSync(prefs);
    if (isDismissed) {
      return baseOrder;
    }

    final shortcutsIndex = baseOrder.indexOf(HomeWidgetType.shortcuts);
    final productsIndex = baseOrder.indexOf(HomeWidgetType.products);

    if (shortcutsIndex == -1 || productsIndex == -1) {
      return baseOrder;
    }

    if (productsIndex < shortcutsIndex) {
      return baseOrder;
    }

    final reordered = List<HomeWidgetType>.from(baseOrder);
    reordered.removeAt(productsIndex);
    reordered.insert(shortcutsIndex + 1, HomeWidgetType.products);

    return reordered;
  }

  Future<void> updateOrder(List<HomeWidgetType> newOrder) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final now = DateTime.now();
    final isBlackFriday = BlackFridayUtils.isBlackFridayWeek(now);
    final isDismissed = BlackFridayUtils.isBlackFridayDismissedSync(prefs);

    List<HomeWidgetType> orderToSave;
    if (isBlackFriday && !isDismissed) {
      orderToSave = restoreBaseOrderFromBlackFridayOrder(
        newOrder,
        baseOrder: _loadBaseOrder(),
      );
    } else {
      orderToSave = newOrder;
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
