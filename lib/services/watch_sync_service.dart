import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/providers/settings/settings_providers.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/streak_circle_display_provider.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/stats_updater.dart';
import 'package:medito/utils/track_variant_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/views/home/widgets/stats/streak_circle_controller.dart';

/// Keeps the Apple Watch / Wear OS app in sync: pushes Continue, Your Daily,
/// favourites and the consistency score / streak (each track pre-resolved to
/// the user's guide + duration so the watch can stream it directly) and
/// records sessions finished on the watch.
///
/// Watched from HomeView, so it only runs while signed in; with no watch the
/// native side drops the push (iOS) or just stores it (Android Data Layer).
final watchSyncProvider = Provider.autoDispose<void>((ref) {
  // iOS: WatchSessionManager.swift; Android (Wear OS): WatchSyncBridge.kt.
  if (!Platform.isIOS && !Platform.isAndroid) return;
  final prefs = ref.read(sharedPreferencesProvider);
  final sync = _WatchSync(ref, prefs);
  // Home is rebuilt after every session (end screen) but only torn down for
  // good on sign-out, account deletion or a forced logout — all of which
  // clear isLoggedIn first. Only then clear the watch, so it never keeps
  // showing (and recording sessions against) a signed-out account.
  ref.onDispose(
    () => sync.dispose(
      signedOut:
          !(prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false),
    ),
  );

  ref.listen(upNextProvider, (_, _) => sync.schedule(), fireImmediately: true);
  ref.listen(favoritesNotifierProvider, (_, _) => sync.schedule());
  ref.listen(statsProvider, (_, _) => sync.schedule());
  ref.listen(guideNamePreferenceProvider, (_, _) => sync.schedule());
  ref.listen(durationPreferenceProvider, (_, _) => sync.schedule());
  ref.listen(streakCircleDisplayProvider, (_, _) => sync.schedule());
  ref.listen(zenModeProvider, (_, _) => sync.schedule());

  unawaited(ref.read(watchCompletionSyncProvider).drainPendingSessions());
});

class _WatchSync {
  _WatchSync(this._ref, this._prefs) {
    // Your Daily changes at midnight with nothing else changing, so re-check
    // whenever the app comes back to the foreground.
    _lifecycle = AppLifecycleListener(onResume: schedule);
  }

  late final AppLifecycleListener _lifecycle;

  static const _channel = MethodChannel('medito.app/watch');

  /// The watch list is short; more favourites than this just scroll forever
  /// on a 45mm screen.
  static const _maxFavorites = 15;
  static const _debounce = Duration(seconds: 2);

  final Ref _ref;
  final SharedPreferences _prefs;
  bool _disposed = false;
  final _resolved = <String, Map<String, Object>>{};
  Timer? _timer;
  String? _lastSignature;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(_push()));
  }

  void dispose({required bool signedOut}) {
    _disposed = true;
    _timer?.cancel();
    _lifecycle.dispose();
    if (signedOut) {
      _prefs.remove(_persistedKey).ignore();
      _channel
          .invokeMethod('updateContext', {
            'v': 2,
            'signedOut': true,
            'sentAt': DateTime.now().millisecondsSinceEpoch,
          })
          .catchError((Object e) {
            AppLogger.w('WATCH', 'Failed to clear watch on sign-out: $e');
            return null;
          })
          .ignore();
    }
  }

  Future<void> _push() async {
    try {
      final snapshotAt = DateTime.now().millisecondsSinceEpoch;
      final upNext = _ref.read(upNextProvider).value;
      final favorites = _ref.read(favoritesNotifierProvider).value ?? [];
      final stats = _ref.read(statsProvider).value;

      final manager = _ref.read(statsManagerProvider);
      final context = <String, Object>{
        'v': 2,
        'accountId': _prefs.getString(SharedPreferenceConstants.userId) ?? '',
        // Compress the acknowledgement history: years of track IDs otherwise
        // exceed WatchConnectivity's small application-context payload budget.
        'recordedSessionsGzip': base64Encode(
          gzip.encode(
            utf8.encode(
              jsonEncode([
                for (final entry
                    in stats?.audioCompleted ?? <LocalAudioCompleted>[])
                  '${entry.id}|${entry.timestamp}',
              ]),
            ),
          ),
        ),
        'freezeTimestamps': stats?.freezeUsageDates ?? <int>[],
        'dayBoundaryOffsetMs': manager.dayBoundaryOffset.inMilliseconds,
      };

      final next = upNext?.nextSession;
      if (upNext != null && next != null) {
        final track = await _resolve(next.id);
        if (track != null) {
          final items = upNext.pack.items;
          final remaining = items.where((item) => item.isCompleted != true);
          final resolved = <Map<String, Object>>[];
          // A bounded look-ahead lets the watch advance without the phone.
          for (final item in remaining.take(10)) {
            final entry = await _resolve(item.id);
            if (entry == null) break;
            resolved.add(entry);
          }
          context['upNext'] = {
            ...track,
            'packTitle': upNext.pack.title,
            'coverUrl': _watchCoverUrl(upNext.pack.coverUrl),
            'completed': upNext.completedCount,
            'total': upNext.totalCount,
            'packTrackIds': items.map((item) => item.id).toList(),
            'completedTrackIds': items
                .where((item) => item.isCompleted == true)
                .map((item) => item.id)
                .toList(),
            'remainingTracks': resolved,
          };
        }
      }

      final daily = await _resolve(ConfigConstants.dailyTrackId, perDay: true);
      if (daily != null) context['daily'] = daily;

      final favoriteTracks = <Map<String, Object>>[];
      for (final item in favorites.take(_maxFavorites)) {
        final track = item.type == FavoriteItemType.pack
            ? await _resolvePackNext(item.id)
            : await _resolve(item.id);
        if (track != null) favoriteTracks.add(track);
      }
      context['favorites'] = favoriteTracks;

      // Zen mode hides streak, stats and consistency "everywhere in the app";
      // the watch included. Progress is still recorded either way.
      if (stats != null && !_ref.read(zenModeProvider)) {
        context['streak'] = stats.streakCurrent;
        context['consistency'] = (stats.consistencyScore * 100).round();
        // Same rule as the Home stat circle: consistency score unless the
        // user ticked "Always show streak on homepage" or has a 100+ day streak.
        context['showStreak'] = !StreakCircleController.showsConsistencyScore(
          stats,
          _ref.read(streakCircleDisplayProvider).value,
        );
      }

      // Do not publish an old stats snapshot after asynchronous resolution.
      if (!identical(stats, _ref.read(statsProvider).value)) {
        schedule();
        return;
      }
      final signature = jsonEncode(context);
      // Signed out while resolving: don't re-fill the watch that dispose()
      // just cleared.
      if (_disposed || signature == _lastSignature) return;

      // sentAt keeps each push distinct: the system drops a context equal
      // to the last one sent, which would strand a reinstalled watch app.
      final delivered =
          await _channel.invokeMethod<bool>('updateContext', {
            ...context,
            'sentAt': snapshotAt,
          }) ??
          false;
      // Only remember what actually reached the watch, so a later push
      // retries once a watch is paired / the app is installed.
      if (delivered) _lastSignature = signature;
    } catch (e, st) {
      if (_disposed) return;
      AppLogger.e('WATCH', 'Failed to push watch context', e, st);
    }
  }

  /// Pack covers are 1080px PNGs (~600KB) — too heavy to stream to a watch.
  /// cdn.medito.app has Cloudflare image resizing, so ask for a ~50KB JPEG
  /// sized for the watch card instead.
  static String _watchCoverUrl(String? url) {
    const cdn = 'https://cdn.medito.app/';
    if (url == null || url.isEmpty) return '';
    if (!url.startsWith(cdn)) return url;
    return '${cdn}cdn-cgi/image/width=400,quality=70,format=jpeg/'
        '${url.substring(cdn.length)}';
  }

  /// A favourited pack plays its next unfinished session — the same pick as
  /// the Home hero's Continue — with the pack's title on the row.
  Future<Map<String, Object>?> _resolvePackNext(String packId) async {
    final persistedKey = 'pack:$packId';
    try {
      final pack = await _ref.read(packDataProvider(packId: packId).future);
      final done = _ref.read(statsProvider).value?.tracksChecked ?? const [];
      final tracks = pack.items
          .where((i) => i.type == TypeConstants.track)
          .toList();
      if (tracks.isEmpty) return null;
      final next = tracks.firstWhere(
        (i) => !done.contains(i.id),
        orElse: () => tracks.first,
      );
      final track = await _resolve(next.id);
      if (track == null) return null;
      final entry = {...track, 'packTitle': pack.title};
      _persist(persistedKey, entry);
      return entry;
    } catch (e) {
      AppLogger.w('WATCH', 'Could not resolve pack $packId for watch: $e');
      return _persisted()[persistedKey];
    }
  }

  /// Picks the voice + file the phone would play for [trackId], cached per
  /// preference so repeat pushes don't refetch every favourite.
  ///
  /// Offline, falls back to the downloaded copy of the track, then to the
  /// last resolution persisted for it — so a push made without a connection
  /// doesn't strip items off the watch.
  ///
  /// [perDay] is for Your Daily, whose id serves a different track each day.
  Future<Map<String, Object>?> _resolve(
    String trackId, {
    bool perDay = false,
  }) async {
    final guideName = _ref.read(guideNamePreferenceProvider);
    final durationMs = _ref.read(durationPreferenceProvider);
    final now = DateTime.now();
    final day = perDay ? '|${now.year}-${now.month}-${now.day}' : '';
    final key = '$trackId|$guideName|$durationMs$day';
    final cached = _resolved[key];
    if (cached != null) return cached;

    final repository = _ref.read(trackRepositoryProvider);
    Track? track;
    try {
      track = await repository.fetchTrack(trackId);
    } catch (e) {
      AppLogger.w('WATCH', 'Could not fetch track $trackId for watch: $e');
      try {
        final downloads = await repository.fetchTrackFromPreference();
        track = downloads.where((t) => t.id == trackId).firstOrNull;
      } catch (_) {}
      if (track == null) return _persisted()[trackId];
    }

    if (track.voices.every((v) => v.audioFiles.isEmpty)) return null;
    final selection = TrackVariantSelector.resolve(
      track,
      guideName: guideName,
      durationMs: durationMs,
    );
    final resolved = <String, Object>{
      'id': track.id,
      'title': track.title,
      'subtitle': track.subtitle ?? '',
      'audioUrl': selection.file.path,
      'fileId': selection.file.id,
      'durationMs': selection.file.duration,
      'guide': selection.voice.guideName ?? '',
    };
    _resolved[key] = resolved;
    _persist(trackId, resolved);
    return resolved;
  }

  static const _persistedKey = 'watch_resolved_tracks';

  Map<String, Map<String, Object>> _persisted() {
    try {
      final raw = _prefs.getString(_persistedKey);
      if (raw == null) return {};
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (id, value) => MapEntry(id, Map<String, Object>.from(value as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  void _persist(String trackId, Map<String, Object> resolved) {
    final all = _persisted()..[trackId] = resolved;
    // Bounded: only what the watch can show (Up Next + favourites) matters.
    while (all.length > _maxFavorites * 2) {
      all.remove(all.keys.first);
    }
    _prefs.setString(_persistedKey, jsonEncode(all)).ignore();
  }
}

/// Completion ingestion lives for the app's ProviderScope, independent of Home
/// or the end screen. Rendering and context resolution stay in watchSyncProvider.
final watchCompletionSyncProvider = Provider<WatchCompletionSync>((ref) {
  final sync = WatchCompletionSync(ref, ref.read(sharedPreferencesProvider));
  ref.onDispose(sync.dispose);
  if (Platform.isIOS || Platform.isAndroid) sync.start();
  return sync;
});

class WatchCompletionSync {
  WatchCompletionSync(this._ref, this._prefs);
  static const _channel = MethodChannel('medito.app/watch');
  final Ref _ref;
  final SharedPreferences _prefs;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;
  bool _draining = false;
  bool _drainAgain = false;

  void start() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sessionsAvailable') await drainPendingSessions();
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(drainPendingSessions());
      },
    );
    unawaited(drainPendingSessions());
  }

  void dispose() {
    _disposed = true;
    _lifecycle?.dispose();
    _channel.setMethodCallHandler(null);
  }

  /// Records sessions the watch finished. They are queued natively (the watch
  /// can deliver while Flutter isn't running) and drained here.
  Future<void> drainPendingSessions() async {
    if (_disposed ||
        !(_prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false)) {
      return;
    }
    if (_draining) {
      _drainAgain = true;
      return;
    }
    _draining = true;
    var savedAny = false;
    try {
      final pending =
          await _channel.invokeListMethod<Map>('takePendingSessions') ?? [];
      if (pending.isEmpty) return;

      final statsManager = _ref.read(statsManagerProvider);
      final accepted = <Map>[];
      for (final session in pending) {
        final trackId = session['trackId'] as String?;
        final timestamp = session['timestamp'] as int?;
        final duration = session['duration'] as int? ?? 0;
        if (_disposed ||
            !(_prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false)) {
          return;
        }
        if (trackId == null || timestamp == null) continue;
        final account = session['accountId'] as String?;
        if (account != null &&
            account.isNotEmpty &&
            account != _prefs.getString(SharedPreferenceConstants.userId)) {
          await _channel.invokeMethod('acknowledgeSessions', {
            'keys': ['$trackId|$timestamp'],
          });
          continue;
        }

        await statsManager.addAudioCompleted(
          LocalAudioCompleted(
            id: trackId,
            timestamp: session['statsTimestamp'] as int? ?? timestamp,
          ),
          duration,
          skipPost: true,
          deduplicate: true,
          timestampIsNormalized: session['statsTimestamp'] is int,
        );
        savedAny = true;
        accepted.add(session);
        await _channel.invokeMethod('acknowledgeSessions', {
          'keys': ['$trackId|$timestamp'],
        });
        unawaited(
          FirebaseAnalyticsService().logEvent(
            name: AnalyticsEventConstants.watchSessionCompleted,
            parameters: {
              AnalyticsEventConstants.paramAudioFileId:
                  session['fileId'] as String? ?? 'unknown',
              AnalyticsEventConstants.paramAudioFileGuide:
                  session['guide'] as String? ?? 'unknown',
              AnalyticsEventConstants.paramAudioFileDuration: duration,
            },
          ),
        );
        AppLogger.d('WATCH', 'Recorded watch session $trackId');
      }
      await _ref.read(statsProvider.notifier).refreshFromLocal();
      // Recording and acknowledgement depend on the local save, not network.
      unawaited(
        statsManager.flushPendingPost().catchError((Object e) {
          AppLogger.w('WATCH', 'Watch stats upload deferred: $e');
        }),
      );

      // As after a phone session: move the Daily reminder series on from the
      // latest session so today's reminder doesn't nag after a watch session.
      final latest = accepted
          .where((p) => p['trackId'] != null && p['timestamp'] is int)
          .fold<Map?>(
            null,
            (a, b) =>
                a == null || (b['timestamp'] as int) > (a['timestamp'] as int)
                ? b
                : a,
          );
      if (latest != null) {
        await rescheduleRemindersAfterSession(
          endMs: latest['timestamp'] as int,
          durationMs: latest['duration'] as int? ?? 0,
        );
      }

      // Last, as on the phone: this can show the Health permission sheet.
      for (final session in accepted) {
        final timestamp = session['timestamp'] as int?;
        if (session['trackId'] == null || timestamp == null) continue;
        await syncSessionToHealth({
          TypeConstants.timestampIdKey: timestamp,
          TypeConstants.durationIdKey: session['duration'] as int? ?? 0,
        }).catchError((e) {
          AppLogger.e('WATCH', 'HealthKit sync error', e);
        });
      }
    } catch (e, st) {
      AppLogger.e('WATCH', 'Failed to record watch sessions', e, st);
    } finally {
      _draining = false;
      if (!_disposed && savedAny) {
        // Earlier entries may have saved even when a later one failed.
        await _ref.read(statsProvider.notifier).refreshFromLocal();
      }
      if (!_disposed && _drainAgain) {
        _drainAgain = false;
        unawaited(drainPendingSessions());
      }
    }
  }
}
