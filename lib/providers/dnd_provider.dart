import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:do_not_disturb/do_not_disturb.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';

class DndNotifier extends Notifier<bool> {
  final _dndPlugin = DoNotDisturbPlugin();

  @override
  bool build() {
    _loadPreference();
    _initDndState();
    return false;
  }

  Future<bool> checkNotificationPolicyAccess() async {
    return await _dndPlugin.isNotificationPolicyAccessGranted();
  }

  Future<void> openNotificationSettings() async {
    await _dndPlugin.openNotificationPolicyAccessSettings();
  }

  Future<void> _initDndState() async {
    if (Platform.isAndroid) {
      final isDndEnabled = await _dndPlugin.isDndEnabled();
      state = isDndEnabled;
    }
  }

  Future<void> _loadPreference() async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = prefs.getBool(SharedPreferenceConstants.dndEnabled) ?? false;
  }

  Future<void> _savePreference(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPreferenceConstants.dndEnabled, value);
  }

  Future<void> toggleDnd(bool isEnabled) async {
    if (Platform.isAndroid) {
      if (isEnabled) {
        // When enabling, check and request permission
        final hasAccess = await _dndPlugin.isNotificationPolicyAccessGranted();
        if (!hasAccess) {
          await _dndPlugin.openNotificationPolicyAccessSettings();
        }
      }

      state = isEnabled;
      await _savePreference(isEnabled);
    }
  }

  Future<void> setDndMode(bool enable) async {
    if (!Platform.isAndroid) return;

    try {
      final hasAccess = await _dndPlugin.isNotificationPolicyAccessGranted();
      if (hasAccess && state) {
        await _dndPlugin.setInterruptionFilter(
          enable ? InterruptionFilter.priority : InterruptionFilter.all,
        );
      }
    } catch (e) {
      // Handle the error silently as this is a best-effort feature
    }
  }
}

final dndProvider = NotifierProvider<DndNotifier, bool>(() => DndNotifier());
