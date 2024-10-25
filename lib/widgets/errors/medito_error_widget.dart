import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../views/downloads/downloads_view.dart';

class MeditoErrorWidget extends ConsumerWidget {
  const MeditoErrorWidget({
    Key? key,
    required this.onTap,
    required this.message,
    this.isLoading = false,
    this.shouldShowCheckDownloadButton = false,
    this.isScaffold = true,
  }) : super(key: key);
  final void Function() onTap;
  final String message;
  final bool isLoading;
  final bool shouldShowCheckDownloadButton;
  final bool isScaffold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var uiState = ref.watch(meditoErrorWidgetProvider(
      MeditoErrorWidgetUIState(shouldShowCheckDownloadButton, message),
    ));
    var textStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: 16,
          color: ColorConstants.white,
          fontFamily: sourceSerif,
        );

    var mainBody = _mainBody(
      context,
      uiState.message,
      uiState.shouldShowCheckDownloadButton,
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
                      text: StringConstants.downloads.toLowerCase(),
                      style: textStyle?.copyWith(
                        decoration: TextDecoration.underline,
                        color: ColorConstants.lightPurple,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const DownloadsView(),
                              ),
                            ),
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
              bgColor: ColorConstants.white,
              textColor: ColorConstants.onyx,
            ),
          ],
        ),
      ),
    );
  }
}
