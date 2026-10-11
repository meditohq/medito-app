import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/review_service.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService(prefs: ref.read(sharedPreferencesProvider));
});
