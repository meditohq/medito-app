import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinIntroView extends ConsumerWidget {
  const JoinIntroView({super.key, required this.fromScreen});

  final Screen fromScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var size = MediaQuery.of(context).size;
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
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    AssetConstants.join,
                    height: size.height * 0.44,
                    width: size.width,
                    fit: BoxFit.cover,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 24, bottom: 16, left: 16, right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          StringConstants.joinTheMeditoFamily,
                          style: textTheme.headlineMedium?.copyWith(
                            color: ColorConstants.walterWhite,
                            fontFamily: SourceSerif,
                            height: 1.2,
                            fontSize: 24,
                          ),
                        ),
                        height8,
                        _benefitPoints(joinBenefitList, textTheme),
                        height24,
                        Text(
                          StringConstants.itsFreeForever,
                          style: textTheme.headlineSmall?.copyWith(
                            color: ColorConstants.walterWhite,
                            fontFamily: DmSans,
                            fontSize: 16,
                          ),
                        ),
                        height8,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(top: 16, bottom: 16, left: 16, right: 16),
            child: _bottomButtons(ref, context),
          ),
          SizedBox(
            height: getBottomPadding(context),
          ),
        ],
      ),
    );
  }

  Column _benefitPoints(List<String> joinBenefitList, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: joinBenefitList
          .map((e) => Text(
                e,
                style: textTheme.labelMedium?.copyWith(
                  color: ColorConstants.walterWhite,
                  fontFamily: DmSans,
                  height: 1.6,
                  fontSize: 16,
                ),
              ))
          .toList(),
    );
  }

  Row _bottomButtons(WidgetRef ref, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: 48, // Specify the desired height of the button
          child: LoadingButtonWidget(
            onPressed: () => _handleMaybeLater(ref, context),
            btnText: StringConstants.maybeLater,
          ),
        ),
        width8,
        Container(
          height: 48, // Specify the desired height of the button
          child: LoadingButtonWidget(
            onPressed: () {
              var params = JoinRouteParamsModel(screen: fromScreen);
              context.push(
                RouteConstants.joinEmailPath,
                extra: params,
              );
            },
            btnText: StringConstants.joinNow,
            bgColor: ColorConstants.walterWhite,
            textColor: ColorConstants.onyx,
          ),
        ),
      ],
    );
  }

  void _handleMaybeLater(WidgetRef ref, BuildContext context) {
    var auth = ref.read(authProvider);
    auth.setIsAGuest(true);
    if (fromScreen == Screen.track) {
      context.pop();
    } else {
      context.go(RouteConstants.bottomNavbarPath);
    }
  }
}
