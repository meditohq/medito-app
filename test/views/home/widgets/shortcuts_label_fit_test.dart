import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/models.dart';
import 'package:medito/views/home/widgets/shortcuts/shortcuts_items_widget.dart';

/// Sweeps phone widths and text sizes to check that a shortcut label is never
/// split in the middle of a word ("Download" / "s") and never loses text to an
/// ellipsis, using the real Google Sans metrics.
void main() {
  const titles = [
    'Your Daily',
    'Downloads',
    'Timer',
    'Sleep',
    'Challenges',
    'Emergency',
    'Favorites',
    'Course',
    // Longer labels, as translations tend to be.
    'Herausforderungen',
    'Téléchargements',
    'Meditación diaria',
    'Notfallmeditation',
  ];

  setUpAll(() async {
    final loader = FontLoader('Google Sans');
    for (final file in [
      'GoogleSans-Regular.ttf',
      'GoogleSans-Medium.ttf',
      'GoogleSans-SemiBold.ttf',
    ]) {
      final bytes = File('assets/fonts/google-sans/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  testWidgets('labels stay whole at every phone width and text size', (
    tester,
  ) async {
    final data = [
      for (final title in titles)
        ShortcutsModel(
          id: title,
          type: 'pack',
          title: title,
          path: 'packs/x',
          icon: 'duoTimer',
        ),
    ];

    final failures = <String>[];
    var smallestScale = 1.0;
    var smallestScaleCase = '';
    var smallestFontPx = double.infinity;
    var smallestFontCase = '';

    for (var width = 280.0; width <= 600.0; width += 4) {
      // 0.8–1.5 is the range the app clamps to; 2.0 covers the clamp being
      // lifted one day.
      for (final scale in [0.8, 1.0, 1.15, 1.3, 1.4, 1.5, 2.0]) {
        tester.view.physicalSize = Size(width, 3000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 3000),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: ShortcutsItemsWidget(data: data),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$width @ $scale');

        for (final title in titles) {
          final where = '"$title" at ${width.toInt()}dp, ${scale}x';
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(title),
          );
          if (paragraph.didExceedMaxLines) {
            failures.add('ellipsised: $where');
          }
          // A word is broken when its glyph boxes sit on more than one line.
          for (final match in RegExp(r'\S+').allMatches(title)) {
            final tops = paragraph
                .getBoxesForSelection(
                  TextSelection(
                    baseOffset: match.start,
                    extentOffset: match.end,
                  ),
                )
                .map((box) => box.top.round())
                .toSet();
            if (tops.length > 1) failures.add('split mid-word: $where');
          }
          // How far FittedBox had to shrink the label, if at all.
          final painted = tester.getRect(find.text(title)).width;
          final shrink = paragraph.size.width == 0
              ? 1.0
              : (painted / paragraph.size.width).clamp(0.0, 1.0);
          if (shrink < smallestScale) {
            smallestScale = shrink;
            smallestScaleCase = where;
          }
          final fontPx = 14 * scale * shrink;
          if (fontPx < smallestFontPx) {
            smallestFontPx = fontPx;
            smallestFontCase = where;
          }
        }
      }
    }
    addTearDown(tester.view.reset);

    // ignore: avoid_print
    print(
      'most shrink: ${smallestScale.toStringAsFixed(2)} for $smallestScaleCase',
    );
    // ignore: avoid_print
    print(
      'smallest text: ${smallestFontPx.toStringAsFixed(1)}px for '
      '$smallestFontCase',
    );
    expect(failures, isEmpty, reason: failures.take(20).join('\n'));
  });
}
