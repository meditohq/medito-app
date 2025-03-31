import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/services/review_service.dart';
import 'package:medito/utils/stats_manager.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) {
  final statsManager = StatsManager();
  return ReviewService(statsManager: statsManager);
});
