import 'package:Medito/constants/constants.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MissingRouteView extends StatelessWidget {
  const MissingRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    var textStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: 16,
          color: ColorConstants.walterWhite,
          fontFamily: SourceSerif,
        );

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: padding16,
            vertical: padding16,
          ),
          child: Center(
            child: RichText(
              text: TextSpan(
                text: StringConstants.unableToLocateTheRoute,
                style: textStyle,
                children: <TextSpan>[
                  TextSpan(
                    text: ' ${StringConstants.pleaseClick} ',
                    style: textStyle,
                  ),
                  TextSpan(
                    text: '${StringConstants.home.toLowerCase()}',
                    style: textStyle?.copyWith(
                      decoration: TextDecoration.underline,
                      color: ColorConstants.lightPurple,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap =
                          () => context.go(RouteConstants.bottomNavbarPath),
                  ),
                  TextSpan(
                    text: ' ${StringConstants.toReturnToTheMainMenu} ',
                    style: textStyle,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
