// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/me/me_repository.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medito/services/tiktok_events_service.dart';
// import 'package:disable_battery_optimizations_latest/disable_battery_optimizations_latest.dart';

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => HelpScreenState();
}

class HelpScreenState extends ConsumerState<HelpScreen> {
  late List<HelpItem> _helpItems;
  final List<bool> _expandedItems = [];
  bool _isLoading = true;
  bool _isSubscriber = false;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _toggleAnalytics(bool enabled) async {
    // Just update the StateNotifier - the provider listener will handle the rest
    await ref.read(tiktokAnalyticsEnabledProvider.notifier).setEnabled(enabled);

    showSnackBar(
      context,
      enabled
          ? StringConstants.analyticsEnabled
          : StringConstants.analyticsDisabled,
    );
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final meRepository = ref.read(meRepositoryProvider);
      final meData = await meRepository.fetchMe();
      setState(() {
        _isSubscriber = meData.hasActiveSubscription;
        _initializeHelpItems();
        _expandedItems.addAll(List.generate(_helpItems.length, (_) => false));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isSubscriber = false;
        _initializeHelpItems();
        _expandedItems.addAll(List.generate(_helpItems.length, (_) => false));
        _isLoading = false;
      });
    }
  }

  void _initializeHelpItems() {
    _helpItems = [];

    // Only add battery optimization item for Android
    if (Platform.isAndroid) {
      _helpItems.add(
        HelpItem(
          title: StringConstants.meditationInterruptionTitle,
          content: StringConstants.meditationInterruptionContent,
          actionText: StringConstants.openBatterySettingsText,
          onActionPressed: _handleBatteryOptimization,
          icon: HugeIcons.solidRoundedVolumeMute02,
        ),
      );
    }

    // Add the rest of the help items
    _helpItems.add(
      HelpItem(
        title: StringConstants.downloadTracksTitle,
        content: StringConstants.downloadTracksContent,
        icon: HugeIcons.solidRoundedDownloadSquare02,
      ),
    );

    // Add analytics toggle help item
    _helpItems.add(
      HelpItem(
        title: StringConstants.analyticsTitle,
        content: StringConstants.analyticsContent,
        icon: HugeIcons.solidRoundedShield01,
        hasToggle: true, // Use a flag instead of ToggleAction
      ),
    );

    // Only show donation option if user is not a subscriber
    if (!_isSubscriber) {
      _helpItems.add(
        HelpItem(
          title: StringConstants.supportTitle,
          content: StringConstants.supportContent,
          icon: HugeIcons.solidSharpFavourite,
          multipleActions: [
            ActionButton(
              text: StringConstants.donateViaDonationFormText,
              onPressed: () => _launchUrl(StringConstants.donationFormUrl),
            ),
            ActionButton(
              text: StringConstants.donateViaPayPalText,
              onPressed: () => _launchUrl(StringConstants.payPalDonationUrl),
            ),
            ActionButton(
              text: StringConstants.donateViaBankTransferText,
              onPressed: () =>
                  _launchUrl(StringConstants.bankTransferDetailsUrl),
            ),
          ],
        ),
      );
    }

    // Only show cancel donation option if user is a subscriber
    if (_isSubscriber) {
      _helpItems.add(
        HelpItem(
          title: StringConstants.stopDonationTitle,
          content: StringConstants.stopDonationContent,
          actionText: StringConstants.goToDonationPortalText,
          onActionPressed: () => _launchUrl(StringConstants.donationPortalUrl),
          icon: HugeIcons.solidRoundedHeartbreak,
        ),
      );
    }

    // Add the remaining help items
    _helpItems.addAll([
      HelpItem(
        title: StringConstants.statsWrongTitle,
        content: StringConstants.statsWrongContent,
        actionText: StringConstants.editStatsActionText,
        onActionPressed: _openStatsEditPage,
        icon: HugeIcons.solidSharpEdit02,
      ),
      HelpItem(
        title: StringConstants.contactUsTitle,
        content: StringConstants.contactUsContent,
        actionText: StringConstants.contactUsActionText,
        onActionPressed: _openContactForm,
        icon: HugeIcons.solidRoundedQuestion,
      ),
    ]);
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showDonationRetentionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ColorConstants.onyx,
        title: const Text(
          StringConstants.donationRetentionTitle,
          style: TextStyle(
            color: ColorConstants.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              StringConstants.donationRetentionMainMessage,
              style: TextStyle(color: ColorConstants.white, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              StringConstants.donationRetentionBenefitsHeading,
              style: TextStyle(color: ColorConstants.white, height: 1.5),
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(StringConstants.donationRetentionBenefit1),
            _buildBulletPoint(StringConstants.donationRetentionBenefit2),
            _buildBulletPoint(StringConstants.donationRetentionBenefit3),
            const SizedBox(height: 12),
            const Text(
              StringConstants.donationRetentionFinancialMessage,
              style: TextStyle(color: ColorConstants.white, height: 1.5),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                showSnackBar(
                  context,
                  StringConstants.donationRetentionThankYouMessage,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConstants.lightPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(StringConstants.stayAsDonorButtonText),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(StringConstants.continueToCancellationButtonText),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _launchUrl(StringConstants.donationPortalUrl);
    }
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: ColorConstants.white)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: ColorConstants.white, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: ColorConstants.ebony,
        toolbarHeight: 56.0,
        automaticallyImplyLeading: false,
        title: const HomeHeaderWidget(greeting: StringConstants.helpTitle),
        elevation: 0.0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  vertical: padding16,
                  horizontal: padding16,
                ),
                child: ExpansionPanelList(
                  expandedHeaderPadding: EdgeInsets.zero,
                  dividerColor: Colors.transparent,
                  elevation: 0,
                  expansionCallback: (index, isExpanded) {
                    setState(() {
                      _expandedItems[index] = !_expandedItems[index];
                    });
                  },
                  children: List.generate(
                    _helpItems.length,
                    (index) => ExpansionPanel(
                      backgroundColor: ColorConstants.onyx,
                      headerBuilder: (context, isExpanded) => ListTile(
                        leading: _helpItems[index].icon != null
                            ? HugeIcon(
                                icon: _helpItems[index].icon!,
                                color: ColorConstants.white,
                                size: 24,
                              )
                            : null,
                        title: Text(
                          _helpItems[index].title,
                          style: const TextStyle(
                            color: ColorConstants.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      body: _buildPanelBody(_helpItems[index]),
                      isExpanded: _expandedItems[index],
                      canTapOnHeader: true,
                    ),
                  ),
                ),
              ),
      ),
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildPanelBody(HelpItem item) {
    return Padding(
      padding: const EdgeInsets.only(
        left: padding16,
        right: padding16,
        bottom: padding16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: padding16),
          _buildActionWidgets(item),
        ],
      ),
    );
  }

  Widget _buildActionWidgets(HelpItem item) {
    if (item.hasToggle == true) {
      return _buildToggleWidget();
    } else if (item.multipleActions != null &&
        item.multipleActions!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: item.multipleActions!
            .map((action) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildActionButton(
                    action.text,
                    action.onPressed,
                  ),
                ))
            .toList(),
      );
    } else if (item.actionText != null && item.onActionPressed != null) {
      // Special handling for donation cancellation
      if (item.title == StringConstants.stopDonationTitle) {
        return _buildActionButton(
          item.actionText!,
          () => _showDonationRetentionDialog(),
        );
      } else {
        return _buildActionButton(
          item.actionText!,
          item.onActionPressed!,
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildToggleWidget() {
    // Watch the analytics state
    final analyticsEnabled = ref.watch(tiktokAnalyticsEnabledProvider);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ColorConstants.lightPurple),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            analyticsEnabled
                ? StringConstants.analyticsEnabled
                : StringConstants.analyticsDisabled,
            style: const TextStyle(
              color: ColorConstants.white,
              fontSize: 16,
            ),
          ),
          Switch(
            value: analyticsEnabled,
            onChanged: _toggleAnalytics,
            activeColor: ColorConstants.lightPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorConstants.lightPurple,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: const BorderSide(color: ColorConstants.lightPurple),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  void _openContactForm() async {
    final clientId = await ref.read(userIdProvider.future);
    final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
    final stats = await ref.read(statsProvider.future);
    var recentSessions = '';

    try {
      if (stats.audioCompleted != null &&
          stats.audioCompleted?.isNotEmpty == true) {
        // Take the most recent 10 sessions (or fewer if less are available)
        final recent = stats.audioCompleted?.take(10).toList();
        for (var session in recent ?? []) {
          recentSessions += '${session.timestamp},';
        }
        // Remove trailing comma
        if (recentSessions.isNotEmpty) {
          recentSessions =
              recentSessions.substring(0, recentSessions.length - 1);
        }
      }
    } catch (e) {
      // Silently handle any errors
    }

    final params = {
      'userId': clientId,
      'platform': deviceInfo.platform,
      'language': deviceInfo.languageCode,
      'model': deviceInfo.model,
      'appVersion': deviceInfo.appVersion,
      'os': deviceInfo.os,
      'recentSessions': recentSessions,
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final url = Uri.parse('${StringConstants.contactFormBaseUrl}?$queryString');

    await _launchUrl(url.toString());
  }

  void _openStatsEditPage() async {
    final statsUrlAsync = ref.read(editStatsUrlProvider);

    statsUrlAsync.whenData((statsUrl) async {
      await _launchUrl(statsUrl);
    });
  }

  Future<void> _handleBatteryOptimization() async {
    await _launchUrl(StringConstants.dontKillMyAppUrl);
  }
}

class HelpItem {
  final String title;
  final String content;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final List<ActionButton>? multipleActions;
  final IconData? icon;
  final bool hasToggle;

  const HelpItem({
    required this.title,
    required this.content,
    this.actionText,
    this.onActionPressed,
    this.multipleActions,
    this.icon,
    this.hasToggle = false,
  });
}

class ActionButton {
  final String text;
  final VoidCallback onPressed;

  const ActionButton({
    required this.text,
    required this.onPressed,
  });
}
