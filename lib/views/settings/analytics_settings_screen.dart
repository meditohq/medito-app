import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/analytics/meta_sdk_service.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';

final _firebaseEnabledProvider = Provider<bool>((ref) {
  return ref
          .watch(sharedPreferencesProvider)
          .getBool(SharedPreferenceConstants.analyticsFirebaseEnabled) ??
      true;
});

final _metaEnabledProvider = Provider<bool>((ref) {
  return ref
          .watch(sharedPreferencesProvider)
          .getBool(SharedPreferenceConstants.analyticsMetaEnabled) ??
      true;
});

class AnalyticsSettingsScreen extends ConsumerWidget {
  const AnalyticsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.analyticsTrackingTitle),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.analyticsTrackingTitle),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context)!.analyticsTrackingContent),
              const SizedBox(height: 24),
              _SwitchTile(
                label: 'Firebase Analytics',
                provider: _firebaseEnabledProvider,
                onConfirmDisableMessage: Platform.isIOS
                    ? AppLocalizations.of(context)!.iosTrackingDialogContent
                    : AppLocalizations.of(context)!.analyticsTrackingContent,
                onChanged: (value) async {
                  await ref
                      .read(sharedPreferencesProvider)
                      .setBool(
                        SharedPreferenceConstants.analyticsFirebaseEnabled,
                        value,
                      );
                  // Disable/enable the SDKs at the native level
                  await FirebaseAnalyticsService().setCollectionEnabled(value);
                  await CrashlyticsService().setCollectionEnabled(value);
                  ref.invalidate(_firebaseEnabledProvider);
                },
              ),
              _SwitchTile(
                label: 'Meta (Facebook) App Events',
                provider: _metaEnabledProvider,
                onConfirmDisableMessage: Platform.isIOS
                    ? AppLocalizations.of(context)!.iosTrackingDialogContent
                    : AppLocalizations.of(context)!.analyticsTrackingContent,
                onChanged: (value) async {
                  await ref
                      .read(sharedPreferencesProvider)
                      .setBool(
                        SharedPreferenceConstants.analyticsMetaEnabled,
                        value,
                      );
                  // Disable/enable the Meta SDK at runtime
                  await MetaSdkService.instance.setEnabled(value);
                  ref.invalidate(_metaEnabledProvider);
                },
              ),
              if (Platform.isIOS) ...[
                const SizedBox(height: 24),
                Text(AppLocalizations.of(context)!.iosTrackingDialogContent),
              ],
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  handleNavigation(
                    'url',
                    ['https://meditofoundation.org/privacy'],
                    context,
                    ref: ref,
                  );
                },
                icon: const Icon(Icons.privacy_tip_outlined),
                label: Text(AppLocalizations.of(context)!.privacyPolicy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends ConsumerWidget {
  final String label;
  final Provider<bool> provider;
  final String onConfirmDisableMessage;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.label,
    required this.provider,
    required this.onConfirmDisableMessage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(provider);

    return SwitchListTile(
      title: Text(label),
      value: enabled,
      onChanged: (value) async {
        if (!value) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => MeditoDialog(
              title: AppLocalizations.of(context)!.areYouSure,
              content: MeditoDialogBody(
                Platform.isIOS
                    ? AppLocalizations.of(context)!.iosTrackingDialogContent
                    : AppLocalizations.of(context)!.analyticsTrackingContent,
              ),
              actions: [
                MeditoDialogSecondaryButton(
                  label: AppLocalizations.of(context)!.iosTrackingDialogCancel,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                MeditoDialogDestructiveButton(
                  label: AppLocalizations.of(context)!.iosTrackingDialogDisable,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          );

          if (confirm != true) return;
        }

        onChanged(value);
      },
    );
  }
}
