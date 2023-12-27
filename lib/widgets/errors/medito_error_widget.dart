import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MeditoErrorWidget extends ConsumerWidget {
  const MeditoErrorWidget({
    Key? key,
    required this.onTap,
    required this.message,
    this.isLoading = false,
    this.isShowCheckDownload = false,
    this.isScaffold = true,
  }) : super(key: key);
  final void Function() onTap;
  final String message;
  final bool isLoading;
  final bool isShowCheckDownload;
  final bool isScaffold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = ref.watch(meditoErrorWidgetProvider(
      MeditoErrorWidgetUIState(isShowCheckDownload, message),
    ));
    var textStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: 16,
          color: ColorConstants.walterWhite,
          fontFamily: SourceSerif,
        );

    var mainBody = _mainBody(
      context,
      provider.message,
      provider.shouldShowCheckDownload,
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
    bool isShowCheckDownload,
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
                  if (isShowCheckDownload)
                    TextSpan(
                      text: '${StringConstants.meanWhileListen} ',
                      style: textStyle,
                    ),
                  if (isShowCheckDownload)
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
