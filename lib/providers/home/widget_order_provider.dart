import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

final homeWidgetOrderProvider =
    NotifierProvider<HomeWidgetOrderNotifier, List<String>>(
  HomeWidgetOrderNotifier.new,
);

class HomeWidgetOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getStringList(SharedPreferenceConstants.homeWidgetOrder) ??
        const ['shortcuts', 'carousel', 'quote'];
  }

  Future<void> updateOrder(List<String> newOrder) async {
    state = [...newOrder];
    await _saveOrderToPrefs(newOrder);
  }

  Future<void> _saveOrderToPrefs(List<String> order) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(SharedPreferenceConstants.homeWidgetOrder, order);
  }
}
