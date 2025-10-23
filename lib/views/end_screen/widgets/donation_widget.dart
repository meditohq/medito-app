import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/logger.dart';
import '../../../services/analytics/firebase_analytics_service.dart';

import '../../../models/events/donation/donation_page_model.dart';
import '../../../providers/donation/donation_page_provider.dart';
import '../../../repositories/me/me_repository.dart';
import '../../../routes/routes.dart';
import '../../../utils/utils.dart';
import '../../../widgets/errors/medito_error_widget.dart';
import 'feedback_widget.dart';

class DonationWidget extends ConsumerStatefulWidget {
  const DonationWidget({super.key});

  @override
  ConsumerState<DonationWidget> createState() => DonationWidgetState();
}

class DonationWidgetState extends ConsumerState<DonationWidget> {
  bool _isDonor = false;
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
              const FeedbackWidget(),
            ],
          );
        },
      ),
    );
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
                ? AppLocalizations.of(context)!.thankYouForYourSupport
                : donationPageModel.title ?? 'Support Medito',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: sourceSerif,
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _isDonor
                ? AppLocalizations.of(context)!.donorSupportMessage
                : donationPageModel.text ??
                    AppLocalizations.of(context)!
                        .meditoReliesOnYourDonationsToSurvive,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 16,
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                TypeConstants.route,
                [RouteConstants.donation],
                context,
                ref: ref,
                sourceRouteName:
                    FirebaseAnalyticsService.paywallSourceEndScreen,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConstants.white,
                foregroundColor: ColorConstants.lightPurple,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                button.title ?? AppLocalizations.of(context)!.donateNow,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
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
                TypeConstants.route,
                [RouteConstants.donation],
                context,
                sourceRouteName:
                    FirebaseAnalyticsService.paywallSourceEndScreen,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConstants.lightPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                button.title ?? AppLocalizations.of(context)!.donateNow,
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
