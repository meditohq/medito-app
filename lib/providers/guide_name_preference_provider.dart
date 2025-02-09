import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

class GuideNamePreferenceNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    var prefs = ref.watch(sharedPreferencesProvider);

    return prefs.getString(SharedPreferenceConstants.lastSelectedGuideName);
  }

  Future<void> setGuideName(String? guideName) async {
    var prefs = ref.read(sharedPreferencesProvider);
    if (guideName != null) {
      await prefs.setString(
          SharedPreferenceConstants.lastSelectedGuideName, guideName);
    } else {
      await prefs.remove(SharedPreferenceConstants.lastSelectedGuideName);
    }

    state = AsyncValue.data(guideName);
  }
}

final guideNamePreferenceProvider =
    AsyncNotifierProvider<GuideNamePreferenceNotifier, String?>(
  GuideNamePreferenceNotifier.new,
);
