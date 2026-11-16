import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/app_tracking_transparency_service.dart';

/// End screens that may show the ask before an unanswered one counts as "no".
/// Ignoring it leaves usage stats off, so this only stops the card nagging.
const int analyticsReconsentMaxImpressions = 3;

const String analyticsReconsentAccepted = 'accepted';
const String analyticsReconsentDeclined = 'declined';

/// Whether the user currently allows App Tracking Transparency. Its own
/// provider so tests can override it without the platform channel.
final attAuthorizedProvider = FutureProvider<bool>(
  (ref) => AppTrackingTransparencyService.instance.isTrackingAuthorized(),
);

class AnalyticsReconsentNotifier extends Notifier<AnalyticsReconsentState> {
  @override
  AnalyticsReconsentState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return AnalyticsReconsentState(
      analyticsEnabled:
          prefs.getBool(SharedPreferenceConstants.analyticsFirebaseEnabled) ??
          true,
      optedOutInSettings:
          prefs.getString(SharedPreferenceConstants.analyticsOptOutSource) ==
          SharedPreferenceConstants.analyticsOptOutSourceSettings,
      answer: prefs.getString(
        SharedPreferenceConstants.analyticsReconsentAnswer,
      ),
      impressions:
          prefs.getInt(
            SharedPreferenceConstants.analyticsReconsentImpressions,
          ) ??
          0,
    );
  }

  Future<void> recordImpression() async {
    final impressions = state.impressions + 1;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(
          SharedPreferenceConstants.analyticsReconsentImpressions,
          impressions,
        );
    state = state.copyWith(impressions: impressions);
  }

  /// Stores the answer only; turning analytics on is the caller's job so this
  /// stays free of the Firebase SDKs.
  Future<void> answer({required bool accepted}) async {
    final answer = accepted
        ? analyticsReconsentAccepted
        : analyticsReconsentDeclined;
    await ref
        .read(sharedPreferencesProvider)
        .setString(SharedPreferenceConstants.analyticsReconsentAnswer, answer);
    state = state.copyWith(answer: answer, analyticsEnabled: accepted);
  }
}

class AnalyticsReconsentState {
  const AnalyticsReconsentState({
    required this.analyticsEnabled,
    required this.optedOutInSettings,
    required this.answer,
    required this.impressions,
  });

  final bool analyticsEnabled;
  final bool optedOutInSettings;
  final String? answer;
  final int impressions;

  AnalyticsReconsentState copyWith({
    bool? analyticsEnabled,
    String? answer,
    int? impressions,
  }) => AnalyticsReconsentState(
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    optedOutInSettings: optedOutInSettings,
    answer: answer ?? this.answer,
    impressions: impressions ?? this.impressions,
  );
}

final analyticsReconsentProvider =
    NotifierProvider<AnalyticsReconsentNotifier, AnalyticsReconsentState>(
      () => AnalyticsReconsentNotifier(),
    );

/// Whether to show the end-screen ask to turn usage stats back on.
///
/// iOS builds 3.4.16–2606.11 switched Firebase analytics off whenever the user
/// declined App Tracking Transparency, and 31a676db stopped that without
/// resetting the stored value. Nothing recorded which opt-outs were real, so
/// rather than flip them back silently we ask, once. Gates:
/// - iOS, where the ATT path existed (every Android opt-out is the user's);
/// - analytics is off and wasn't turned off on the Data Collection screen
///   since that started being recorded;
/// - ATT is not authorised: the old path only wrote the opt-out on a denial,
///   so an opt-out alongside an authorisation was the user's own choice;
/// - not answered yet, and shown fewer than
///   [analyticsReconsentMaxImpressions] times.
///
/// Takes precedence over the reminder and account soft-asks: it is answered
/// once and gone, while those come back after a snooze.
final shouldShowAnalyticsReconsentProvider = Provider<bool>((ref) {
  if (defaultTargetPlatform != TargetPlatform.iOS) return false;

  final state = ref.watch(analyticsReconsentProvider);
  if (state.analyticsEnabled || state.optedOutInSettings) return false;
  if (state.answer != null) return false;
  if (state.impressions >= analyticsReconsentMaxImpressions) return false;

  // Unknown until the status loads, and unknown is not "denied".
  final attAuthorized = ref.watch(attAuthorizedProvider).value;
  return attAuthorized == false;
});
