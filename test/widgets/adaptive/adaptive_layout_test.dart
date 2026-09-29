import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/views/bottom_navigation/widgets/medito_nav_bar.dart';
import 'package:medito/views/bottom_navigation/widgets/medito_sidebar.dart';
import 'package:medito/widgets/adaptive/adaptive_content.dart';
import 'package:medito/widgets/adaptive/adaptive_home_sections.dart';

const destinations = [
  MeditoNavItem(icon: MeditoIcons.home, label: 'Home'),
  MeditoNavItem(icon: MeditoIcons.book, label: 'Explore'),
  MeditoNavItem(icon: MeditoIcons.search, label: 'Search'),
  MeditoNavItem(icon: MeditoIcons.settings, label: 'Settings'),
];

Widget app(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'GoogleSans',
    scaffoldBackgroundColor: const Color(0xff171717),
    colorScheme: const ColorScheme.dark(primary: Colors.white),
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'sidebar destinations remain reachable with large text and short height',
    (tester) async {
      tester.view.physicalSize = const Size(760, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = -1;
      await tester.pumpWidget(
        app(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(760, 320),
              textScaler: TextScaler.linear(2),
            ),
            child: MeditoSidebar(
              extended: false,
              items: destinations,
              selectedIndex: 0,
              onSelected: (i) => selected = i,
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      expect(selected, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home sections preserve state and reading order across resizing',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final field = TextEditingController();
      addTearDown(field.dispose);
      await tester.pumpWidget(
        app(
          AdaptiveHomeSections(
            children: [
              TextField(key: const ValueKey('first'), controller: field),
              const Text('Second', key: ValueKey('second')),
            ],
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Keep my place');
      final originalState = tester.state(find.byType(TextField));
      expect(tester.getTopLeft(find.text('Second')).dx, 0);
      expect(
        tester.getTopLeft(find.text('Second')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TextField)).dy),
      );
      tester.view.physicalSize = const Size(600, 800);
      await tester.pump();
      expect(field.text, 'Keep my place');
      expect(tester.state(find.byType(TextField)), same(originalState));
      expect(tester.getTopLeft(find.text('Second')).dx, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pane size excludes sidebar width', (tester) async {
    Size? pane;
    await tester.pumpWidget(
      app(
        Row(
          children: [
            const SizedBox(width: 200),
            Expanded(
              child: AdaptiveContent(
                child: Builder(
                  builder: (context) {
                    pane = MediaQuery.sizeOf(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    expect(pane!.width, 600);
  });
}
