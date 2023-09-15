import 'dart:convert';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'track_repository.g.dart';

abstract class TrackRepository {
  Future<TrackModel> fetchTrack(String trackId);
  Future<List<TrackModel>> fetchTrackFromPreference();
  Future<void> addTrackInPreference(List<TrackModel> trackList);
  Future<void> addCurrentlyPlayingTrackInPreference(
    TrackModel trackModel,
  );
  Future<TrackModel?> fetchCurrentlyPlayingTrackFromPreference();
}

class TrackRepositoryImpl extends TrackRepository {
  final DioApiService client;

  TrackRepositoryImpl({required this.client});

  @override
  Future<TrackModel> fetchTrack(String trackId) async {
    try {
      var res =
          await client.getRequest('${HTTPConstants.TRACKS}/$trackId');

      return TrackModel.fromJson(res);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<TrackModel>> fetchTrackFromPreference() async {
    var _downloadedTrackList = <TrackModel>[];
    var _downloadedTrackFromPref =
        await SharedPreferencesService.getStringFromSharedPref(
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
  Future<void> addTrackInPreference(
      List<TrackModel> trackList) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.downloads,
      json.encode(trackList),
    );
  }

  @override
  Future<void> addCurrentlyPlayingTrackInPreference(
    TrackModel track,
  ) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.currentPlayingTrack,
      json.encode(track),
    );
  }

  @override
  Future<TrackModel?>
      fetchCurrentlyPlayingTrackFromPreference() async {
    var _track = await SharedPreferencesService.getStringFromSharedPref(
      SharedPreferenceConstants.currentPlayingTrack,
    );
    if (_track != null) {
      return TrackModel.fromJson(json.decode(_track));
    }

    return null;
  }
}

@riverpod
TrackRepository trackRepository(ref) {
  return TrackRepositoryImpl(client: ref.watch(dioClientProvider));
}
