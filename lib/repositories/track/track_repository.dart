import 'dart:convert';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'track_repository.g.dart';

abstract class TrackRepository {
  Future<TrackModel> fetchTrack(String trackId);

  Future<List<TrackModel>> fetchTrackFromPreference();

  Future<void> addTrackInPreference(List<TrackModel> trackList);

  Future<void> addCurrentlyPlayingTrackInPreference(
    TrackModel trackModel,
  );

  Future<void> removeCurrentlyPlayingTrackInPreference();

  Future<TrackModel?> fetchCurrentlyPlayingTrackFromPreference();
}

class TrackRepositoryImpl extends TrackRepository {
  final DioApiService client;
  final Ref ref;

  TrackRepositoryImpl({required this.ref, required this.client});

  @override
  Future<TrackModel> fetchTrack(String trackId) async {
    var response = await client.getRequest('${HTTPConstants.TRACKS}/$trackId');

    return TrackModel.fromJson(response);
  }

  @override
  Future<List<TrackModel>> fetchTrackFromPreference() async {
    var _downloadedTrackList = <TrackModel>[];
    var _downloadedTrackFromPref =
        ref.read(sharedPreferencesProvider).getString(
              SharedPreferenceConstants.downloads,
            );
    if (_downloadedTrackFromPref != null) {
      var tempList = [];
      tempList = json.decode(_downloadedTrackFromPref);
      tempList.forEach((element) {
        _downloadedTrackList.add(TrackModel.fromJson(element));
      });
    }

    return _downloadedTrackList;
  }

  @override
  Future<void> addTrackInPreference(List<TrackModel> trackList) async {
    await ref.read(sharedPreferencesProvider).setString(
          SharedPreferenceConstants.downloads,
          json.encode(trackList),
        );
  }

  @override
  Future<void> addCurrentlyPlayingTrackInPreference(
    TrackModel track,
  ) async {
    await ref.read(sharedPreferencesProvider).setString(
          SharedPreferenceConstants.currentPlayingTrack,
          json.encode(track),
        );
  }

  @override
  Future<void> removeCurrentlyPlayingTrackInPreference() async {
    await ref.read(sharedPreferencesProvider).remove(
          SharedPreferenceConstants.currentPlayingTrack,
        );
  }

  @override
  Future<TrackModel?> fetchCurrentlyPlayingTrackFromPreference() async {
    var _track = ref.read(sharedPreferencesProvider).getString(
          SharedPreferenceConstants.currentPlayingTrack,
        );
    if (_track != null) {
      return TrackModel.fromJson(json.decode(_track));
    }

    return null;
  }
}

@riverpod
TrackRepository trackRepository(TrackRepositoryRef ref) {
  return TrackRepositoryImpl(ref: ref, client: ref.watch(dioClientProvider));
}
