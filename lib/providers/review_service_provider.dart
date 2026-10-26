import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/review_service.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) => ReviewService());

final canRateMeditoProvider = Provider<bool>((ref) {
  final stats = ref.watch(statsProvider).value;
  return stats != null && ReviewService.isEligible(stats.totalTracksCompleted);
});
