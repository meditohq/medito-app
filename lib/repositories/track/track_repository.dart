import 'dart:convert';

import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'track_repository.g.dart';

abstract class TrackRepository {
  Future<Track> fetchTrack(String trackId);

  Future<List<Track>> fetchTrackFromPreference();

  Future<void> addTrackInPreference(List<Track> trackList);

  Future<void> addCurrentlyPlayingTrackInPreference(Track track);

  Future<void> removeCurrentlyPlayingTrackInPreference();

  Future<Track?> fetchCurrentlyPlayingTrackFromPreference();
}

class TrackRepositoryImpl extends TrackRepository {
  final HttpApiService client;
  final Ref ref;

  TrackRepositoryImpl({required this.ref, required this.client});

  @override
  Future<Track> fetchTrack(String trackId) async {
    try {
      var response = await client.getRequest(
        '${HTTPConstants.tracks}/$trackId',
      );
      return Track.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Track>> fetchTrackFromPreference() async {
    var downloadedTrackList = <Track>[];
    var downloadedTrackFromPref = ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.downloads);
    if (downloadedTrackFromPref != null) {
      var tempList = [];
      tempList = json.decode(downloadedTrackFromPref);
      for (var element in tempList) {
        downloadedTrackList.add(Track.fromJson(element));
      }
    }

    return downloadedTrackList;
  }

  @override
  Future<void> addTrackInPreference(List<Track> trackList) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(SharedPreferenceConstants.downloads, json.encode(trackList));
  }

  @override
  Future<void> addCurrentlyPlayingTrackInPreference(Track track) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          SharedPreferenceConstants.currentPlayingTrack,
          json.encode(track),
        );
  }

  @override
  Future<void> removeCurrentlyPlayingTrackInPreference() async {
    await ref
        .read(sharedPreferencesProvider)
        .remove(SharedPreferenceConstants.currentPlayingTrack);
  }

  @override
  Future<Track?> fetchCurrentlyPlayingTrackFromPreference() async {
    var track = ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.currentPlayingTrack);
    if (track != null) {
      return Track.fromJson(json.decode(track));
    }

    return null;
  }
}

@riverpod
TrackRepository trackRepository(Ref ref) {
  return TrackRepositoryImpl(ref: ref, client: HttpApiService());
}
