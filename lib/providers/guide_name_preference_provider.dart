import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

class GuideNamePreferenceNotifier extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    return prefs.getString(SharedPreferenceConstants.lastSelectedGuideName);
  }

  void setGuideName(String? guideName) {
    state = guideName;

    final prefs = ref.read(sharedPreferencesProvider);
    if (guideName != null) {
      prefs.setString(
        SharedPreferenceConstants.lastSelectedGuideName,
        guideName,
      );
    } else {
      prefs.remove(SharedPreferenceConstants.lastSelectedGuideName);
    }
  }

  void clearGuideName() {
    setGuideName(null);
  }
}

final guideNamePreferenceProvider =
    NotifierProvider<GuideNamePreferenceNotifier, String?>(
      GuideNamePreferenceNotifier.new,
    );
