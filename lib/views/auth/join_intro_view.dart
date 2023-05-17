import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinIntroView extends ConsumerWidget {
  const JoinIntroView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    StringConstants.joinTheMeditoFamily,
                    style: textTheme.headlineMedium?.copyWith(
                      color: ColorConstants.walterWhite,
                      fontFamily: ClashDisplay,
                      height: 2,
                      fontSize: 24,
                    ),
                  ),
                  for (int i = 0; i < joinBenefitList.length; i++)
                    Text(
                      joinBenefitList[i],
                      style: textTheme.labelMedium?.copyWith(
                        color: ColorConstants.walterWhite,
                        fontFamily: ClashDisplay,
                        height: 1.8,
                        fontSize: 16,
                      ),
                    ),
                  Text(
                    StringConstants.itsFreeForever,
                    style: textTheme.headlineSmall?.copyWith(
                      color: ColorConstants.walterWhite,
                      fontFamily: ClashDisplay,
                      height: 3,
                      fontSize: 16,
                    ),
                  ),
                  height8,
                  Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      LoadingButtonWidget(
                        onPressed: () {
                          var auth = ref.read(authProvider);
                          auth.setIsAGuest(true);
                          context.go(RouteConstants.homePath);
                        },
                        btnText: StringConstants.maybeLater,
                      ),
                      width8,
                      LoadingButtonWidget(
                        onPressed: () {
                          context.push(RouteConstants.joinEmailPath);
                        },
                        btnText: StringConstants.joinNow,
                        bgColor: ColorConstants.walterWhite,
                        textColor: ColorConstants.greyIsTheNewGrey,
                      ),
                    ],
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
