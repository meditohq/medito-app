import 'package:in_app_review/in_app_review.dart';
import 'package:medito/utils/logger.dart';

/// Store navigation is always user initiated from Settings.
class ReviewService {
  static const minCompletedSessions = 5;
  static const _appStoreId = '1500780518';
  final Future<void> Function() _openStore;

  ReviewService({Future<void> Function()? openStore})
    : _openStore =
          openStore ??
          (() =>
              InAppReview.instance.openStoreListing(appStoreId: _appStoreId));

  static bool isEligible(int completedSessions) =>
      completedSessions >= minCompletedSessions;

  Future<void> openStore() async {
    try {
      await _openStore();
    } catch (e) {
      AppLogger.e('REVIEW', 'Error opening store listing: $e');
    }
  }
}
