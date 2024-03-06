import 'package:Medito/constants/constants.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DonationWidget extends ConsumerWidget {
  const DonationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var bodyLarge = Theme.of(context).textTheme.bodyLarge;
    var bgColor = ColorConstants.lightPurple;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: bgColor,
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Text(
            StringConstants.didYouKnow,
            style: bodyLarge?.copyWith(fontFamily: SourceSerif, fontSize: 22),
            textAlign: TextAlign.center,
          ),
          height8,
          Text(
            StringConstants.meditoReliesOnYourDonationsToSurvive,
            style: bodyLarge?.copyWith(
              fontFamily: DmSans,
              fontSize: 16,
              color: ColorConstants.walterWhite,
            ),
            textAlign: TextAlign.center,
          ),
          height20,
          Container(
            height: 48,
            width: MediaQuery.of(context).size.width,
            child: LoadingButtonWidget(
              onPressed: () => _handleDonatePress(),
              btnText: StringConstants.donateNow,
              bgColor: ColorConstants.walterWhite,
              textColor: bgColor,
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

  void _handleDonatePress() {
    handleNavigation(
      StringConstants.meditoUrl,
      [],
    );
  }
}
