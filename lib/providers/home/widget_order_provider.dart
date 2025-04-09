import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

final homeWidgetOrderProvider =
    NotifierProvider<HomeWidgetOrderNotifier, List<HomeWidgetType>>(
  HomeWidgetOrderNotifier.new,
);

class HomeWidgetOrderNotifier extends Notifier<List<HomeWidgetType>> {
  @override
  List<HomeWidgetType> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedOrder =
        prefs.getStringList(SharedPreferenceConstants.homeWidgetOrder);

    if (savedOrder != null) {
      return savedOrder.map((type) => HomeWidgetType.fromString(type)).toList();
    }

    return [
      HomeWidgetType.shortcuts,
      HomeWidgetType.carousel,
      HomeWidgetType.products,
      HomeWidgetType.quote,
    ];
  }

  Future<void> updateOrder(List<HomeWidgetType> newOrder) async {
    state = [...newOrder];
    await _saveOrderToPrefs(newOrder);
  }

  Future<void> _saveOrderToPrefs(List<HomeWidgetType> order) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final stringOrder = order.map((type) => type.name).toList();
    await prefs.setStringList(
        SharedPreferenceConstants.homeWidgetOrder, stringOrder);
  }
}
