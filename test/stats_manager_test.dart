import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/services/stats_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';


@GenerateMocks([StatsService, SharedPreferences])
void main() {
  late StatsManager statsManager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    statsManager = StatsManager();
  });

  group('StatsManager - Streak Calculation', () {
    test('calculateStreak should handle regular consecutive days', () async {
      var now = DateTime.now();
      var yesterday = now.subtract(const Duration(days: 1));
      var twoDaysAgo = now.subtract(const Duration(days: 2));

      var mockStats = LocalAllStats(
        tracksCompleted: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: now.millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: yesterday.millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: twoDaysAgo.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 2,
        totalTracksCompleted: 3,
        totalTimeListened: 180,
        updated: now.millisecondsSinceEpoch,
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 3);
      expect(result.streakLongest, 3);
    });

    test('calculateStreak should handle sessions near midnight', () async {
      var now = DateTime.now();
      var yesterdayLate =
          now.subtract(const Duration(days: 1, minutes: 15)); // 23:45 yesterday
      var todayEarly =
          now.subtract(const Duration(hours: 23, minutes: 45)); // 00:15 today

      var mockStats = LocalAllStats(
        announcementsDismissed: [],
        tracksCompleted: [],
        tracksFavorited: [],
        streakLastDate: 0,
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: now.millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: yesterdayLate.millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: todayEarly.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 1,
        totalTracksCompleted: 3,
        totalTimeListened: 180,
        updated: now.millisecondsSinceEpoch,
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 2);
      expect(result.streakLongest, 2);
    });

    test('calculateStreak should handle broken streaks', () async {
      var now = DateTime.now();
      var twoDaysAgo = now.subtract(const Duration(days: 2));
      var threeDaysAgo = now.subtract(const Duration(days: 3));

      var mockStats = LocalAllStats(
        announcementsDismissed: [],
        tracksCompleted: [],
        tracksFavorited: [],
        streakLastDate: 0,
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: now.millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: twoDaysAgo.millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: threeDaysAgo.millisecondsSinceEpoch),
        ],
        streakCurrent: 3,
        streakLongest: 3,
        totalTracksCompleted: 3,
        totalTimeListened: 180,
        updated: now.millisecondsSinceEpoch,
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 1);
      expect(result.streakLongest, 3);
    });

    test('calculateStreak should handle empty audioCompleted list', () {
      var mockStats = LocalAllStats(
        announcementsDismissed: [],
        tracksCompleted: [],
        tracksFavorited: [],
        audioCompleted: [],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 0,
        totalTimeListened: 0,
        updated: DateTime.now().millisecondsSinceEpoch,
        streakLastDate: 0,
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 0);
      expect(result.streakLongest, 0);
    });

    test('calculateStreak should handle single day activity', () {
      var now = DateTime.now();
      var mockStats = LocalAllStats(
        announcementsDismissed: [],
        tracksCompleted: [],
        tracksFavorited: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: now.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 1,
        totalTimeListened: 60,
        updated: now.millisecondsSinceEpoch,
        streakLastDate: 0,
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 1);
      expect(result.streakLongest, 1);
    });

    test('calculateStreak should handle multiple sessions on the same day', () {
      var now = DateTime.now();
      var mockStats = LocalAllStats(
        announcementsDismissed: [],
        tracksCompleted: [],
        tracksFavorited: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: now.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: now.subtract(const Duration(hours: 4)).millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 3,
        totalTimeListened: 180,
        updated: now.millisecondsSinceEpoch,
        streakLastDate: 0,
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 1);
      expect(result.streakLongest, 1);
    });

    test('calculateStreak should handle a very long streak', () {
      var now = DateTime.now();
      var audioCompleted = List.generate(100, (index) {
        return LocalAudioCompleted(
          id: index.toString(),
          timestamp: now.subtract(Duration(days: index)).millisecondsSinceEpoch,
        );
      });

      var mockStats = LocalAllStats(
        announcementsDismissed: [],
        tracksCompleted: [],
        tracksFavorited: [],
        audioCompleted: audioCompleted,
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 100,
        totalTimeListened: 6000,
        updated: now.millisecondsSinceEpoch,
        streakLastDate: 0,
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 100);
      expect(result.streakLongest, 100);
    });
  });
}
