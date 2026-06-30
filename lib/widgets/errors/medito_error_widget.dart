import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/error_widget/report_cooldown_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/views/splash_view.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/repositories/auth/auth_repository.dart';

import '../../views/downloads/downloads_view.dart';
import 'package:medito/utils/utils.dart';

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

  String _getErrorMessage(BuildContext context) {
    return switch (error) {
      NetworkConnectionError() => AppLocalizations.of(
        context,
      )!.errorNoInternetMessage,
      TimeoutError() => AppLocalizations.of(context)!.errorTimeoutMessage,
      UnauthorizedError() => AppLocalizations.of(
        context,
      )!.errorUnauthorizedMessage,
      NotFoundError() => AppLocalizations.of(context)!.errorNotFoundMessage,
      ServerError() => AppLocalizations.of(context)!.errorServerMessage,
      UnknownError() => AppLocalizations.of(context)!.errorUnknownMessage,
      RefreshTokenError() => AppLocalizations.of(
        context,
      )!.errorUnauthorizedMessage,
      _ => AppLocalizations.of(context)!.errorUnknownMessage,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var uiState = ref.watch(
      meditoErrorWidgetProvider(
        MeditoErrorWidgetUIState(
          shouldShowCheckDownloadButton,
          _getErrorMessage(context),
        ),
      ),
    );
    var textStyle = Theme.of(context).textTheme.headlineMedium;

    var mainBody = _mainBody(
      context,
      uiState.message,
      uiState.shouldShowCheckDownloadButton,
      textStyle,
      ref,
    );

    if (isScaffold) {
      return Scaffold(backgroundColor: ColorConstants.ebony, body: mainBody);
    }

    return mainBody;
  }

  SizedBox _mainBody(
    BuildContext context,
    String message,
    bool isShowCheckDownload,
    TextStyle? textStyle,
    WidgetRef ref,
  ) {
    final isCoolingDown = ref.watch(isCoolingDownProvider);

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
                      text: '${AppLocalizations.of(context)!.meanWhileListen} ',
                      style: textStyle,
                    ),
                  if (isShowCheckDownload)
                    TextSpan(
                      text: AppLocalizations.of(
                        context,
                      )!.downloads.toLowerCase(),
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
            if (error is UnauthorizedError || error is RefreshTokenError)
              Column(
                mainAxisSize: MainAxisSize.min,
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
                      child: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 300,
                    child: LoadingButtonWidget(
                      btnText: AppLocalizations.of(context)!.signInAgain,
                      onPressed: () async {
                        final authRepository = ref.read(
                          authRepositorySyncProvider,
                        );
                        await authRepository.signOut();
                        await ref.read(statsManagerProvider).clearAllStats();
                        if (context.mounted) {
                          ref.read(meRefreshProvider)();

                          // Add a small delay to let the me provider refresh before navigation
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );

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
                    ),
                  ),
                ],
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
                      child: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: ElevatedButton(
                      onPressed: () {
                        handleNavigation(TypeConstants.flow, [
                          TypeConstants.downloads,
                        ], context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorConstants.lightPurple,
                        foregroundColor: ColorConstants.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(AppLocalizations.of(context)!.goToDownloads),
                    ),
                  ),
                ],
              ),
            SizedBox(
              width: 300,
              child: TextButton(
                onPressed: isCoolingDown
                    ? null
                    : () {
                        CrashlyticsService().recordAppError(error);
                        ref
                            .read(reportCooldownProvider.notifier)
                            .startCooldown();
                        showSnackBar(
                          context,
                          AppLocalizations.of(context)!.errorReportedMessage,
                        );
                      },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                ),
                child: Text(
                  AppLocalizations.of(context)!.reportError,
                  style: TextStyle(
                    color: isCoolingDown
                        ? ColorConstants.lightPurple.withOpacityValue(0.5)
                        : ColorConstants.lightPurple,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
