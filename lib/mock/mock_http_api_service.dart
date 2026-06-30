import 'dart:convert';

import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/mock/mock_data.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/utils/logger.dart';

/// Mock HTTP service that intercepts all API calls and returns hardcoded data.
/// Used in mock mode so contributors can run the app without real API keys.
class MockHttpApiService extends HttpApiService {
  MockHttpApiService() : super.internal() {
    // Set a fake auth header so repositories don't complain
    setAuthHeader('mock-access-token');
  }

  Map<String, dynamic> _toJsonMap(Map<String, dynamic> raw) {
    return jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getRequest(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    AppLogger.d('MOCK_HTTP', 'GET $path');
    return _toJsonMap(_matchResponse(path));
  }

  @override
  Future<Map<String, dynamic>> postRequest(String path, {dynamic body}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    AppLogger.d('MOCK_HTTP', 'POST $path');
    return _toJsonMap(_matchResponse(path));
  }

  @override
  Future<Map<String, dynamic>> deleteRequest(String path) async {
    await Future.delayed(const Duration(milliseconds: 100));
    AppLogger.d('MOCK_HTTP', 'DELETE $path');
    return {};
  }

  @override
  Future<void> signOut() async {
    AppLogger.d('MOCK_HTTP', 'Sign out (mock)');
    clearAuthHeader();
  }

  Map<String, dynamic> _matchResponse(String path) {
    // Strip leading slash if present
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // Home
    if (cleanPath == HTTPConstants.home) {
      return mockHome.toJson();
    }

    // Announcement
    if (cleanPath.startsWith('announcements')) {
      return mockAnnouncement.toJson();
    }

    // Pack detail: packs/{id}
    if (cleanPath.startsWith('${HTTPConstants.packs}/')) {
      final id = cleanPath.split('/').last;
      final pack = mockPacks.where((p) => p.id == id).firstOrNull;
      return pack?.toJson() ?? mockPacks.first.toJson();
    }

    // Packs list
    if (cleanPath == HTTPConstants.packs) {
      return {'results': mockPacks.map((p) => p.toJson()).toList()};
    }

    // Track detail: tracks/{id}
    if (cleanPath.startsWith('${HTTPConstants.tracks}/')) {
      final id = cleanPath.split('/').last;
      final track = mockTracks[id];
      return track?.toJson() ?? mockTracks.values.first.toJson();
    }

    // Me
    if (cleanPath == HTTPConstants.me) {
      return mockMe.toJson();
    }

    // Stats
    if (cleanPath == HTTPConstants.allStats) {
      return mockStats.toJson();
    }

    // Favorites
    if (cleanPath == HTTPConstants.favorites) {
      return {'results': mockFavorites.map((f) => f.toJson()).toList()};
    }

    // Background sounds
    if (cleanPath == HTTPConstants.backgroundSounds) {
      return {'results': mockBackgroundSounds.map((s) => s.toJson()).toList()};
    }

    // Search tracks
    if (cleanPath.startsWith(HTTPConstants.searchTracks)) {
      return {'results': <Map<String, dynamic>>[]};
    }

    // Maintenance
    if (cleanPath.startsWith('maintenance')) {
      return mockMaintenance.toJson();
    }

    // Donation
    if (cleanPath.startsWith('donations')) {
      return mockDonation.toJson();
    }

    // Default: return empty map for unmatched paths
    AppLogger.w('MOCK_HTTP', 'No mock data for path: $cleanPath');
    return {};
  }
}
