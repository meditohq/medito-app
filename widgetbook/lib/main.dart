import 'package:flutter/material.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' show App;

import 'main.directories.g.dart';

void main() {
  runApp(const WidgetbookApp());
}

@App()
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: directories,
      addons: [
        ThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Dark', data: ThemeData(brightness: Brightness.dark)),
            WidgetbookTheme(name: 'Light', data: ThemeData(brightness: Brightness.light)),
          ],
          initialTheme: WidgetbookTheme(name: 'Dark', data: ThemeData(brightness: Brightness.dark)),
          themeBuilder: (context, theme, child) => Theme(
            data: appTheme(
              context,
              theme.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            ),
            child: child,
          ),
        ),
        TextScaleAddon(min: 1.0, max: 2.0),
      ],
    );
  }
}
