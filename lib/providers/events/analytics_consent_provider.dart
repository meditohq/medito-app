import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared_preference/shared_preference_provider.dart';

final analyticsConsentProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  return prefs.getBool('accepted_analytics') ?? false;
});