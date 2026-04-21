import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/track/track_model.dart';
import '../providers/device_and_app_info/device_and_app_info_provider.dart';
import '../services/report_service.dart';
import '../utils/duration_extensions.dart';
import '../utils/logger.dart';
import '../utils/utils.dart';
import 'dialogs/dialogs.dart';
import 'snackbar_widget.dart';

/// Dialog widget for reporting track issues
class ReportDialogWidget extends ConsumerWidget {
  final TrackModel track;
  final int timestampAtOpen;
  final String formattedPosition;

  ReportDialogWidget({
    super.key,
    required this.track,
    required this.timestampAtOpen,
  }) : formattedPosition =
            Duration(milliseconds: timestampAtOpen).toMinutesSeconds();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return MeditoDialog(
      maxHeight: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeditoDialogTitle(l10n.reportTrack),
          const SizedBox(height: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MeditoDialogBody(l10n.reportTrackDescription(track.title)),
                const SizedBox(height: 16),
                Text(
                  l10n.reportDialogQuestion,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withOpacityValue(0.8),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () =>
                      launchURLInBrowser('https://medito.support.site/'),
                  child: Text(
                    l10n.reportDialogHelpLink,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.brandPurple,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          MeditoDialogPrimaryButton(
            label: l10n.reportForThisTrack,
            onPressed: () => _handleReport(context, ref, isFullTrack: true),
          ),
          const SizedBox(height: 8),
          MeditoDialogSecondaryButton(
            label: '${l10n.reportAtCurrentPosition} $formattedPosition',
            onPressed: () => _handleReport(context, ref, isFullTrack: false),
          ),
          const SizedBox(height: 8),
          MeditoDialogSecondaryButton(
            label: l10n.cancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReport(
    BuildContext context,
    WidgetRef ref, {
    required bool isFullTrack,
  }) async {
    Navigator.of(context).pop();

    try {
      final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
      final locale = deviceInfo.languageCode;

      final timestamp = isFullTrack ? 0 : timestampAtOpen;

      await ReportService.launchReportForm(
        locale: locale,
        trackId: track.id,
        timestamp: timestamp,
        trackName: track.title,
        guideName: track.audio.isNotEmpty ? track.audio.first.guideName : null,
      );

      if (context.mounted) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.reportDialogHelpLink,
          onActionPressed: () =>
              launchURLInBrowser('https://medito.support.site/'),
          actionLabel: AppLocalizations.of(context)!.helpPage,
        );
      }
    } catch (e) {
      AppLogger.d('REPORT', 'Error launching report form: $e');
    }
  }
}
