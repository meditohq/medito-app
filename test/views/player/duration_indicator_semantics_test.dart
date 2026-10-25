import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/views/player/widgets/duration_indicator_widget.dart';

class _Audio extends AudioStateNotifier {
  @override
  PlaybackState build() => PlaybackState(
    position: 6000,
    duration: 48000,
    isPlaying: true,
    isBuffering: false,
    isSeeking: false,
    isCompleted: false,
    speed: Speed(speed: 1),
    volume: 100,
    track: Track(
      id: 'preview',
      title: 'Noting Thoughts',
      fileId: 'preview-file',
      description: '',
      imageUrl: '',
      artist: 'Will',
    ),
  );
}

void main() {
  testWidgets('seek bar is one named slider with spoken values and '
      '15-second steps', (tester) async {
    final handle = tester.ensureSemantics();
    final seeks = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioStateProvider.overrideWith(_Audio.new)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DurationIndicatorWidget(onSeekEnd: seeks.add)),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(Slider).first);
    // The Slider itself is excluded; the found node is the wrapper's.
    final data = node.getSemanticsData();
    expect(data.label, 'Playback position');
    expect(data.value, '6 seconds of 48 seconds');
    expect(data.increasedValue, '21 seconds of 48 seconds');
    expect(data.decreasedValue, '0 seconds of 48 seconds');
    expect(data.flagsCollection.isSlider, isTrue);
    // The smoke flow waits on this (.maestro/smoke.yaml; Java's "(?s)" is
    // dotAll here), with or without the label in front.
    // Maestro matches the whole string, hence the anchors.
    final smoke = RegExp(r'^(.*\D)?[1-9][0-9]? seconds? of .*$', dotAll: true);
    expect(smoke.hasMatch(data.value), isTrue);
    expect(smoke.hasMatch('${data.label}, ${data.value}'), isTrue);
    expect(smoke.hasMatch(data.decreasedValue), isFalse);

    tester.semantics.performAction(
      find.semantics.byLabel('Playback position'),
      SemanticsAction.increase,
    );
    tester.semantics.performAction(
      find.semantics.byLabel('Playback position'),
      SemanticsAction.decrease,
    );
    expect(seeks, [21000, 0]);
    handle.dispose();
  });
}
