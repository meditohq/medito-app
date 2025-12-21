export 'device_and_app_info/device_and_app_info_provider.dart';
export 'feature_flags_provider.dart';
export 'home/home_provider.dart';
export 'me/me_provider.dart';
export 'meditation/download_track_provider.dart';
export 'pack/pack_provider.dart';
export 'player/audio_state_provider.dart';
export 'player/download/audio_downloader_provider.dart';
export 'player/player_provider.dart';
export 'shared_preference/shared_preference_provider.dart';
export 'error_widget/medito_error_widget_provider.dart';
export 'explore/explore_provider.dart';
export 'dnd_provider.dart';
export 'settings/reminder_prompt_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';

final analyticsServiceProvider = Provider<FirebaseAnalyticsService>(
  (ref) => FirebaseAnalyticsService(),
);

final analyticsEnabledProvider = FutureProvider<bool>((ref) async {
  final analyticsService = ref.read(analyticsServiceProvider);
  return analyticsService.isAnalyticsEnabled();
});
