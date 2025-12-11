import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/services/paywall_manager_service.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/snackbar_widget.dart';

class DebugInfoScreen extends ConsumerWidget {
  const DebugInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        title:
            HomeHeaderWidget(greeting: AppLocalizations.of(context)!.debugInfo),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _copyDebugInfo(context, ref),
            tooltip: AppLocalizations.of(context)!.copy,
          ),
        ],
      ),
      body: _buildBody(context, ref),
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    return ref.watch(deviceAppAndUserInfoProvider).when(
          data: (infoString) => _buildInfoView(context, ref, infoString),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(AppLocalizations.of(context)!.anErrorOccurred),
          ),
        );
  }

  Widget _buildInfoView(
      BuildContext context, WidgetRef ref, String infoString) {
    final paywallManager = ref.read(paywallManagerServiceProvider);
    final donationPlacementId = paywallManager.getDonationPlacementId();
    final fullInfo = '$infoString\nDPI: $donationPlacementId';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        fullInfo,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  void _copyDebugInfo(BuildContext context, WidgetRef ref) async {
    final infoString = await ref.read(deviceAppAndUserInfoProvider.future);
    final paywallManager = ref.read(paywallManagerServiceProvider);
    final donationPlacementId = paywallManager.getDonationPlacementId();
    final fullInfo =
        '$infoString\n\nDonation Placement ID: $donationPlacementId';
    await Clipboard.setData(ClipboardData(text: fullInfo));
    if (context.mounted) {
      showSnackBar(context, AppLocalizations.of(context)!.debugInfoCopied);
    }
  }
}
