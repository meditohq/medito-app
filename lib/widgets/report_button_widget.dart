import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/medito_icon.dart';

import '../constants/colors/color_constants.dart';
import '../models/models.dart';
import '../providers/player/audio_state_provider.dart';
import 'report_dialog_widget.dart';

/// Button widget for reporting track issues
class ReportButtonWidget extends ConsumerWidget {
  final PlaybackRequest request;

  const ReportButtonWidget({
    super.key,
    required this.request,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => _showReportDialog(context, ref),
      tooltip: AppLocalizations.of(context)!.reportIssue,
      icon: MeditoIcon(
        assetName: MeditoIcons.alert,
        color: ColorConstants.white.withValues(alpha: 0.5),
        size: 24,
      ),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    final playbackState = ref.read(audioStateProvider);
    final currentPosition = playbackState.position;

    showDialog(
      context: context,
      builder: (context) => ReportDialogWidget(
        request: request,
        timestampAtOpen: currentPosition,
      ),
    );
  }
}
