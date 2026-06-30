import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/analytics/firebase_analytics_service.dart';
import '../../../widgets/dialogs/dialogs.dart';
import '../../../widgets/medito_icon.dart';
import '../../../widgets/snackbar_widget.dart';

import '../../../models/events/donation/donation_page_model.dart';
import '../../../providers/donation/donation_page_provider.dart';
import '../../../providers/donation/donation_snooze_provider.dart';
import '../../../routes/routes.dart';
import '../../../utils/utils.dart';
import '../../../widgets/errors/medito_error_widget.dart';
import '../../home/widgets/home_gradient_border.dart';
import 'feedback_widget.dart';

class DonationWidget extends ConsumerStatefulWidget {
  const DonationWidget({super.key});

  @override
  ConsumerState<DonationWidget> createState() => DonationWidgetState();
}

class DonationWidgetState extends ConsumerState<DonationWidget> {
  @override
  Widget build(BuildContext context) {
    final donationPage = ref.watch(fetchDonationPageProvider);
    final snoozeState = ref.watch(donationSnoozeProvider);

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
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 500),
                child: snoozeState.isSnoozed
                    ? _buildCompactThankYouWidget(context)
                    : _buildDonationWidget(
                        context,
                        donationPageModel,
                        isSnoozed: false,
                      ),
              ),
              height20,
              const FeedbackWidget(),
            ],
          );
        },
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
    DonationPageModel donationPageModel, {
    required bool isSnoozed,
  }) {
    final footerColor = donationPageModel.cardTextColor != null
        ? parseColor(donationPageModel.cardTextColor!)
        : Colors.white.withValues(alpha: 0.85);

    return HomeGradientBorder(
      backgroundColor: context.brandPurple,
      borderRadius: 14,
      borderWidth: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      donationPageModel.title ?? 'Support Medito',
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontFamily: sourceSerif,
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                            color: Colors.white,
                          ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.donationInfo,
                  icon: MeditoIcon(
                    assetName: MeditoIcons.help,
                    size: 20,
                    color: Colors.white,
                  ),
                  onPressed: () => _showDonationInfoDialog(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              donationPageModel.text ??
                  AppLocalizations.of(
                    context,
                  )!.meditoReliesOnYourDonationsToSurvive,
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildButtonRow(donationPageModel.buttons, context),
            ),
            if (donationPageModel.footerText != null)
              Padding(
                padding: const EdgeInsets.only(top: 14.0, right: 8),
                child: Text(
                  donationPageModel.footerText!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: footerColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactThankYouWidget(BuildContext context) {
    return HomeGradientBorder(
      backgroundColor: context.brandPurple,
      borderRadius: 14,
      borderWidth: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context)!.thankYouForYourSupport,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: sourceSerif,
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context)!.donorSupportMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => handleNavigation(
                  TypeConstants.route,
                  [RouteConstants.donation],
                  context,
                  ref: ref,
                  sourceRouteName:
                      FirebaseAnalyticsService.paywallSourceEndScreen,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.donateAgain,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDonationInfoDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return MeditoDialog(
          title: AppLocalizations.of(context)!.donationInfoTitle,
          content: SingleChildScrollView(
            child: MeditoDialogBody(
              AppLocalizations.of(context)!.donationInfoMessage,
            ),
          ),
          actions: [
            MeditoDialogSecondaryButton(
              label: AppLocalizations.of(context)!.cancel,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            MeditoDialogPrimaryButton(
              label: AppLocalizations.of(context)!.hideForNow,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _snoozeDonationAsk(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _snoozeDonationAsk(BuildContext context) async {
    try {
      await ref.read(donationSnoozeProvider.notifier).snoozeForDays(30);
      if (context.mounted) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.donationAskHiddenMessage,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, AppLocalizations.of(context)!.anErrorOccurred);
      }
    }
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
                foregroundColor: context.brandPurple,
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
                backgroundColor: context.brandPurple,
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
