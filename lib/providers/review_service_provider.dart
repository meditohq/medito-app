import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/review_service.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService(statsManager: ref.read(statsManagerProvider));
});
