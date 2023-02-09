import 'package:Medito/constants/constants.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ErrorComponent extends StatelessWidget {
  const ErrorComponent({
    Key? key,
    required this.onTap,
    required this.message,
  }) : super(key: key);
  final void Function() onTap;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _richText(
            context,
            message,
            ' Retry',
            onTap: onTap,
          ),
        ],
      ),
    );
  }

  RichText _richText(BuildContext context, String title, String text,
      {void Function()? onTap}) {
    return RichText(
      text: TextSpan(
        text: title,
        style: Theme.of(context).textTheme.headline5?.copyWith(
            fontSize: 18,
            color: ColorConstants.newGrey,
            letterSpacing: -0.3,
            fontWeight: FontWeight.w400),
        children: <TextSpan>[
          TextSpan(
              text: text,
              style: Theme.of(context).textTheme.headline5?.copyWith(
                  fontSize: 18,
                  color: ColorConstants.link,
                  letterSpacing: -0.3,
                  fontWeight: FontWeight.w400),
              recognizer: TapGestureRecognizer()..onTap = onTap)
        ],
      ),
    );
  }
}
