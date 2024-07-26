import 'package:firebase_analytics/firebase_analytics.dart';

import '../shared_preference/shared_preference_provider.dart';

Future<void> updateAnalyticsCollectionBasedOnConsent() async {
  var prefs = await initializeSharedPreferences();
  final hasAcceptedAnalytics = prefs.getBool('accepted_analytics') ?? true;

  await FirebaseAnalytics.instance
      .setAnalyticsCollectionEnabled(hasAcceptedAnalytics);
}

Future<void> setAnalyticsConsent(bool consent) async {
  var prefs = await initializeSharedPreferences();
  await prefs.setBool('accepted_analytics', consent);

  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(consent);
}

Future<bool> getAnalyticsConsent() async {
  var prefs = await initializeSharedPreferences();

  return prefs.getBool("accepted_analytics") ?? true;
}
