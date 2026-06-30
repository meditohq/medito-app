import 'package:in_app_review/in_app_review.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static const _reviewRequestKey = 'last_review_request_timestamp';
  static const _minimumDaysBetweenRequests = 90; // 3 months
  static const _minimumStreakForReview = 10;

  final InAppReview _inAppReview = InAppReview.instance;
  final StatsManager _statsManager;

  ReviewService({required StatsManager statsManager})
    : _statsManager = statsManager;

  Future<void> checkAndRequestReview() async {
    try {
      final stats = await _statsManager.localAllStats;

      // 2. Check if streak is at least 2
      if (stats.streakCurrent < _minimumStreakForReview) {
        return;
      }

      // 3. Check if we can request a review
      if (!await _canRequestReview()) {
        return;
      }

      // 4. Request the review
      await _requestReview();

      // 5. Save the timestamp of this request
      await _saveReviewRequestTimestamp();
    } catch (e) {
      AppLogger.e('REVIEW', 'Error checking for app review: $e');
    }
  }

  Future<bool> _canRequestReview() async {
    try {
      // Check if in-app review is available on this device
      if (!await _inAppReview.isAvailable()) {
        return false;
      }

      // Check if enough time has passed since last request
      final prefs = await SharedPreferences.getInstance();
      final lastRequestTimestamp = prefs.getInt(_reviewRequestKey) ?? 0;

      if (lastRequestTimestamp == 0) {
        // First time, can request
        return true;
      }

      final lastRequestDate = DateTime.fromMillisecondsSinceEpoch(
        lastRequestTimestamp,
      );
      final now = DateTime.now();
      final difference = now.difference(lastRequestDate).inDays;

      return difference >= _minimumDaysBetweenRequests;
    } catch (e) {
      return false;
    }
  }

  Future<void> _requestReview() async {
    try {
      await _inAppReview.requestReview();
    } catch (e) {
      // Fallback to store listing if requesting review fails
      try {
        await _inAppReview.openStoreListing(appStoreId: '1500780518');
      } catch (storeError) {
        AppLogger.e('REVIEW', 'Error opening store listing: $storeError');
      }
    }
  }

  Future<void> _saveReviewRequestTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _reviewRequestKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.e('REVIEW', 'Error saving review request timestamp: $e');
    }
  }
}
