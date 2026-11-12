import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'medito_text.dart';

/// Material's text slots filled from the app's type scale ([MeditoText]), so
/// stock widgets match. App code reads styles from `context.text` instead.
TextTheme meditoTextTheme(BuildContext context, [ThemeMode? themeMode]) {
  final brightness = MediaQuery.of(context).platformBrightness;
  final isDark =
      themeMode == ThemeMode.dark ||
      (themeMode == ThemeMode.system && brightness == Brightness.dark);

  return MeditoText.forBrightness(
    isDark ? Brightness.dark : Brightness.light,
  ).toTextTheme();
}

MarkdownStyleSheet buildMarkdownStyleSheet(BuildContext context) {
  return MarkdownStyleSheet.fromTheme(Theme.of(context));
}
