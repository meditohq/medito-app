import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/path/path_result.dart';
import '../models/path/path_dto.dart';
import '../mappers/path_mapper.dart';
import '../providers/shared_preference/shared_preference_provider.dart';
import '../constants/constants.dart';

part 'path_repository.g.dart';

@riverpod
PathMapper pathMapper(Ref ref) => PathMapper();

class PathRepository {
  final SharedPreferences _prefs;
  final PathMapper _pathMapper;
  final HttpApiService _client;
  final AsyncValue<LocalAllStats> _stats;

  PathRepository(this._prefs, this._pathMapper, this._client, this._stats);

  static const String _cacheKey = 'path_data';

  Future<bool> isTrackCompleted(String trackId) async {
    return _stats.valueOrNull?.audioCompleted
            ?.map((e) => e.id)
            .contains(trackId) ??
        false;
  }

  Future<JourneyResult> fetchPathData() async {
    try {
      final response = await _client.getRequest('${HTTPConstants.journeys}/1');
      final pathDto = PathDTO.fromJson(response);

      await _cachePathData(json.encode(pathDto.toJson()));

      return _pathMapper.mapDtoToResult(pathDto);
    } catch (e) {
      debugPrint(e.toString());
      return PathResultError.JourneyResultError(
          'Failed to fetch path data: ${e.toString()}');
    }
  }

  Future<JourneyResult> updateTaskCompletion(
      String taskId, bool isCompleted) async {
    try {
      final response = await _client.postRequest(
        '${HTTPConstants.journeys}/1/tasks/$taskId',
        data: {
          'isCompleted': isCompleted,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        },
      );

      final updatedPathDto = PathDTO.fromJson(response);
      await _cachePathData(json.encode(response));

      return _pathMapper.mapDtoToResult(updatedPathDto);
    } catch (e) {
      debugPrint(e.toString());
      return PathResultError.JourneyResultError(
          'Failed to update task completion: ${e.toString()}');
    }
  }

  Future<JourneyResult> updateJournalEntry(
    String taskId,
    String entryText,
    bool markAsCompleted,
  ) async {
    try {
      final response = await _client.postRequest(
        '${HTTPConstants.journeys}/1/tasks/$taskId',
        data: {
          'data': {'entryText': entryText},
          'isCompleted': markAsCompleted,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        },
      );

      final updatedPathDto = PathDTO.fromJson(response);
      await _cachePathData(json.encode(response));

      return _pathMapper.mapDtoToResult(updatedPathDto);
    } catch (e) {
      debugPrint(e.toString());
      return PathResultError.JourneyResultError(
          'Failed to update journal entry: ${e.toString()}');
    }
  }

  Future<void> _cachePathData(String data) async {
    await _prefs.setString(_cacheKey, data);
  }

  Future<void> updateTaskProgress(
      String journeyId, TaskUpdatePayload payload) async {
    final url = '$contentBaseUrl}/journeys/$journeyId/progress';

    try {
      await _client.postRequest(
        url,
        data: payload.toJson(),
      );
    } catch (e) {
      throw Exception('Failed to update task progress: $e');
    }
  }
}

@riverpod
PathRepository pathRepository(Ref ref) {
  return PathRepository(
    ref.watch(sharedPreferencesProvider),
    ref.watch(pathMapperProvider),
    HttpApiService(),
    ref.watch(statsProvider),
  );
}
