import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

class DownloadSettings {
  const DownloadSettings({
    this.deleteCompleted = false,
    this.downloadNext = false,
    this.useMobileData = false,
  });

  final bool deleteCompleted;
  final bool downloadNext;
  final bool useMobileData;
}

final downloadSettingsProvider =
    NotifierProvider<DownloadSettingsNotifier, DownloadSettings>(
      DownloadSettingsNotifier.new,
    );

class DownloadSettingsNotifier extends Notifier<DownloadSettings> {
  @override
  DownloadSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return DownloadSettings(
      deleteCompleted:
          prefs.getBool(
            SharedPreferenceConstants.autoDeleteCompletedDownloads,
          ) ??
          false,
      downloadNext:
          prefs.getBool(SharedPreferenceConstants.autoDownloadNextSession) ??
          false,
      useMobileData:
          prefs.getBool(SharedPreferenceConstants.autoDownloadOnMobileData) ??
          false,
    );
  }

  Future<void> setDeleteCompleted(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(SharedPreferenceConstants.autoDeleteCompletedDownloads, value);
    if (!ref.mounted) return;
    state = DownloadSettings(
      deleteCompleted: value,
      downloadNext: state.downloadNext,
      useMobileData: state.useMobileData,
    );
  }

  Future<void> setDownloadNext(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(SharedPreferenceConstants.autoDownloadNextSession, value);
    if (!ref.mounted) return;
    state = DownloadSettings(
      deleteCompleted: state.deleteCompleted,
      downloadNext: value,
      useMobileData: state.useMobileData,
    );
  }

  Future<void> setUseMobileData(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(SharedPreferenceConstants.autoDownloadOnMobileData, value);
    if (!ref.mounted) return;
    state = DownloadSettings(
      deleteCompleted: state.deleteCompleted,
      downloadNext: state.downloadNext,
      useMobileData: value,
    );
  }
}
