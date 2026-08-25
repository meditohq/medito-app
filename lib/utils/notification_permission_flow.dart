import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:medito/l10n/app_localizations.dart';

/// Everything between "user asked for reminders" and "the OS actually lets us
/// send them". Three surfaces need it — onboarding, the end-screen card and the
/// settings tile — and each previously handled it differently, or not at all.

/// Soft-ask shown immediately before the OS notification permission dialog.
///
/// The system dialog is effectively one-shot: on iOS every denial we record is
/// `permanently_denied`, so the prompt never appears again and that user can
/// never be reached. The expensive mistake is therefore spending the prompt on
/// someone who was going to refuse. Declining this dialog costs nothing — the
/// system prompt is never raised, and a later surface can ask again.
///
/// Pure UI: callers log their own analytics so each surface keeps its own
/// funnel. Returns true if the user chose to continue to the system prompt.
Future<bool> showNotificationPermissionPrimer(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.reminderPrimerTitle),
      content: Text(l10n.reminderPrimerBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.notNow),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.reminderPrimerContinue),
        ),
      ],
    ),
  );

  return proceed == true;
}

/// Shown when permission is already permanently denied, so no system prompt is
/// coming and the only route left is the phone's own settings.
///
/// Returns true if the user chose to go there.
Future<bool> showNotificationsBlockedDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.notificationsBlockedTitle),
      content: Text(l10n.notificationsBlockedBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.notNow),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.openSettings),
        ),
      ],
    ),
  );

  return proceed == true;
}

/// Opens the phone's app-settings page and resolves once the user comes back,
/// reporting whether notification permission is granted by then.
///
/// Sending someone to settings used to be the end of the interaction: the app
/// had no idea they had returned, so a user who granted permission there came
/// back to an unchanged screen and had to tap the same control again. Callers
/// can now finish the job for them.
///
/// Resolves on the first resume after the settings page opens. Times out so a
/// caller is never left awaiting forever if the app is killed while away.
Future<bool> openSettingsAndAwaitPermission({
  Duration timeout = const Duration(minutes: 5),
}) async {
  final completer = Completer<bool>();
  late final _ResumeObserver observer;

  Future<void> finish(bool granted) async {
    if (completer.isCompleted) return;
    WidgetsBinding.instance.removeObserver(observer);
    completer.complete(granted);
  }

  observer = _ResumeObserver(() async {
    final status = await Permission.notification.status;
    await finish(status.isGranted);
  });

  WidgetsBinding.instance.addObserver(observer);
  await openAppSettings();

  return completer.future.timeout(
    timeout,
    onTimeout: () {
      WidgetsBinding.instance.removeObserver(observer);
      return false;
    },
  );
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
