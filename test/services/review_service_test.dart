import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late int storeOpens;

  Future<ReviewService> service([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return ReviewService(
      prefs: await SharedPreferences.getInstance(),
      openStore: () async => storeOpens++,
      now: () => now,
    );
  }

  setUp(() {
    now = DateTime(2026, 10, 1, 9);
    storeOpens = 0;
  });

  test('asks only once 😊 has been tapped on 3 separate days', () async {
    final s = await service();

    expect(await s.onHappyFeedback(), isFalse);
    now = now.add(const Duration(hours: 5)); // same day
    expect(await s.onHappyFeedback(), isFalse);
    now = DateTime(2026, 10, 3, 9);
    expect(await s.onHappyFeedback(), isFalse);
    now = DateTime(2026, 10, 7, 21);
    expect(await s.onHappyFeedback(), isTrue);
  });

  test('never asks again once shown', () async {
    final s = await service();
    for (final day in [1, 2, 3]) {
      now = DateTime(2026, 10, day);
      await s.onHappyFeedback();
    }
    await s.markShown();

    now = DateTime(2026, 10, 4);
    expect(await s.onHappyFeedback(), isFalse);
    now = DateTime(2027, 6, 1);
    expect(await s.onHappyFeedback(), isFalse);
  });

  test('suppressed tap still counts toward eligibility', () async {
    final s = await service();
    for (final day in [1, 2]) {
      now = DateTime(2026, 10, day);
      await s.onHappyFeedback();
    }
    now = DateTime(2026, 10, 3);
    expect(await s.onHappyFeedback(suppress: true), isFalse);
    now = DateTime(2026, 10, 4);
    expect(await s.onHappyFeedback(), isTrue);
  });

  test('users asked by the old streak prompt are not asked again', () async {
    final s = await service({'last_review_request_timestamp': 1700000000000});
    for (final day in [1, 2, 3, 4]) {
      now = DateTime(2026, 10, day);
      expect(await s.onHappyFeedback(), isFalse);
    }
  });

  test('openStore opens the store listing', () async {
    final s = await service();
    await s.openStore();
    expect(storeOpens, 1);
  });
}
