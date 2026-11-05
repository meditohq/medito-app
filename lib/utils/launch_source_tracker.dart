/// Records the most recent reason the app foregrounded or routed, so a
/// later in-app event (e.g. an announcement impression) can be attributed to
/// the signal that brought the user here. The win-rule is "latest wins",
/// with [cold] / [resume] set by [AppOpenTracker] and [deepLink] /
/// [pushNotification] / [localReminder] set by their own handlers before
/// routing.
///
/// Deliberately global (not a provider): foreground, deep-link and
/// notification callbacks fire before any widget tree exists.
class LaunchSourceTracker {
  LaunchSourceTracker._();
  static final LaunchSourceTracker instance = LaunchSourceTracker._();

  static const cold = 'cold';
  static const resume = 'resume';
  static const deepLink = 'deep_link';
  static const pushNotification = 'push';
  static const localReminder = 'smart_reminder';

  String _current = cold;

  /// The latest launch/routing signal. Defaults to [cold] before any
  /// foreground callback fires.
  String get current => _current;

  void markCold() => _current = cold;
  void markResume() => _current = resume;
  void markDeepLink() => _current = deepLink;
  void markPush() => _current = pushNotification;
  void markLocalReminder() => _current = localReminder;
}
