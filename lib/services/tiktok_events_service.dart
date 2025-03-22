import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:tiktok_events_sdk/tiktok_events_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Add a provider for the analytics state
final tiktokAnalyticsEnabledProvider =
    StateNotifierProvider<TiktokAnalyticsNotifier, bool>((ref) {
  return TiktokAnalyticsNotifier();
});

// Modify the TikTok events service provider to observe the state
final tiktokEventsServiceProvider = Provider<TiktokEventsService>((ref) {
  final service = TiktokEventsService();

  // Set up a listener to reinitialize when the analytics state changes
  ref.listen<bool>(tiktokAnalyticsEnabledProvider, (previous, current) {
    if (previous != current) {
      service._isEnabled = current;
      service.initialise();
    }
  });

  return service;
});

// Add a StateNotifier to track the analytics enabled state
class TiktokAnalyticsNotifier extends StateNotifier<bool> {
  TiktokAnalyticsNotifier() : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state =
        prefs.getBool(SharedPreferenceConstants.tiktokAnalyticsEnabled) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        SharedPreferenceConstants.tiktokAnalyticsEnabled, enabled);
    state = enabled;
  }
}

class TiktokEventsService {
  bool _isEnabled = true;

  Future<void> initialise() async {
    try {
      // Create iOS options with tracking disabled if user opted out
      final iosOptions = TikTokIosOptions(
        disableTracking: !_isEnabled,
        disableAutomaticTracking: !_isEnabled,
        disableSKAdNetworkSupport: !_isEnabled,
      );

      // Create Android options that respect user preference
      final androidOptions = TikTokAndroidOptions(
        disableAutoStart: !_isEnabled,
        enableAutoIapTrack: _isEnabled,
        disableAdvertiserIDCollection: !_isEnabled,
      );

      // Always initialize the SDK but with appropriate options
      await TikTokEventsSdk.initSdk(
        androidAppId: 'meditofoundation.medito',
        tikTokAndroidId: tiktokAndroidId,
        iosAppId: '1500780518',
        tiktokIosId: tiktokIosId,
        isDebugMode: kDebugMode,
        logLevel: TikTokLogLevel.debug,
        iosOptions: iosOptions,
        androidOptions: androidOptions,
      );

      debugPrint(
          'TikTok SDK initialized with analytics ${_isEnabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('TikTok SDK initialization failed: $e');
    }
  }

  Future<void> logEvent(String eventName,
      {Map<String, dynamic>? customProperties}) async {
    if (!_isEnabled) return;

    final properties = EventProperties(
      customProperties: customProperties,
    );

    try {
      await TikTokEventsSdk.logEvent(
        event: TikTokEvent(
          eventName: eventName,
          properties: properties,
        ),
      );
    } catch (e) {
      debugPrint('Failed to log TikTok event "$eventName": $e');
    }
  }

  Future<void> logShortcutTap({
    required String shortcutId,
    required String shortcutTitle,
    required String? shortcutType,
    required String shortcutPath,
  }) async {
    await logEvent(
      'shortcut_tap',
      customProperties: {
        'shortcut_id': shortcutId,
        'shortcut_title': shortcutTitle,
        'shortcut_type': shortcutType ?? 'unknown',
        'shortcut_path': shortcutPath,
      },
    );
  }

  Future<void> logCompleteMeditationEvent({
    required String meditationId,
    required String meditationName,
    required Duration duration,
  }) async {
    await logEvent(
      'CompleteMeditation',
      customProperties: {
        'meditation_id': meditationId,
        'meditation_name': meditationName,
        'duration_seconds': duration.inSeconds,
      },
    );
  }
}
