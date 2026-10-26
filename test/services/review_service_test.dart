import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/review_service.dart';

void main() {
  test('rating option requires five completed sessions', () {
    expect(ReviewService.isEligible(0), isFalse);
    expect(ReviewService.isEligible(4), isFalse);
    expect(ReviewService.isEligible(5), isTrue);
    expect(ReviewService.isEligible(100), isTrue);
  });

  test('store only opens on explicit request', () async {
    var opens = 0;
    final service = ReviewService(
      openStore: () async {
        opens++;
      },
    );
    expect(opens, 0);
    await service.openStore();
    expect(opens, 1);
  });

  test('store errors do not escape into Settings', () async {
    final service = ReviewService(
      openStore: () async {
        throw Exception('unavailable');
      },
    );
    await expectLater(service.openStore(), completes);
  });
}
