import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      data: (DonationPageModel donationPageModel) =>
          _buildDonationWidget(context, donationPageModel),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorWidget(String err) {
    return Container(
      height: 200,
      child: Center(child: Text(err)),
    );
  }

  Widget _buildDonationWidget(
    BuildContext context,
    DonationPageModel donationPageModel,
  ) {
    final textColor = parseColor(donationPageModel.colorText);
    var bodyLarge = Theme.of(context).textTheme.bodyLarge;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: parseColor(donationPageModel.colorBackground),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Text(
            donationPageModel.title ?? StringConstants.didYouKnow,
            textAlign: TextAlign.center,
            style: bodyLarge?.copyWith(fontFamily: SourceSerif, fontSize: 22),
          ),
          SizedBox(height: 8),
          Text(
            donationPageModel.text ??
                StringConstants.meditoReliesOnYourDonationsToSurvive,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: textColor,
            ),
          ),
          height20,
          Container(
            height: 48,
            width: MediaQuery.of(context).size.width,
            child: LoadingButtonWidget(
              onPressed: () => handleNavigation(
                donationPageModel.ctaType,
                [donationPageModel.ctaPath],
                context,
              ),
              btnText: donationPageModel.ctaTitle ?? StringConstants.donateNow,
              bgColor: ColorConstants.walterWhite,
              textColor: parseColor(donationPageModel.colorBackground),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              isLoading: false,
              borderRadius: 24,
            ),
          ),
        ],
      ),
    );
  }
}
