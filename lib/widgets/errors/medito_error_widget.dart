import 'package:Medito/constants/constants.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MeditoErrorWidget extends StatelessWidget {
  const MeditoErrorWidget({
    Key? key,
    required this.onTap,
    required this.message,
    this.isLoading = false,
    this.showCheckDownloadText = false,
    this.isScaffold = true,
  }) : super(key: key);
  final void Function() onTap;
  final String message;
  final bool isLoading;
  final bool showCheckDownloadText;
  final bool isScaffold;

  @override
  Widget build(BuildContext context) {
    var splittedMessage = message.split(': ');
    var _showCheckDownloadText = showCheckDownloadText;

    if (splittedMessage.length > 1) {
      var statusCode = int.parse(splittedMessage[1]);
      if (statusCode >= 500 && statusCode < 600) {
        _showCheckDownloadText = true;
      }
    }
    var textStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: 16,
          color: ColorConstants.walterWhite,
          fontFamily: SourceSerif,
        );

    var mainBody = _mainBody(
      context,
      splittedMessage[0],
      _showCheckDownloadText,
      textStyle,
    );

    if (isScaffold) {
      return Scaffold(
        backgroundColor: ColorConstants.ebony,
        body: mainBody,
      );
    }

    return mainBody;
  }

  SizedBox _mainBody(
    BuildContext context,
    String message,
    bool showCheckDownloadText,
    TextStyle? textStyle,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: padding16,
          vertical: padding16,
        ),
        child: Column(
          mainAxisSize: isScaffold ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              text: TextSpan(
                text: '$message. ',
                style: textStyle,
                children: <TextSpan>[
                  if (showCheckDownloadText)
                    TextSpan(
                      text: '${StringConstants.meanWhileCheck} ',
                      style: textStyle,
                    ),
                  if (showCheckDownloadText)
                    TextSpan(
                      text: '${StringConstants.downloads.toLowerCase()}',
                      style: textStyle?.copyWith(
                        decoration: TextDecoration.underline,
                        color: ColorConstants.lightPurple,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap =
                            () => context.push(RouteConstants.downloadsPath),
                    ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            height16,
            LoadingButtonWidget(
              btnText: StringConstants.retry,
              onPressed: onTap,
              isLoading: isLoading,
              bgColor: ColorConstants.walterWhite,
              textColor: ColorConstants.onyx,
            ),
          ],
        ),
      ),
    );
  }
}
