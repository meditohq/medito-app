import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/utils/black_friday_utils.dart';

final homeWidgetOrderProvider =
    NotifierProvider<HomeWidgetOrderNotifier, List<HomeWidgetType>>(
      HomeWidgetOrderNotifier.new,
    );

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
      orderToSave = _restoreBaseOrderFromBlackFridayOrder(newOrder);
    } else {
      orderToSave = newOrder;
    }

    state = [...newOrder];
    await _saveOrderToPrefs(orderToSave);
  }

  List<HomeWidgetType> _restoreBaseOrderFromBlackFridayOrder(
    List<HomeWidgetType> blackFridayOrder,
  ) {
    final shortcutsIndex = blackFridayOrder.indexOf(HomeWidgetType.shortcuts);
    final productsIndex = blackFridayOrder.indexOf(HomeWidgetType.products);

    if (shortcutsIndex == -1 ||
        productsIndex == -1 ||
        productsIndex != shortcutsIndex + 1) {
      return blackFridayOrder;
    }

    final restored = List<HomeWidgetType>.from(blackFridayOrder);
    restored.removeAt(productsIndex);

    final originalProductsPosition = _findOriginalProductsPosition(restored);

    restored.insert(originalProductsPosition, HomeWidgetType.products);

    return restored;
  }

  int _findOriginalProductsPosition(List<HomeWidgetType> orderWithoutProducts) {
    final shortcutsIndex = orderWithoutProducts.indexOf(
      HomeWidgetType.shortcuts,
    );
    final carouselIndex = orderWithoutProducts.indexOf(HomeWidgetType.carousel);
    final quoteIndex = orderWithoutProducts.indexOf(HomeWidgetType.quote);

    if (shortcutsIndex == -1) {
      return orderWithoutProducts.length;
    }

    final widgetsAfterShortcuts = <HomeWidgetType>[];
    if (carouselIndex != -1 && carouselIndex > shortcutsIndex) {
      widgetsAfterShortcuts.add(HomeWidgetType.carousel);
    }
    if (quoteIndex != -1 && quoteIndex > shortcutsIndex) {
      widgetsAfterShortcuts.add(HomeWidgetType.quote);
    }

    if (widgetsAfterShortcuts.isEmpty) {
      return shortcutsIndex + 1;
    }

    final firstWidgetAfterShortcuts = widgetsAfterShortcuts
        .map((widget) => orderWithoutProducts.indexOf(widget))
        .reduce((a, b) => a < b ? a : b);

    return firstWidgetAfterShortcuts;
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
