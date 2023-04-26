import 'dart:convert';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_repository.g.dart';

abstract class SessionRepository {
  Future<SessionModel> fetchSession(int sessionId);
  Future<List<SessionModel>> fetchSessionFromPreference();
  Future<void> addSessionInPreference(List<SessionModel> sessionList);
  Future<void> addCurrentlyPlayingSessionInPreference(
    SessionModel sessionModel,
  );
  Future<SessionModel?> fetchCurrentlyPlayingSessionFromPreference();
}

class SessionRepositoryImpl extends SessionRepository {
  final DioApiService client;

  SessionRepositoryImpl({required this.client});

  @override
  Future<SessionModel> fetchSession(int sessionId) async {
    try {
      var res = await client.getRequest('${HTTPConstants.SESSIONS}/$sessionId');

      return SessionModel.fromJson(res);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<SessionModel>> fetchSessionFromPreference() async {
    var _downloadedSessionList = <SessionModel>[];
    var _downloadedSessionFromPref =
        await SharedPreferencesService.getStringFromSharedPref(
      SharedPreferenceConstants.downloads,
    );
    if (_downloadedSessionFromPref != null) {
      var tempList = [];
      tempList = json.decode(_downloadedSessionFromPref);
      tempList.forEach((element) {
        _downloadedSessionList.add(SessionModel.fromJson(element));
      });
    }

    return _downloadedSessionList;
  }

  @override
  Future<void> addSessionInPreference(List<SessionModel> sessionList) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.downloads,
      json.encode(sessionList),
    );
  }

  @override
  Future<void> addCurrentlyPlayingSessionInPreference(
    SessionModel session,
  ) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.currentPlayingSession,
      json.encode(session),
    );
  }

  @override
  Future<SessionModel?> fetchCurrentlyPlayingSessionFromPreference() async {
    var _session = await SharedPreferencesService.getStringFromSharedPref(
      SharedPreferenceConstants.currentPlayingSession,
    );
    if (_session != null) {
      return SessionModel.fromJson(json.decode(_session));
    }

    return null;
  }
}

@riverpod
SessionRepository sessionRepository(ref) {
  return SessionRepositoryImpl(client: ref.watch(dioClientProvider));
}
