import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/widgets/launch_splash.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('launch appearance stays consistent in $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(800, 600),
              padding: EdgeInsets.only(top: 59, bottom: 34),
            ),
            child: LaunchSplash(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final splash = find.byType(LaunchSplash);
      final background = tester.widget<ColoredBox>(
        find.descendant(of: splash, matching: find.byType(ColoredBox)),
      );
      expect(background.color, Colors.black);

      // Native launch screens center in the whole window, including insets.
      final logo = find.byType(SvgPicture);
      expect(tester.getSize(logo), const Size(168, 168));
      expect(tester.getCenter(logo), tester.getCenter(splash));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: splash,
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.light);
      expect(overlay.value.systemNavigationBarIconBrightness, Brightness.light);
      expect(tester.takeException(), isNull);
    });
  }
}
