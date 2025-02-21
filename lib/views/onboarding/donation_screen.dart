import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DonationScreen extends ConsumerStatefulWidget {
  const DonationScreen({super.key, this.onNext});

  final VoidCallback? onNext;

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen>
    with WidgetsBindingObserver {
  bool _didAttemptDonation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _didAttemptDonation) {
      _didAttemptDonation = false;
      widget.onNext?.call();
    }
  }

  void _handleDonationAction(BuildContext context, bool didDonate) {
    if (didDonate) {
      _didAttemptDonation = true;
      final deviceInfo = ref.read(deviceAndAppInfoProvider);
      final url = _getDonationUrlForCurrency(deviceInfo.value?.currencyName);

      handleNavigation(
        TypeConstants.url,
        [url],
        context,
      );
    }
  }

  String _getDonationUrlForCurrency(String? currencyName) {
    const defaultUrl = 'https://meditofoundation.org/donate';
    final urls = {
      'USD':
          'https://medito.notion.site/Donate-in-US-Dollars-07f19ed2f8cd416cb935ebb9422949ae',
      'GBP':
          'https://medito.notion.site/Donate-in-British-Pounds-f8303845086949ee8310b836e52be507',
      'EUR':
          'https://medito.notion.site/Donate-in-Euros-51f78f48702f41b69e6b76d8ee635a1b',
      'AUD':
          'https://medito.notion.site/Donate-in-Australian-Dollars-af35055553194aa48680fe52b3642ddc',
      'INR':
          'https://medito.notion.site/Donate-in-Indian-Rupees-505b3419fbb046f5968272a9f6cf52c9',
      'CAD':
          'https://medito.notion.site/Donate-in-C-Canadian-Dollars-dc2fa660a76147e7a237db2ec469d4d8',
    };

    return urls[currencyName] ?? defaultUrl;
  }

  void _handleNextAction() {
    widget.onNext?.call();
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meProvider);
    final isDonor = meAsync.value?.hasActiveSubscription ?? false;

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    isDonor
                        ? StringConstants.donationThankYouTitle
                        : StringConstants.donationTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isDonor
                        ? StringConstants.donationThankYouBody
                        : StringConstants.donationBody,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Column(
                children: [
                  _buildActionButton(
                    text: isDonor
                        ? StringConstants.donationVisitFoundation
                        : StringConstants.donateNow,
                    onPressed: () => _handleDonationAction(context, true),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _handleNextAction,
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isDonor
                            ? StringConstants.donationContinue
                            : StringConstants.noThanks,
                        style: const TextStyle(
                          color: ColorConstants.lightPurple,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      {required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConstants.lightPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}
