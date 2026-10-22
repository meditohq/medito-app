import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/constants.dart';

/// Both Flutter startup stages use a full-window frame. Android can carry
/// keyboard insets from the launcher/previous activity into the first frames;
/// resizing for those insets would move the logo up and then back down.
class LaunchSplashFrame extends StatelessWidget {
  const LaunchSplashFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    extendBody: true,
    backgroundColor: Colors.black,
    body: child,
  );
}

/// Matches the native launch screens, regardless of the saved app theme.
class LaunchSplash extends StatelessWidget {
  const LaunchSplash({super.key});

  static const systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(
          child: Center(
            child: SvgPicture.asset(
              AssetConstants.icLogo,
              width: 168,
              height: 168,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
