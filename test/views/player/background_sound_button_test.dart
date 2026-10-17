import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/background_sounds/background_sounds_model.dart';
import 'package:medito/providers/background_sounds/background_sounds_notifier.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/background_sound_button.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/bg_sound_widget.dart';
import 'package:medito/views/previews/preview_support.dart' show MemoryPrefs;

const _rain = BackgroundSoundsModel(
  id: 'rain',
  title: 'Rain',
  path: 'rain.mp3',
  duration: 1000,
);
const _hint = 'Tap here to change background sounds or bells.';

Finder get _soundButton => find
    .ancestor(of: find.byType(BgSoundWidget), matching: find.byType(IconButton))
    .first;

class _Sounds extends BackgroundSoundsNotifier {
  _Sounds({this.sound, this.bells = false});

  final BackgroundSoundsModel? sound;
  final bool bells;

  @override
  BackgroundSoundsState build() =>
      BackgroundSoundsState(selectedBgSound: sound, bellsEnabled: bells);

  void select(BackgroundSoundsModel? value) {
    state = state.copyWith(selectedBgSound: value);
  }

  void enableBells(bool enabled) {
    state = state.copyWith(bellsEnabled: enabled);
  }
}

Future<void> _mount(
  WidgetTester tester,
  MemoryPrefs prefs,
  _Sounds sounds, {
  VoidCallback? onPressed,
  double textScale = 1,
}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backgroundSoundsNotifierProvider.overrideWith(() => sounds),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: ColorConstants.onyx,
          body: const SizedBox.expand(),
          bottomNavigationBar: SafeArea(
            child: Align(
              heightFactor: 1,
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: BackgroundSoundButton(
                  isBackgroundSoundSelected: false,
                  onPressed: onPressed ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _waitForHint(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('counts enabling mid-visit once; shows on the next visit only', (
    tester,
  ) async {
    final prefs = MemoryPrefs({});
    final sounds = _Sounds();
    await _mount(tester, prefs, sounds);
    await _waitForHint(tester);
    expect(prefs.getInt(SharedPreferenceConstants.bgSoundPlayerVisits), isNull);

    sounds.select(_rain);
    await tester.pump();
    sounds.select(null);
    sounds.select(_rain);
    await _waitForHint(tester);
    expect(prefs.getInt(SharedPreferenceConstants.bgSoundPlayerVisits), 1);
    expect(find.text(_hint), findsNothing);

    // Recreating the provider scope also models restarting the app: the visit
    // count and the shown flag live in preferences, not in a provider instance.
    await _mount(tester, prefs, _Sounds(sound: _rain));
    expect(find.text(_hint), findsNothing);
    await _waitForHint(tester);
    expect(find.text(_hint), findsOneWidget);
    expect(
      prefs.getBool(SharedPreferenceConstants.bgSoundChangeHintShown),
      true,
    );

    final hintRect = tester.getRect(find.text(_hint));
    final buttonRect = tester.getRect(_soundButton);
    expect(hintRect.bottom, lessThan(buttonRect.top));
    expect(hintRect.left, greaterThanOrEqualTo(16));
    expect(hintRect.right, lessThanOrEqualTo(784));

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.text(_hint), findsNothing);
    await _mount(tester, prefs, _Sounds(sound: _rain));
    await _waitForHint(tester);
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('silence and None without bells do not count', (tester) async {
    final prefs = MemoryPrefs({});
    for (final sound in [null, _rain.copyWith(id: kNoneBackgroundSoundId)]) {
      await _mount(tester, prefs, _Sounds(sound: sound));
      await _waitForHint(tester);
      expect(
        prefs.getInt(SharedPreferenceConstants.bgSoundPlayerVisits),
        isNull,
      );
      expect(find.text(_hint), findsNothing);
    }
  });

  testWidgets(
    'bells alone qualify on the second visit, including legacy bells',
    (tester) async {
      for (final legacy in [false, true]) {
        final prefs = MemoryPrefs({});
        _Sounds bells() =>
            _Sounds(sound: legacy ? kSessionBellsSound : null, bells: !legacy);
        await _mount(tester, prefs, bells());
        await _waitForHint(tester);
        expect(prefs.getInt(SharedPreferenceConstants.bgSoundPlayerVisits), 1);
        expect(find.text(_hint), findsNothing);

        await _mount(tester, prefs, bells());
        await _waitForHint(tester);
        expect(find.text(_hint), findsOneWidget);
        expect(
          prefs.getBool(SharedPreferenceConstants.bgSoundChangeHintShown),
          true,
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('enabling bells during a visit counts once', (tester) async {
    final prefs = MemoryPrefs({});
    final sounds = _Sounds();
    await _mount(tester, prefs, sounds);
    sounds.enableBells(true);
    await tester.pump();
    sounds.enableBells(false);
    sounds.enableBells(true);
    await _waitForHint(tester);
    expect(prefs.getInt(SharedPreferenceConstants.bgSoundPlayerVisits), 1);
    expect(find.text(_hint), findsNothing);

    await _mount(tester, prefs, _Sounds(bells: true));
    await _waitForHint(tester);
    expect(find.text(_hint), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('opening the picker before the delay suppresses the hint', (
    tester,
  ) async {
    final prefs = MemoryPrefs({
      SharedPreferenceConstants.bgSoundPlayerVisits: 1,
    });
    var opened = 0;
    await _mount(
      tester,
      prefs,
      _Sounds(sound: _rain),
      onPressed: () => opened++,
    );
    await tester.tap(_soundButton);
    await _waitForHint(tester);
    expect(opened, 1);
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('outside taps dismiss; the sound button remains actionable', (
    tester,
  ) async {
    final prefs = MemoryPrefs({
      SharedPreferenceConstants.bgSoundPlayerVisits: 1,
    });
    var opened = 0;
    await _mount(
      tester,
      prefs,
      _Sounds(sound: _rain),
      onPressed: () => opened++,
    );
    await _waitForHint(tester);
    expect(find.text(_hint), findsOneWidget);
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(_hint), findsNothing);
    await tester.tap(_soundButton);
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'close dismisses the hint without opening the picker or repeating',
    (tester) async {
      final prefs = MemoryPrefs({
        SharedPreferenceConstants.bgSoundPlayerVisits: 1,
      });
      var opened = 0;
      await _mount(
        tester,
        prefs,
        _Sounds(sound: _rain),
        onPressed: () => opened++,
      );
      await _waitForHint(tester);
      final close = find.byTooltip('Close');
      expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(44));
      // A slower tap must still reach the close button instead of the overlay
      // disappearing on pointer-down and cancelling its gesture.
      final gesture = await tester.startGesture(tester.getCenter(close));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();
      expect(find.text(_hint), findsNothing);
      expect(opened, 0);
      await _mount(tester, prefs, _Sounds(sound: _rain));
      await _waitForHint(tester);
      expect(find.text(_hint), findsNothing);
    },
  );

  testWidgets('leaving before display cancels the hint without consuming it', (
    tester,
  ) async {
    final prefs = MemoryPrefs({
      SharedPreferenceConstants.bgSoundPlayerVisits: 1,
    });
    await _mount(tester, prefs, _Sounds(sound: _rain));
    await tester.pumpWidget(const SizedBox());
    await _waitForHint(tester);
    expect(
      prefs.getBool(SharedPreferenceConstants.bgSoundChangeHintShown),
      isNull,
    );
    expect(tester.takeException(), isNull);
    await _mount(tester, prefs, _Sounds(sound: _rain));
    await _waitForHint(tester);
    expect(find.text(_hint), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('fits a narrow screen with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = MemoryPrefs({
      SharedPreferenceConstants.bgSoundPlayerVisits: 1,
    });
    await _mount(tester, prefs, _Sounds(sound: _rain), textScale: 2);
    await _waitForHint(tester);
    expect(find.text(_hint), findsOneWidget);
    final rect = tester.getRect(find.text(_hint));
    expect(rect.left, greaterThanOrEqualTo(16));
    expect(rect.right, lessThanOrEqualTo(304));
    expect(rect.bottom, lessThan(tester.getRect(_soundButton).top));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
