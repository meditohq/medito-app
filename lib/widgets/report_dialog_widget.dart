import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/colors/color_constants.dart';
import '../l10n/app_localizations.dart';
import '../models/track/track_model.dart';
import '../providers/device_and_app_info/device_and_app_info_provider.dart';
import '../services/report_service.dart';
import '../utils/duration_extensions.dart';
import '../utils/logger.dart';
import '../utils/utils.dart';
import '../widgets/snackbar_widget.dart';

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
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 500,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              AppLocalizations.of(context)!.reportTrack,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),

            // Content - wrapped in Flexible to handle overflow
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!
                        .reportTrackDescription(track.title),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.5,
                      fontSize: 14,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.reportDialogQuestion,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () =>
                        launchURLInBrowser('https://medito.support.site/'),
                    child: Text(
                      AppLocalizations.of(context)!.reportDialogHelpLink,
                      style: TextStyle(
                        color: ColorConstants.lightPurple,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons in a column for better handling of long text
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Full track report button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () =>
                        _handleReport(context, ref, isFullTrack: true),
                    style: TextButton.styleFrom(
                      backgroundColor: ColorConstants.lightPurple,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.reportForThisTrack,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Current position report button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () =>
                        _handleReport(context, ref, isFullTrack: false),
                    style: TextButton.styleFrom(
                      backgroundColor:
                          ColorConstants.lightPurple.withValues(alpha: 0.1),
                      foregroundColor: ColorConstants.lightPurple,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '${AppLocalizations.of(context)!.reportAtCurrentPosition} $formattedPosition',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.cancel,
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
