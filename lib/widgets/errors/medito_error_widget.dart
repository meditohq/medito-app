import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:medito/views/splash_view.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/repositories/auth/auth_repository.dart';

import '../../views/downloads/downloads_view.dart';

class MeditoErrorWidget extends ConsumerWidget {
  const MeditoErrorWidget({
    super.key,
    required this.onTap,
    required this.error,
    this.isLoading = false,
    this.shouldShowCheckDownloadButton = false,
    this.isScaffold = true,
  });

  final void Function() onTap;
  final AppError error;
  final bool isLoading;
  final bool shouldShowCheckDownloadButton;
  final bool isScaffold;

  String _getErrorMessage() {
    return switch (error) {
      NoInternetError() => StringConstants.errorNoInternetMessage,
      TimeoutError() => StringConstants.errorTimeoutMessage,
      UnauthorizedError() => StringConstants.errorUnauthorizedMessage,
      NotFoundError() => StringConstants.errorNotFoundMessage,
      ServerError() => StringConstants.errorServerMessage,
      UnknownError() => StringConstants.errorUnknownMessage,
      RefreshTokenError() => StringConstants.errorUnauthorizedMessage,
      _ => StringConstants.errorUnknownMessage,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var uiState = ref.watch(meditoErrorWidgetProvider(
      MeditoErrorWidgetUIState(
          shouldShowCheckDownloadButton, _getErrorMessage()),
    ));
    var textStyle = Theme.of(context).textTheme.headlineMedium;

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
            if (error is UnauthorizedError)
              LoadingButtonWidget(
                btnText: StringConstants.signInAgain,
                onPressed: () async {
                  final authRepository = ProviderScope.containerOf(context)
                      .read(authRepositorySyncProvider);
                  await authRepository.signOut();
                  await StatsManager().clearAllStats();
                  if (context.mounted) {
                    final ref = ProviderScope.containerOf(context);
                    ref.read(meRefreshProvider)();

                    // Add a small delay to let the me provider refresh before navigation
                    await Future.delayed(const Duration(milliseconds: 100));

                    if (context.mounted) {
                      // Navigate to splash screen from UI
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const SplashView(),
                        ),
                        (route) => false,
                      );
                    }
                  }
                },
                isLoading: isLoading,
                bgColor: ColorConstants.lightPurple,
                textColor: ColorConstants.onyx,
              )
            else
              Column(
                spacing: 4,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(StringConstants.retry),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: ElevatedButton(
                      onPressed: () {
                        handleNavigation(
                          TypeConstants.flow,
                          [TypeConstants.downloads],
                          context,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorConstants.lightPurple,
                        foregroundColor: ColorConstants.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(StringConstants.goToDownloads),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
