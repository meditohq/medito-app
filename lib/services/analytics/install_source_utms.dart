import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores where an install came from (Apple Ads, Play install referrer) as the
/// same UTM prefs deep links set, so GA4 user properties, Meta events and
/// Stripe metadata all carry it. UTMs a deep link already stored are kept:
/// they're more specific (a named campaign) than an install source.
Future<void> storeInstallSourceUtms(
  SharedPreferences prefs,
  Map<String, Object?> utms,
) async {
  if (prefs.getString(SharedPreferenceConstants.utmSource) != null) return;
  for (final MapEntry(:key, :value) in utms.entries) {
    if (value != null) await prefs.setString(key, '$value');
  }
  await FirebaseAnalyticsService.applyStoredUtmParameters();
}
