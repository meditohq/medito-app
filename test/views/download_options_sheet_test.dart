import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/downloads/download_settings_provider.dart';
import 'package:medito/providers/meditation/download_track_provider.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/views/downloads/widgets/download_options_sheet.dart';
import 'package:medito/views/previews/preview_support.dart';
import 'package:medito/views/settings/manage_defaults_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpDownloads(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.dark,
  Locale locale = const Locale('en'),
  double textScale = 1,
  GlobalKey? captureKey,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: PreviewShell(
        prefs: const {},
        themeMode: mode,
        locale: locale,
        overrides: [
          downloadedTracksProvider.overrideWith((ref) async => <Track>[]),
          upNextProvider.overrideWith(
            (ref) => const AsyncData(
              UpNextData(
                pack: PackModel(id: 'course', title: 'Course'),
                nextSession: null,
                completedCount: 0,
                totalCount: 0,
              ),
            ),
          ),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: tester.view.physicalSize / tester.view.devicePixelRatio,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const DownloadsView(isRoot: true),
        ),
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  testWidgets(
    'overflow opens options and independently persists both choices',
    (tester) async {
      await _pumpDownloads(tester);
      await tester.tap(find.byTooltip('Download options'));
      await _settle(tester);

      expect(find.byType(DownloadOptionsSheet), findsOneWidget);
      final context = tester.element(find.byType(DownloadOptionsSheet));
      final container = ProviderScope.containerOf(context);
      expect(container.read(downloadSettingsProvider).deleteCompleted, isFalse);
      expect(container.read(downloadSettingsProvider).downloadNext, isFalse);
      expect(find.text('Wi-Fi only'), findsNothing);

      await tester.tap(find.text('Download next session'));
      await _settle(tester);
      expect(container.read(downloadSettingsProvider).downloadNext, isTrue);
      expect(container.read(downloadSettingsProvider).deleteCompleted, isFalse);
      expect(find.text('Wi-Fi only'), findsOneWidget);
      expect(container.read(downloadSettingsProvider).useMobileData, isFalse);
    expect(find.textContaining('Continue on Home'), findsOneWidget);

      await tester.tap(find.text('Wi-Fi and mobile data'));
      await _settle(tester);
      await tester.tap(find.text('Delete completed downloads'));
      await _settle(tester);
      await tester.tap(find.text('Download next session'));
      await _settle(tester);
      final settings = container.read(downloadSettingsProvider);
      expect(settings.deleteCompleted, isTrue);
      expect(settings.downloadNext, isFalse);
      expect(settings.useMobileData, isTrue);
      container.invalidate(downloadSettingsProvider);
      expect(container.read(downloadSettingsProvider).deleteCompleted, isTrue);
      expect(container.read(downloadSettingsProvider).downloadNext, isFalse);
      expect(container.read(downloadSettingsProvider).useMobileData, isTrue);

      Navigator.of(context).pop();
      await _settle(tester);
      await tester.tap(find.byTooltip('Download options'));
      await _settle(tester);
      expect(container.read(downloadSettingsProvider).deleteCompleted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'options scroll on a small phone with large text in both themes',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final mode in ThemeMode.values.where(
        (mode) => mode != ThemeMode.system,
      )) {
        await _pumpDownloads(tester, mode: mode, textScale: 1.6);
        await tester.tap(find.byTooltip('Download options'));
        await _settle(tester);
        final context = tester.element(find.byType(DownloadOptionsSheet));
        await ProviderScope.containerOf(context)
            .read(downloadSettingsProvider.notifier)
            .setDownloadNext(true);
        await _settle(tester);
        await tester.ensureVisible(find.text('Wi-Fi and mobile data'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'default voice and length opens existing settings and returns to the sheet',
    (tester) async {
      await _pumpDownloads(tester);
      await tester.tap(find.byTooltip('Download options'));
      await _settle(tester);
      await tester.tap(find.text('Default voice and length'));
      await _settle(tester);
      expect(find.byType(ManageDefaultsScreen), findsOneWidget);
      final context = tester.element(find.byType(ManageDefaultsScreen));
      Navigator.of(context).pop();
      await _settle(tester);
      expect(find.byType(DownloadOptionsSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Opt-in capture of the actual Downloads screen and modal sheet, with the
  // app's bundled fonts. No generated mockup or device/backend is involved.
  testWidgets('capture download options for review', (tester) async {
    const capture = bool.fromEnvironment('CAPTURE_DOWNLOAD_OPTIONS');
    if (!capture) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Google Sans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(
        rootBundle.load('assets/fonts/google-sans/GoogleSans-$weight.ttf'),
      );
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final key = GlobalKey();
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      await _pumpDownloads(tester, mode: mode, captureKey: key);
      await tester.tap(find.byTooltip('Download options'));
      await _settle(tester);
      await tester.tap(find.text('Download next session'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/download-options-${mode.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
