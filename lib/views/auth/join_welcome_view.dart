import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinWelcomeView extends ConsumerWidget {
  const JoinWelcomeView({
    super.key,
    required this.email,
    required this.fromScreen,
  });

  final Screen fromScreen;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var textTheme = Theme.of(context).textTheme;
    var size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
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
                      height: size.height * 0.45,
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
                            StringConstants.thanksForJoining,
                            style: textTheme.headlineMedium?.copyWith(
                              color: ColorConstants.walterWhite,
                              fontFamily: SourceSerif,
                              height: 1.2,
                              fontSize: 24,
                            ),
                          ),
                          height8,
                          Text(
                            StringConstants.welcomeMessage,
                            style: textTheme.bodyMedium?.copyWith(
                              color: ColorConstants.walterWhite,
                              fontFamily: DmSans,
                              height: 1.4,
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
              padding: const EdgeInsets.only(
                  top: 16, bottom: 16, left: 16, right: 16),
              child: _bottomButtons(ref, context),
            ),
            SizedBox(
              height: getBottomPadding(context),
            ),
          ],
        ),
      ),
    );
  }

  Row _bottomButtons(WidgetRef ref, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: 48,
          child: LoadingButtonWidget(
            onPressed: () {
              var auth = ref.read(authProvider.notifier);
              auth.setUserEmail(email);
              if (fromScreen == Screen.splash) {
                context.go(RouteConstants.bottomNavbarPath);
              } else if (fromScreen == Screen.track) {
                context.pop();
                context.pop();
                context.pop();
                context.pop();
              }
            },
            btnText: StringConstants.close,
            bgColor: ColorConstants.walterWhite,
            textColor: ColorConstants.onyx,
          ),
        ),
      ],
    );
  }
}
