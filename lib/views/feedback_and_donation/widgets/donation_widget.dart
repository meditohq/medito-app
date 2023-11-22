import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class DonationWidget extends StatelessWidget {
  final DonationModel donationModel;
  const DonationWidget({super.key, required this.donationModel});

  @override
  Widget build(BuildContext context) {
    var bodyLarge = Theme.of(context).textTheme.bodyLarge;
    var bgColor = parseColor(donationModel.colorBackground);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: parseColor(donationModel.colorBackground),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Text(
            donationModel.title,
            style: bodyLarge?.copyWith(fontFamily: DmSerif, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          height8,
          Text(
            donationModel.text,
            style: bodyLarge?.copyWith(
              fontFamily: DmSans,
              fontSize: 16,
              color: parseColor(donationModel.colorText),
            ),
            textAlign: TextAlign.center,
          ),
          height20,
          Container(
            height: 48,
            width: MediaQuery.of(context).size.width,
            child: LoadingButtonWidget(
              onPressed: () => handleNavigation(donationModel.ctaType, [
                donationModel.ctaPath,
              ]),
              btnText: donationModel.ctaTitle,
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
}
