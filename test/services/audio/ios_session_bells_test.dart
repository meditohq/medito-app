import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medito/models/background_sounds/background_sounds_model.dart';
import 'package:medito/services/audio/ios_session_bells.dart';

class _Player extends Mock implements AudioPlayer {}

void main() {
  late _Player primary;
  late _Player bell;
  late StreamController<Duration> positions;
  late IosSessionBells controller;
  var position = Duration.zero;
  var playing = false;
  var processing = ProcessingState.ready;
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    primary = _Player();
    bell = _Player();
    positions = StreamController<Duration>.broadcast(sync: true);
    position = Duration.zero;
    playing = false;
    processing = ProcessingState.ready;
    when(() => primary.positionStream).thenAnswer((_) => positions.stream);
    when(
      () => primary.playerStateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => primary.positionDiscontinuityStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => primary.position).thenAnswer((_) => position);
    when(() => primary.speed).thenReturn(1.0);
    when(() => primary.playing).thenAnswer((_) => playing);
    when(() => primary.processingState).thenAnswer((_) => processing);
    when(() => primary.duration).thenReturn(const Duration(minutes: 10));
    when(
      () => bell.setAsset(kSessionBellAsset),
    ).thenAnswer((_) async => const Duration(seconds: 6));
    when(() => bell.setVolume(any())).thenAnswer((_) async {});
    when(() => bell.seek(Duration.zero)).thenAnswer((_) async {});
    when(() => bell.play()).thenAnswer((_) async {});
    when(() => bell.pause()).thenAnswer((_) async {});
    when(() => bell.stop()).thenAnswer((_) async {});
    when(() => bell.processingState).thenReturn(ProcessingState.ready);
    when(() => bell.playing).thenReturn(false);
    when(() => bell.position).thenReturn(Duration.zero);
    controller = IosSessionBells(primary, bell: bell);
  });

  tearDown(() async {
    await controller.disable();
    await positions.close();
  });

  test(
    'paused selection waits for playback and resume does not duplicate cue',
    () async {
      await controller.enable(.5);
      verifyNever(() => bell.play());
      playing = true;
      positions.add(position);
      await flush();
      verify(() => bell.play()).called(1);
      playing = false;
      positions.add(position);
      playing = true;
      positions.add(position);
      await flush();
      verifyNever(() => bell.play());
      position = const Duration(minutes: 5);
      positions.add(position);
      await flush();
      verify(() => bell.play()).called(1);
    },
  );

  test(
    'completion pauses the bell without starting or awaiting a final ring',
    () async {
      await controller.enable(.5);
      processing = ProcessingState.completed;
      positions.add(const Duration(minutes: 10));
      await flush();
      verifyNever(() => bell.play());
      verify(() => bell.pause()).called(greaterThanOrEqualTo(1));
    },
  );

  test('deselecting while asset loads prevents stale playback', () async {
    playing = true;
    final loading = Completer<Duration?>();
    when(
      () => bell.setAsset(kSessionBellAsset),
    ).thenAnswer((_) => loading.future);
    final enabling = controller.enable(.5);
    await controller.disable();
    loading.complete(const Duration(seconds: 6));
    await enabling;
    verifyNever(() => bell.play());
  });

  test('a full session rings at beginning, middle and end', () async {
    await controller.enable(.5);
    playing = true;
    positions.add(Duration.zero);
    await flush();
    verify(() => bell.play()).called(1);
    position = const Duration(minutes: 5);
    positions.add(position);
    await flush();
    verify(() => bell.play()).called(1);
    position = const Duration(seconds: 594);
    positions.add(position);
    await flush();
    verify(() => bell.play()).called(1);
    position = const Duration(minutes: 10);
    processing = ProcessingState.completed;
    positions.add(position);
    await flush();
    verifyNever(() => bell.play());
  });
}
