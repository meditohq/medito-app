import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../utils/logger.dart';

import '../../../models/events/donation/donation_page_model.dart';
import '../../../providers/donation/donation_page_provider.dart';
import '../../../repositories/me/me_repository.dart';
import '../../../routes/routes.dart';
import '../../../utils/utils.dart';
import '../../../widgets/errors/medito_error_widget.dart';

class DonationWidget extends ConsumerStatefulWidget {
  const DonationWidget({super.key});

  @override
  ConsumerState<DonationWidget> createState() => _DonationWidgetState();
}

class _DonationWidgetState extends ConsumerState<DonationWidget> {
  bool _isDonor = false;
  bool _showThankYouMessage = false;
  bool _isCheckingSubscription = true;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  @override
  Widget build(BuildContext context) {
    final donationPage = ref.watch(fetchDonationPageProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: donationPage.when(
        loading: () => _buildLoadingWidget(),
        error: (err, _) {
          final error = err is AppError ? err : const UnknownError();
          return MeditoErrorWidget(
            error: error,
            onTap: () => ref.refresh(fetchDonationPageProvider),
            isScaffold: false,
          );
        },
        data: (DonationPageModel donationPageModel) {
          return Column(
            children: [
              _isCheckingSubscription
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: _buildDonationWidget(context, donationPageModel),
                    ),
              height20,
               _buildFeedbackCard(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: ColorConstants.onyx,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            StringConstants.howDoYouFeel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: teachers,
              fontSize: 22,
              color: ColorConstants.white,
            ),
          ),
          _showThankYouMessage
              ? _buildThanksMessage()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 16,
                  children: [
                    Semantics(
                      button: true,
                      label: StringConstants.thanksForSharingHappy,
                      child: _buildEmotionButton(
                        context,
                        HugeIcons.solidStandardSmile,
                        StringConstants.thanksForSharing,
                        _handlePositiveFeedback,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: StringConstants.thanksForSharingNeutral,
                      child: _buildEmotionButton(
                        context,
                        HugeIcons.solidStandardNeutral,
                        StringConstants.thanksForSharing,
                        _handleNeutralFeedback,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: StringConstants.thanksForSharingSad,
                      child: _buildEmotionButton(
                        context,
                        HugeIcons.solidStandardSad01,
                        StringConstants.thanksForSharing,
                        _handleNegativeFeedback,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildThanksMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Text(
        StringConstants.thanksForSharing,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          color: ColorConstants.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _handlePositiveFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });
  }

  Future<void> _handleNeutralFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });
  }

  Future<void> _handleNegativeFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });
  }

  Future<void> _checkSubscriptionStatus() async {
    setState(() {
      _isCheckingSubscription = true;
    });

    try {
      final meRepo = ref.read(meRepositoryProvider);
      final userInfo = await meRepo.fetchMe();

      if (mounted) {
        setState(() {
          _isDonor = userInfo.hasActiveSubscription;
          _isCheckingSubscription = false;
        });
      }
    } catch (e) {
      AppLogger.e('DONATION', 'Error checking subscription: $e');
      if (mounted) {
        setState(() {
          _isDonor = false;
          _isCheckingSubscription = false;
        });
      }
    }
  }

  Widget _buildEmotionButton(
    BuildContext context,
    IconData icon,
    String feedbackMessage,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(8),
          color: ColorConstants.ebony,
        ),
        child: Icon(
          icon,
          size: 36,
          color: ColorConstants.lightPurple,
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildDonationWidget(
    BuildContext context,
    DonationPageModel donationPageModel,
  ) {
    final textColor = donationPageModel.cardTextColor != null
        ? parseColor(donationPageModel.cardTextColor!)
        : ColorConstants.lightPurple;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: ColorConstants.lightPurple,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _isDonor
                ? 'Thank You for Your Support'
                : donationPageModel.title ?? 'Support Medito',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: sourceSerif,
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: ColorConstants.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isDonor
                ? 'We rely on donors like you to continue providing mindfulness to everyone.'
                : donationPageModel.text ??
                    StringConstants.meditoReliesOnYourDonationsToSurvive,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: ColorConstants.white,
              fontWeight: FontWeight.w400,
            ),
          ),
          height20,
          _buildButtonRow(donationPageModel.buttons, context),
          if (donationPageModel.footerText != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                donationPageModel.footerText!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButtonRow(List<ButtonModel>? buttons, BuildContext context) {
    if (buttons == null || buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> buttonWidgets = [];

    if (buttons.length == 1) {
      ButtonModel button = buttons[0];

      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => handleNavigation(
                button.type,
                [button.path],
                context,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConstants.white,
                foregroundColor: ColorConstants.lightPurple,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                button.title ?? StringConstants.donateNow,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      for (int i = 0; i < buttons.length; i++) {
        ButtonModel button = buttons[i];

        buttonWidgets.add(
          Expanded(
            child: ElevatedButton(
              onPressed: () => handleNavigation(
                button.type,
                [button.path],
                context,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConstants.lightPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                button.title ?? StringConstants.donateNow,
              ),
            ),
          ),
        );

        if (i < buttons.length - 1) {
          buttonWidgets.add(const SizedBox(width: 8));
        }
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: buttonWidgets,
      );
    }
  }
}