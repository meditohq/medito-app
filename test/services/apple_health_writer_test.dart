import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/apple_health_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final writer = AppleHealthWriter();
  final start = DateTime.utc(2026, 11, 16, 10);
  final end = start.add(const Duration(minutes: 10));
  late List<MethodCall> calls;
  bool? response;

  setUp(() {
    calls = [];
    response = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppleHealthWriter.channel, (call) async {
          calls.add(call);
          return response;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppleHealthWriter.channel, null);
  });

  test('sends the session dates, title and IDs to the native writer', () async {
    expect(
      await writer.writeMindfulnessSession(
        start,
        end,
        title: 'Body Scan',
        trackId: 'track-1',
        fileId: 'file-9',
      ),
      isTrue,
    );
    expect(calls.single.method, 'writeMindfulnessSession');
    expect(calls.single.arguments, {
      'startEpochMs': start.millisecondsSinceEpoch,
      'endEpochMs': end.millisecondsSinceEpoch,
      'title': 'Body Scan',
      'trackId': 'track-1',
      'fileId': 'file-9',
    });
  });

  test('older completions can omit the title and content IDs', () async {
    expect(await writer.writeMindfulnessSession(start, end), isTrue);
    expect(calls.single.arguments, {
      'startEpochMs': start.millisecondsSinceEpoch,
      'endEpochMs': end.millisecondsSinceEpoch,
      'title': null,
      'trackId': null,
      'fileId': null,
    });
  });

  test('passes localized timer titles and synthetic IDs', () async {
    await writer.writeMindfulnessSession(
      start,
      end,
      title: 'Temporizador',
      trackId: 'timer-600',
      fileId: 'timer-countdown-600000',
    );
    expect(calls.single.arguments['title'], 'Temporizador');
    expect(calls.single.arguments['trackId'], 'timer-600');
    expect(calls.single.arguments['fileId'], 'timer-countdown-600000');
  });

  test(
    'does not report an unsuccessful or missing native result as saved',
    () async {
      response = false;
      expect(await writer.writeMindfulnessSession(start, end), isFalse);
      response = null;
      expect(await writer.writeMindfulnessSession(start, end), isFalse);
    },
  );

  test('surfaces native failures for the health sync error handler', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppleHealthWriter.channel, (_) async {
          throw PlatformException(code: 'HEALTH_WRITE_FAILED');
        });
    await expectLater(
      writer.writeMindfulnessSession(start, end),
      throwsA(isA<PlatformException>()),
    );
  });
}
