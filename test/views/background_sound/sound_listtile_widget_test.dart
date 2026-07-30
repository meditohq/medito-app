import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/background_sounds/background_sounds_notifier.dart';
import 'package:medito/views/background_sound/widgets/sound_listtile_widget.dart';

const _rain = BackgroundSoundsModel(
  id: '12',
  title: 'Rain',
  path: 'https://example.com/rain.mp3',
  duration: 60,
);

const _none = BackgroundSoundsModel(
  id: kNoneBackgroundSoundId,
  title: 'None',
  path: '',
  duration: 0,
);

/// Lets a test put the notifier in an arbitrary state and observe the calls the
/// widget makes, without touching the filesystem or an audio player.
class _FakeNotifier extends BackgroundSoundsNotifier {
  _FakeNotifier(this._initialState);

  final BackgroundSoundsState _initialState;
  final retried = <String>[];
  final changed = <String?>[];

  @override
  BackgroundSoundsState build() => _initialState;

  @override
  void retryDownload(BackgroundSoundsModel sound) => retried.add(sound.id);

  @override
  void handleOnChangeSound(BackgroundSoundsModel? sound) =>
      changed.add(sound?.id);
}

void main() {
  Future<_FakeNotifier> pump(
    WidgetTester tester,
    BackgroundSoundsState state, {
    BackgroundSoundsModel sound = _rain,
    Locale locale = const Locale('en'),
  }) async {
    final notifier = _FakeNotifier(state);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backgroundSoundsNotifierProvider.overrideWith(() => notifier),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SoundListTileWidget(sound: sound)),
        ),
      ),
    );

    return notifier;
  }

  testWidgets('a failed sound shows the retry message', (tester) async {
    await pump(tester, const BackgroundSoundsState(failedBgSound: _rain));

    expect(find.text("Couldn't download. Tap to try again."), findsOneWidget);
  });

  testWidgets('tapping a failed sound retries instead of re-selecting it', (
    tester,
  ) async {
    final notifier = await pump(
      tester,
      const BackgroundSoundsState(failedBgSound: _rain),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(notifier.retried, ['12']);
    expect(
      notifier.changed,
      isEmpty,
      reason: 're-selecting would reuse the corrupt file and fail again',
    );
  });

  testWidgets('a sound with no failure shows no message and selects on tap', (
    tester,
  ) async {
    final notifier = await pump(tester, const BackgroundSoundsState());

    expect(find.text("Couldn't download. Tap to try again."), findsNothing);

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(notifier.changed, ['12']);
    expect(notifier.retried, isEmpty);
  });

  testWidgets('a failure on another sound leaves this row alone', (
    tester,
  ) async {
    final notifier = await pump(
      tester,
      const BackgroundSoundsState(failedBgSound: _none),
    );

    expect(find.text("Couldn't download. Tap to try again."), findsNothing);

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(notifier.changed, ['12']);
  });

  testWidgets('the None row is localised, not shown as the English title', (
    tester,
  ) async {
    await pump(
      tester,
      const BackgroundSoundsState(),
      sound: _none,
      locale: const Locale('es'),
    );

    expect(find.text('Ninguno'), findsOneWidget);
    expect(find.text('None'), findsNothing);
  });
}
