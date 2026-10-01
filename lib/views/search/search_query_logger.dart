import 'dart:async';

import 'package:medito/constants/strings/analytics_event_constants.dart';

/// Turns the stream of debounced queries into one logged search per thing the
/// user actually looked for.
///
/// The field's 500ms debounce settles on every mid-word pause, so logging each
/// settled query recorded "germ", "germa", "german" as three searches, each with
/// its own no-results event (Sep 2026). Here a query is only logged once the
/// user commits to it: they open a result, submit from the keyboard, clear the
/// field, or stop typing for [idle].
class SearchQueryLogger {
  SearchQueryLogger({
    required this.log,
    this.idle = const Duration(seconds: 3),
  });

  final void Function(String name, Map<String, Object> parameters) log;
  final Duration idle;

  Timer? _idleTimer;
  String? _pending;
  bool? _pendingHasResults;
  String? _lastLogged;

  /// A new settled query. Empty means the field was emptied, which commits
  /// whatever came before it.
  void onQuery(String query) {
    if (query.isEmpty) {
      commit();
      return;
    }
    _pending = query;
    _pendingHasResults = null;
    _idleTimer?.cancel();
    _idleTimer = Timer(idle, commit);
  }

  /// Results for [query] have loaded. Ignored for anything but the pending
  /// query, so a slow response can't be attributed to a newer one.
  void onResults(String query, {required bool hasResults}) {
    if (query == _pending) _pendingHasResults = hasResults;
  }

  /// Logs the pending query, once. Safe to call repeatedly.
  void commit() {
    _idleTimer?.cancel();
    _idleTimer = null;
    final query = _pending;
    final hasResults = _pendingHasResults;
    _pending = null;
    _pendingHasResults = null;
    if (query == null) return;

    final term = sanitizeSearchTerm(query);
    if (term.isEmpty || term == _lastLogged) return;
    _lastLogged = term;

    log(AnalyticsEventConstants.searchPerformed, {
      AnalyticsEventConstants.paramSearchTerm: term,
      AnalyticsEventConstants.paramSearchTermLength: query.trim().length,
      // Absent while results were still loading at commit time.
      if (hasResults != null)
        AnalyticsEventConstants.paramHasResults: hasResults ? 'true' : 'false',
    });
    if (hasResults == false) {
      log(AnalyticsEventConstants.searchNoResults, {
        AnalyticsEventConstants.paramSearchTerm: term,
      });
    }
  }

  void dispose() => commit();
}

/// GA4 forbids personal data and caps string params at 100 characters. Search
/// boxes collect personal data anyway: people paste emails and phone numbers
/// into them. A term with an "@" or 7+ digits (a phone number, however it's
/// spaced) is replaced with [redactedSearchTerm] rather than dropped, so the
/// search still counts.
String sanitizeSearchTerm(String query) {
  final term = query.trim().toLowerCase();
  final digits = RegExp(r'\d').allMatches(term).length;
  if (term.contains('@') || digits >= 7) {
    return redactedSearchTerm;
  }
  return term.length > 100 ? term.substring(0, 100) : term;
}

const redactedSearchTerm = '[redacted]';
