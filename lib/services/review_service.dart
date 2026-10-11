import 'package:in_app_review/in_app_review.dart';
import 'package:intl/intl.dart';
import 'package:medito/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides when to ask for a store rating: once, right after the user has
/// told us they feel good (a 😊 tap on the end screen).
///
/// A single happy tap is not enough — first sessions (onboarding) and one-off
/// good days are excluded by requiring 😊 on [minHappyDays] separate days.
/// Once the ask has been shown it never comes back on this install, whatever
/// the user picked.
///
/// The ask's button opens the store's review page rather than the in-app
/// review dialog: both stores forbid triggering that dialog from a button,
/// because the OS may silently not show it and the button would do nothing.
class ReviewService {
  static const _happyDaysKey = 'review_happy_feedback_days';
  static const _shownKey = 'review_prompt_shown';

  /// Set by the old streak-based prompt. Anyone it already asked counts as
  /// asked, so they are not prompted a second time.
  static const _legacyRequestKey = 'last_review_request_timestamp';

  static const _appStoreId = '1500780518';

  static const minHappyDays = 3;

  final SharedPreferences _prefs;
  final Future<void> Function() _openStore;
  final DateTime Function() _now;

  ReviewService({
    required SharedPreferences prefs,
    Future<void> Function()? openStore,
    DateTime Function()? now,
  }) : _prefs = prefs,
       _openStore =
           openStore ??
           (() =>
               InAppReview.instance.openStoreListing(appStoreId: _appStoreId)),
       _now = now ?? DateTime.now;

  bool get _alreadyShown =>
      (_prefs.getBool(_shownKey) ?? false) ||
      _prefs.containsKey(_legacyRequestKey);

  /// Records a 😊 tap and returns whether the rating ask should be shown now.
  /// The tap is recorded even when [suppress] is set (another ask already
  /// happened on this screen, e.g. a donate tap), so it still counts later.
  Future<bool> onHappyFeedback({bool suppress = false}) async {
    try {
      if (_alreadyShown) return false;
      final days = await _recordHappyDay();
      return days >= minHappyDays && !suppress;
    } catch (e) {
      AppLogger.e('REVIEW', 'Error checking review eligibility: $e');
      return false;
    }
  }

  /// Called when the ask is rendered, so it is never shown again.
  Future<void> markShown() async {
    try {
      await _prefs.setBool(_shownKey, true);
    } catch (e) {
      AppLogger.e('REVIEW', 'Error saving review prompt state: $e');
    }
  }

  /// Opens the store's write-a-review page (iOS) / listing (Android).
  Future<void> openStore() async {
    try {
      await _openStore();
    } catch (e) {
      AppLogger.e('REVIEW', 'Error opening store listing: $e');
    }
  }

  /// Adds today to the days with a 😊 tap and returns how many are stored.
  Future<int> _recordHappyDay() async {
    final today = DateFormat('yyyy-MM-dd').format(_now());
    final days = _prefs.getStringList(_happyDaysKey) ?? const <String>[];
    if (days.contains(today)) return days.length;

    // Only the count up to minHappyDays matters; keep the list bounded.
    final updated = [...days, today];
    final trimmed = updated.length > minHappyDays
        ? updated.sublist(updated.length - minHappyDays)
        : updated;
    await _prefs.setStringList(_happyDaysKey, trimmed);
    return trimmed.length;
  }
}
