import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';

/// The welcome UI used by SplashView, separate from app initialization.
class SplashWelcomeLayout extends StatelessWidget {
  const SplashWelcomeLayout({
    super.key,
    required this.showAccountButtons,
    required this.isSigningIn,
    required this.onGetStarted,
    required this.onSignIn,
  });
  final bool showAccountButtons;
  final bool isSigningIn;
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: constraints.maxWidth >= 700
                  ? constraints.maxHeight * 0.48
                  : 500,
              child: SvgPicture.asset(
                AssetConstants.splashBackground,
                fit: constraints.maxWidth >= 700
                    ? BoxFit.cover
                    : BoxFit.fitWidth,
                alignment: constraints.maxWidth >= 700
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: constraints.maxWidth >= 700
                  ? Alignment.topCenter
                  : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          (constraints.maxWidth >= 700
                              ? constraints.maxHeight * 0.52
                              : constraints.maxHeight) -
                          MediaQuery.of(context).padding.top,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: constraints.maxWidth >= 700
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              left: constraints.maxWidth >= 700 ? 0 : 16,
                              top: 16,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: constraints.maxWidth >= 700
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(
                                      ((0.1).clamp(0.0, 1.0) * 255).round(),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SvgPicture.asset(
                                    AssetConstants.icLogo,
                                    width: 40,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  AppLocalizations.of(context)!.appName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        fontSize: 24,
                                        color: Colors.white,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.splashHeadline,
                                  textAlign: constraints.maxWidth >= 700
                                      ? TextAlign.center
                                      : TextAlign.start,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                        color: Colors.white,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: constraints.maxWidth >= 700
                                      ? Alignment.center
                                      : Alignment.centerLeft,
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.splashSubtitle,
                                    textAlign: constraints.maxWidth >= 700
                                        ? TextAlign.center
                                        : TextAlign.start,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (constraints.maxWidth >= 700)
                            const SizedBox(height: 28)
                          else
                            const Spacer(),
                          if (showAccountButtons) ...[
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                32,
                                0,
                                32,
                                constraints.maxWidth >= 700 ? 24 : 250,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Primary: start straight away as a
                                  // guest; the account choice can wait.
                                  SizedBox(
                                    width: constraints.maxWidth >= 700
                                        ? 360
                                        : double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        textStyle: const TextStyle(
                                          fontFamily: googleSans,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      onPressed: isSigningIn
                                          ? null
                                          : onGetStarted,
                                      child: isSigningIn
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.getStarted,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Secondary: quiet link for returning
                                  // users to sign in.
                                  TextButton(
                                    onPressed: isSigningIn ? null : onSignIn,
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.splashSignInOrSignUp,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ), // IntrinsicHeight
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
