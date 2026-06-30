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
    final prefs = ref.read(sharedPreferencesProvider);
    final savedOrder = prefs.getStringList(
      SharedPreferenceConstants.homeWidgetOrder,
    );

    List<HomeWidgetType> baseOrder;
    if (savedOrder != null) {
      baseOrder = savedOrder
          .map((type) => HomeWidgetType.fromString(type))
          .toList();
      // Ensure upNext is always included if not already present
      if (!baseOrder.contains(HomeWidgetType.upNext)) {
        baseOrder.insert(0, HomeWidgetType.upNext);
      }
    } else {
      baseOrder = [
        HomeWidgetType.upNext,
        HomeWidgetType.shortcuts,
        HomeWidgetType.carousel,
        HomeWidgetType.quote,
        HomeWidgetType.products,
      ];
    }

    return _applyBlackFridayOrdering(baseOrder);
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
    final prefs = ref.read(sharedPreferencesProvider);
    final savedOrder = prefs.getStringList(
      SharedPreferenceConstants.homeWidgetOrder,
    );

    List<HomeWidgetType> baseOrder;
    if (savedOrder != null) {
      baseOrder = savedOrder
          .map((type) => HomeWidgetType.fromString(type))
          .toList();
      // Ensure upNext is always included if not already present
      if (!baseOrder.contains(HomeWidgetType.upNext)) {
        baseOrder.insert(0, HomeWidgetType.upNext);
      }
    } else {
      baseOrder = [
        HomeWidgetType.upNext,
        HomeWidgetType.shortcuts,
        HomeWidgetType.carousel,
        HomeWidgetType.quote,
        HomeWidgetType.products,
      ];
    }

    state = _applyBlackFridayOrdering(baseOrder);
  }
}
