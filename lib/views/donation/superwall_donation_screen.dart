// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/services/paywall_manager_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SuperwallDonationScreen extends ConsumerStatefulWidget {
  const SuperwallDonationScreen({super.key});

  @override
  ConsumerState<SuperwallDonationScreen> createState() =>
      _SuperwallDonationScreenState();
}

class _SuperwallDonationScreenState
    extends ConsumerState<SuperwallDonationScreen> {
  bool _hasTriggeredPaywall = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Trigger Superwall paywall as soon as the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSuperwallPaywall();
      // Add timeout to prevent infinite loading
      _addTimeoutFallback();
    });
  }

  @override
  void dispose() {
    // Clean up Pay clients when the screen is disposed
    // This helps prevent event channel conflicts
    super.dispose();
  }

  void _addTimeoutFallback() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        AppLogger.w('SUPERWALL_DONATION_SCREEN',
            'Paywall loading timeout - falling back to web donation');
        setState(() {
          _isLoading = false;
        });
        _fallbackToWebDonation();
      }
    });
  }

  Future<void> _triggerSuperwallPaywall() async {
    if (_hasTriggeredPaywall) return;
    _hasTriggeredPaywall = true;

    try {
      AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Starting paywall trigger');

      // Get payment config to pass currency and pricing data to Superwall
      // Add error handling for payment config loading failures
      try {
        await ref.read(paymentConfigProvider.future);
      } catch (paymentConfigError) {
        AppLogger.e(
            'SUPERWALL_DONATION_SCREEN',
            'Failed to load payment config, falling back to web donation',
            paymentConfigError);
        // If payment config fails (e.g., API not deployed to prod),
        // fall back to web donation
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          await _fallbackToWebDonation();
          return;
        }
      }

      final paywallManager = ref.read(paywallManagerServiceProvider);

      await paywallManager.triggerDonationPaywall(
        onPaywallPresented: () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        onPaywallDismissed: () {
          AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Paywall dismissed');
          // Close the screen when paywall is dismissed
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _handlePaywallError(error);
          }
        },
        onDonationInitiated: (amount, isMonthly) {
          AppLogger.d('SUPERWALL_DONATION_SCREEN',
              'Donation initiated: amount: $amount, isMonthly: $isMonthly');
          AppLogger.d(
              'SUPERWALL_DONATION_SCREEN', 'Dismissing Superwall paywall...');
          Superwall.shared.dismiss();
          // Show donation confirmation in snackbar
          if (mounted) {
            final donationText = isMonthly
                ? 'Monthly donation: \$${amount.toString()}'
                : 'One-time donation: \$${amount.toString()}';
            showSnackBar(context, donationText);
            // Close the screen after showing the snackbar
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        },
      );
    } catch (error) {
      AppLogger.e(
          'SUPERWALL_DONATION_SCREEN',
          'Failed to trigger Superwall paywall, falling back to web donation',
          error);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        await _fallbackToWebDonation();
      }
    }
  }

  void _handlePaywallError(String error) {
    AppLogger.w('SUPERWALL_DONATION_SCREEN', 'Paywall error: $error');
    // For any paywall error, fall back to web donation
    _fallbackToWebDonation();
  }

  /// Fallback method to open web donation when API fails
  Future<void> _fallbackToWebDonation() async {
    try {
      AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Opening web donation fallback');
      final uri = Uri.parse('https://meditofoundation.org/donate');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          showSnackBar(
            context,
            AppLocalizations.of(context)!.unableToLoadDonationOptionsAtThisTime,
          );
        }
      }
    } catch (error) {
      AppLogger.e(
          'SUPERWALL_DONATION_SCREEN', 'Failed to open web donation', error);
      if (mounted) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.unableToLoadDonationOptionsAtThisTime,
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a minimal loading screen while the paywall is being prepared
    // The actual paywall will appear as a full-screen overlay
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _isLoading
                    ? AppLocalizations.of(context)!.loadingDonationOptions
                    : AppLocalizations.of(context)!.preparingDonation,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.thisMayTakeAMoment,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
