import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/auth_button_widget.dart';

class JoinWelcomeView extends StatelessWidget {
  const JoinWelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    var joinBenefitList = [
      StringConstants.joinBenefits1,
      StringConstants.joinBenefits2,
      StringConstants.joinBenefits3,
      StringConstants.joinBenefits4,
      StringConstants.joinBenefits5,
    ];

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(AssetConstants.join),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    StringConstants.welcomeToTheMeditoFamily,
                    style: textTheme.headlineMedium?.copyWith(
                      color: ColorConstants.walterWhite,
                      fontFamily: ClashDisplay,
                      height: 1.2,
                      fontSize: 24,
                    ),
                  ),
                  height8,
                  Text(
                    StringConstants.welcomeMessage,
                    style: textTheme.bodyMedium?.copyWith(
                      color: ColorConstants.walterWhite,
                      fontFamily: ClashDisplay,
                      height: 1.6,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    StringConstants.thanksForJoining,
                    style: textTheme.headlineSmall?.copyWith(
                      color: ColorConstants.walterWhite,
                      fontFamily: ClashDisplay,
                      height: 3,
                      fontSize: 16,
                    ),
                  ),
                  height8,
                  Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: AuthButtonWidget(
                      onPressed: () {
                        context.push(RouteConstants.homePath);
                      },
                      btnText: StringConstants.close,
                      bgColor: ColorConstants.walterWhite,
                      textColor: ColorConstants.greyIsTheNewGrey,
                    ),
                  ),
                  height8,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
