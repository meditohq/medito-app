import 'dart:async';
import 'dart:io';

import 'package:do_not_disturb/do_not_disturb.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';

/// Whether the app should switch the phone to Do Not Disturb while a session
/// plays. Android only: iOS offers no API for this, so the setting is hidden.
///
/// The preference and the system permission are separate things. The user can
/// have the preference on while Android has revoked access; [setDndMode] then
/// silently does nothing. The settings sheet gates turning it on behind
/// [hasAccess] so the two normally agree.
class DndNotifier extends Notifier<bool> {
  final _dndPlugin = DoNotDisturbPlugin();

  @override
  bool build() {
    return _loadSavedPreference();
  }

  bool _loadSavedPreference() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(SharedPreferenceConstants.dndEnabled) ?? false;
  }

  /// Whether Android has granted this app Do Not Disturb access.
  Future<bool> hasAccess() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _dndPlugin.isNotificationPolicyAccessGranted();
    } catch (_) {
      return false;
    }
  }

  /// Opens the system page where the user grants Do Not Disturb access and
  /// resolves once they come back to the app, reporting whether access is
  /// granted by then. Times out so a caller is never left waiting if the app
  /// is killed while away.
  Future<bool> requestAccessViaSettings({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (!Platform.isAndroid) return false;

    final completer = Completer<bool>();
    late final _ResumeObserver observer;

    Future<void> finish(bool granted) async {
      if (completer.isCompleted) return;
      WidgetsBinding.instance.removeObserver(observer);
      completer.complete(granted);
    }

    observer = _ResumeObserver(() async => finish(await hasAccess()));
    WidgetsBinding.instance.addObserver(observer);
    await _dndPlugin.openNotificationPolicyAccessSettings();

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        WidgetsBinding.instance.removeObserver(observer);
        return false;
      },
    );
  }

  /// Persists the preference. Callers turning it on should confirm
  /// [hasAccess] first; this does not open system settings itself.
  Future<void> setEnabled(bool value) async {
    if (!Platform.isAndroid) return;
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPreferenceConstants.dndEnabled, value);
  }

  /// Applies or lifts Do Not Disturb around playback. Best effort: no-op when
  /// the preference is off or access has been revoked.
  Future<void> setDndMode(bool enable) async {
    if (!Platform.isAndroid) return;

    try {
      final hasAccess = await _dndPlugin.isNotificationPolicyAccessGranted();
      if (hasAccess && state) {
        await _dndPlugin.setInterruptionFilter(
          enable ? InterruptionFilter.alarms : InterruptionFilter.all,
        );
      }
    } catch (e) {
      // Handle the error silently as this is a best-effort feature
    }
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResumed);

  final Future<void> Function() onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(onResumed());
    }
  }
}

final dndProvider = NotifierProvider<DndNotifier, bool>(() => DndNotifier());
