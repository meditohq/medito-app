import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => HelpScreenState();
}

class HelpScreenState extends ConsumerState<HelpScreen> {
  late List<HelpItem> _helpItems;
  final List<bool> _expandedItems = [];

  @override
  void initState() {
    super.initState();
    _initializeHelpItems();
    _expandedItems.addAll(List.generate(_helpItems.length, (_) => false));
  }

  void _initializeHelpItems() {
    _helpItems = [
      HelpItem(
        title: StringConstants.meditationInterruptionTitle,
        content: StringConstants.meditationInterruptionContent,
        actionText: StringConstants.openBatterySettingsText,
        onActionPressed: _openBatterySettings,
        icon: HugeIcons.solidRoundedVolumeMute02,
      ),
      HelpItem(
        title: StringConstants.downloadTracksTitle,
        content: StringConstants.downloadTracksContent,
        icon: HugeIcons.solidRoundedDownloadSquare02,
      ),
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
            onPressed: () => _launchUrl(StringConstants.bankTransferDetailsUrl),
          ),
        ],
      ),
      HelpItem(
        title: StringConstants.stopDonationTitle,
        content: StringConstants.stopDonationContent,
        actionText: StringConstants.goToDonationPortalText,
        onActionPressed: () => _launchUrl(StringConstants.donationPortalUrl),
        icon: HugeIcons.solidRoundedHeartbreak,
      ),
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
    ];
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
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
        child: SingleChildScrollView(
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
          _buildActionButtons(item),
        ],
      ),
    );
  }

  Widget _buildActionButtons(HelpItem item) {
    if (item.multipleActions != null && item.multipleActions!.isNotEmpty) {
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
      return _buildActionButton(
        item.actionText!,
        item.onActionPressed!,
      );
    }

    return const SizedBox.shrink();
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

    final params = {
      'userId': clientId ?? '',
      'platform': deviceInfo?.platform ?? '',
      'language': deviceInfo?.languageCode ?? '',
      'model': deviceInfo?.model ?? '',
      'appVersion': deviceInfo?.appVersion ?? '',
      'os': deviceInfo?.os ?? '',
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final url = Uri.parse('${StringConstants.contactFormBaseUrl}?$queryString');

    await _launchUrl(url.toString());
  }

  void _openStatsEditPage() async {
    final statsUrl = ref.read(editStatsUrlProvider);
    await _launchUrl(statsUrl);
  }

  static Future<void> _openBatterySettings() async {
    final urlString = Platform.isAndroid
        ? 'package:com.android.settings'
        : Platform.isIOS
            ? 'App-prefs:Battery'
            : null;

    if (urlString == null) return;

    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Fallback to general settings
      final generalSettings = Uri.parse(
          Platform.isAndroid ? 'package:com.android.settings' : 'App-prefs:');
      await launchUrl(generalSettings);
    }
  }
}

class HelpItem {
  final String title;
  final String content;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final List<ActionButton>? multipleActions;
  final IconData? icon;

  const HelpItem({
    required this.title,
    required this.content,
    this.actionText,
    this.onActionPressed,
    this.multipleActions,
    this.icon,
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
