// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/models/stripe/payment_method_model.dart'
    as payment_models;
import 'package:medito/widgets/dialogs/dialogs.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/services/paywall_manager_service.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SuperwallDonationScreen extends ConsumerStatefulWidget {
  const SuperwallDonationScreen({super.key, this.source});

  final String? source;

  @override
  ConsumerState<SuperwallDonationScreen> createState() =>
      _SuperwallDonationScreenState();
}

class _SuperwallDonationScreenState
    extends ConsumerState<SuperwallDonationScreen> {
  bool _hasTriggeredPaywall = false;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String? _currentPaywallId;

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
        AppLogger.w(
          'SUPERWALL_DONATION_SCREEN',
          'Paywall loading timeout - falling back to web donation',
        );
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
      final paywallManager = ref.read(paywallManagerServiceProvider);

      await paywallManager.triggerDonationPaywall(
        onPaywallPresented: (String paywallId) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _currentPaywallId = paywallId;
            });
          }
        },
        onPaywallDismissed: (String paywallId) {
          AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Paywall dismissed');

          if (mounted && !_isProcessingPayment) {
            AppLogger.d(
              'SUPERWALL_DONATION_SCREEN',
              'User dismissed - closing screen',
            );
            Navigator.of(context).pop(false);
          } else if (_isProcessingPayment) {
            AppLogger.d(
              'SUPERWALL_DONATION_SCREEN',
              'Payment in progress - keeping screen open for completion',
            );
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
        onDonationInitiated: (amount, isMonthly) async {
          AppLogger.d(
            'SUPERWALL_DONATION_SCREEN',
            'Donation initiated: amount: $amount, isMonthly: $isMonthly',
          );

          // Mark that we're processing payment so onPaywallDismissed doesn't close the screen
          _isProcessingPayment = true;

          AppLogger.d(
            'SUPERWALL_DONATION_SCREEN',
            'Dismissing Superwall paywall...',
          );
          Superwall.shared.dismiss();

          // Trigger native payment sheet instead of just showing snackbar
          if (mounted) {
            await _processDonationPayment(context, amount, isMonthly);
          }
        },
      );
    } catch (error) {
      AppLogger.e(
        'SUPERWALL_DONATION_SCREEN',
        'Failed to trigger Superwall paywall, falling back to web donation',
        error,
      );
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

  /// Process the donation payment using native payment methods
  Future<void> _processDonationPayment(
    BuildContext context,
    num amount,
    bool isMonthly,
  ) async {
    try {
      AppLogger.d(
        'SUPERWALL_DONATION_SCREEN',
        'Processing donation payment: amount=$amount, isMonthly=$isMonthly',
      );

      final uiController = ref.read(paymentUIControllerProvider.notifier);
      final paywallId = _currentPaywallId ?? 'unknown';
      final authRepository = ref.read(authRepositorySyncProvider);
      final userId = authRepository.currentUser?.id ?? 'unknown';

      // Check if user is logged in
      final isLoggedIn = await authRepository.isLoggedIn();
      String? userEmail = authRepository.currentUser?.email;

      // If user is not logged in, collect email for identification
      if (!isLoggedIn || (userEmail == null || userEmail.isEmpty)) {
        AppLogger.d(
          'SUPERWALL_DONATION_SCREEN',
          'User not logged in or no email - collecting email for payment identification',
        );

        userEmail = await _collectEmailForPayment(context);
        if (userEmail == null) {
          if (mounted) {
            // Return false to indicate no donation was made
            Navigator.of(context).pop(false);
          }
          return;
        }
      }

      // Get payment config for currency
      final paymentConfig = await ref.read(paymentConfigProvider.future);

      // Get available payment methods
      final availableMethods = await ref.read(
        availablePaymentMethodsProvider.future,
      );

      if (availableMethods.isEmpty) {
        await _fallbackToWebDonation();
        return;
      }

      // Choose the best payment method (prioritize platform pay)
      var selectedMethod = availableMethods.first;

      // Prefer Apple Pay over card payments
      for (final method in availableMethods) {
        if (method.type == payment_models.PaymentMethodType.applePay) {
          selectedMethod = method;
          break;
        }
      }

      AppLogger.d(
        'SUPERWALL_DONATION_SCREEN',
        'Selected payment method: ${selectedMethod.type}',
      );

      // Amount is already in cents from Superwall
      final amountInCents = amount.toInt();

      // Trigger the appropriate payment based on type
      AppLogger.d(
        'SUPERWALL_DONATION_SCREEN',
        'Initiating ${isMonthly ? "monthly subscription" : "one-time payment"} for $amountInCents cents (${(amountInCents / 100).toStringAsFixed(2)} ${paymentConfig.pricing.currency})',
      );

      final result = isMonthly
          ? await uiController.initiateMonthlySubscription(
              context: context,
              amount: amountInCents,
              currency: paymentConfig.pricing.currency,
              paymentMethod: selectedMethod.type,
              paywallId: paywallId,
              userId: userId,
              userEmail: userEmail,
              paywallSource: widget.source,
              onSuccess: () {},
            )
          : await uiController.initiateOneTimePayment(
              context: context,
              amount: amountInCents,
              currency: paymentConfig.pricing.currency,
              paymentMethod: selectedMethod.type,
              paywallId: paywallId,
              userId: userId,
              userEmail: userEmail,
              paywallSource: widget.source,
              onSuccess: () {},
            );

      switch (result) {
        case PaymentSuccess():
          AppLogger.d(
            'SUPERWALL_DONATION_SCREEN',
            'Payment flow completed successfully',
          );

          if (mounted) {
            AppLogger.d(
              'SUPERWALL_DONATION_SCREEN',
              'Closing donation screen after successful payment',
            );
            Navigator.of(context).pop(true);
          }
        case PaymentFailure(
          errorMessage: final errorMessage,
          paymentIntentId: final paymentIntentId,
        ):
          AppLogger.w(
            'SUPERWALL_DONATION_SCREEN',
            'Payment failed: $errorMessage (${paymentIntentId ?? 'unknown'})',
          );

          if (mounted) {
            Navigator.of(context).pop(false);
          }
        case PaymentCancelled():
          AppLogger.d(
            'SUPERWALL_DONATION_SCREEN',
            'Payment cancelled - closing donation screen',
          );

          if (mounted) {
            Navigator.of(context).pop(false);
          }
      }
    } catch (error) {
      AppLogger.e(
        'SUPERWALL_DONATION_SCREEN',
        'Failed to process donation payment',
        error,
      );

      if (mounted) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.unableToLoadDonationOptionsAtThisTime,
        );

        // Close the screen immediately - the global snackbar will show regardless
        // Return false to indicate no donation was made
        Navigator.of(context).pop(false);
      }
    } finally {
      _isProcessingPayment = false;
    }
  }

  /// Collect email address from anonymous users for payment identification
  Future<String?> _collectEmailForPayment(BuildContext context) async {
    final emailController = TextEditingController();
    final focusNode = FocusNode();
    bool keepKeyboardClosed = false;
    bool hasRequestedInitialFocus = false;
    String? email;

    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Use StatefulBuilder to request focus after build
        return StatefulBuilder(
          builder: (context, setState) {
            if (!hasRequestedInitialFocus && !keepKeyboardClosed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!keepKeyboardClosed) {
                  focusNode.requestFocus();
                }
              });
              hasRequestedInitialFocus = true;
            }

            return PopScope(
              canPop: false, // Prevent back button from dismissing dialog
              child: MeditoDialog(
                title: AppLocalizations.of(context)!.emailForReceipt,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MeditoDialogBody(
                      AppLocalizations.of(context)!.emailForReceiptDescription,
                    ),
                    const SizedBox(height: 16),
                    AutofillGroup(
                      child: MeditoDialogTextField(
                        controller: emailController,
                        focusNode: focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        labelText: AppLocalizations.of(context)!.email,
                        suffixIcon: emailController.text.isNotEmpty
                            ? IconButton(
                                icon: MeditoIcon(
                                  assetName: MeditoIcons.xmark,
                                  size: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                                onPressed: () {
                                  emailController.clear();
                                  focusNode.requestFocus();
                                  setState(() {});
                                },
                              )
                            : null,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [
                          TextInputFormatter.withFunction(
                            (oldValue, newValue) => TextEditingValue(
                              text: newValue.text.toLowerCase(),
                              selection: newValue.selection,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            '@gmail.com',
                            '@icloud.com',
                            '@me.com',
                            '@outlook.com',
                            '@yahoo.com',
                            '@pm.me',
                            '@hotmail.com',
                            '@live.com',
                          ].map((domain) {
                            return OutlinedButton(
                              onPressed: () {
                                keepKeyboardClosed = true;
                                focusNode.unfocus();

                                final currentText = emailController.text.trim();
                                String newText;

                                if (currentText.isEmpty) {
                                  newText = domain;
                                } else if (currentText.contains('@')) {
                                  final localPart = currentText
                                      .split('@')
                                      .first;
                                  newText = '$localPart$domain';
                                } else {
                                  newText = '$currentText$domain';
                                }

                                final lowerText = newText.toLowerCase();
                                emailController.text = lowerText;
                                emailController.selection =
                                    TextSelection.fromPosition(
                                      TextPosition(offset: lowerText.length),
                                    );
                                setState(() {});
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                domain,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 12),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
                actions: [
                  MeditoDialogPrimaryButton(
                    label: AppLocalizations.of(context)!.next,
                    onPressed: () {
                      final enteredEmail = emailController.text
                          .trim()
                          .toLowerCase();
                      if (_isValidEmail(enteredEmail)) {
                        Navigator.of(dialogContext).pop(enteredEmail);
                      } else {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!.invalidEmail,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((result) {
      email = result;
      focusNode.dispose();
    });

    return email;
  }

  /// Simple email validation
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Fallback method to open web donation when API fails
  Future<void> _fallbackToWebDonation() async {
    try {
      AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Opening web donation fallback');
      final uri = Uri.parse('https://donate.meditofoundation.org');

      // Close the screen first
      if (mounted) {
        Navigator.of(context).pop(false);
      }

      // Wait a moment for the screen to close, then open the web URL
      await Future.delayed(const Duration(milliseconds: 300));

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Web donation opened');
      } else {
        // If we can't open the URL, show snackbar on the previous screen
        // Note: context might not be available after pop, so we'll skip the snackbar
        AppLogger.w(
          'SUPERWALL_DONATION_SCREEN',
          'Unable to launch web donation URL',
        );
      }
    } catch (error) {
      AppLogger.e(
        'SUPERWALL_DONATION_SCREEN',
        'Failed to open web donation',
        error,
      );
      // Screen is already closed, so we can't show snackbar here
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
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
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
