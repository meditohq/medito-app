import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/stats_provider.dart';

import '../../../models/events/donation/donation_page_model.dart';
import '../../../providers/donation/donation_page_provider.dart';
import '../../../routes/routes.dart';
import '../../../utils/utils.dart';
import '../../../widgets/buttons/loading_button_widget.dart';

class DonationWidget extends ConsumerWidget {
  const DonationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationPage = ref.watch(fetchDonationPageProvider);

    return donationPage.when(
      loading: () => _buildLoadingWidget(),
      error: (err, _) => _buildErrorWidget(err.toString()),
      data: (DonationPageModel donationPageModel) {
        return _buildDonationWidget(context, donationPageModel);
      },
    );
  }

  Widget _buildLoadingWidget() {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorWidget(String err) {
    return SizedBox(
      height: 200,
      child: Center(child: Text(err)),
    );
  }

  Widget _buildDonationWidget(
    BuildContext context,
    DonationPageModel donationPageModel,
  ) {
    final textColor = donationPageModel.cardTextColor != null
        ? parseColor(donationPageModel.cardTextColor!)
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: donationPageModel.cardBackgroundColor != null
            ? parseColor(donationPageModel.cardBackgroundColor!)
            : ColorConstants.lightPurple,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Conditionally render the title
          if (donationPageModel.title != null)
            Text(
              donationPageModel.title!,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: Teachers,
                fontSize: 22,
                color: textColor,
              ),
            ),
          if (donationPageModel.title != null) const SizedBox(height: 8),
          Text(
            donationPageModel.text ??
                StringConstants.meditoReliesOnYourDonationsToSurvive,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              color: textColor,
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
                textAlign: TextAlign.left,
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
            child: LoadingButtonWidget(
              onPressed: () => handleNavigation(
                button.type,
                [button.path],
                context,
              ),
              btnText: button.title ?? StringConstants.donateNow,
              bgColor: parseColor(button.backgroundColor),
              textColor: parseColor(button.textColor),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              isLoading: false,
              borderRadius: 24,
            ),
          ),
        ],
      );
    } else {
      for (int i = 0; i < buttons.length; i++) {
        ButtonModel button = buttons[i];

        buttonWidgets.add(
          Expanded(
            child: LoadingButtonWidget(
              onPressed: () => handleNavigation(
                button.type,
                [button.path],
                context,
              ),
              btnText: button.title ?? StringConstants.donateNow,
              bgColor: parseColor(button.backgroundColor),
              textColor: parseColor(button.textColor),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              isLoading: false,
              borderRadius: 24,
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
