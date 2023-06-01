import 'dart:convert';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'meditation_repository.g.dart';

abstract class MeditationRepository {
  Future<MeditationModel> fetchMeditation(int meditationId);
  Future<List<MeditationModel>> fetchMeditationFromPreference();
  Future<void> addMeditationInPreference(List<MeditationModel> meditationList);
  Future<void> addCurrentlyPlayingMeditationInPreference(
    MeditationModel meditationModel,
  );
  Future<MeditationModel?> fetchCurrentlyPlayingMeditationFromPreference();
}

class MeditationRepositoryImpl extends MeditationRepository {
  final DioApiService client;

  MeditationRepositoryImpl({required this.client});

  @override
  Future<MeditationModel> fetchMeditation(int meditationId) async {
    try {
      var res =
          await client.getRequest('${HTTPConstants.MEDITATIONS}/$meditationId');

      return MeditationModel.fromJson(res);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<MeditationModel>> fetchMeditationFromPreference() async {
    var _downloadedMeditationList = <MeditationModel>[];
    var _downloadedMeditationFromPref =
        await SharedPreferencesService.getStringFromSharedPref(
      SharedPreferenceConstants.downloads,
    );
    if (_downloadedMeditationFromPref != null) {
      var tempList = [];
      tempList = json.decode(_downloadedMeditationFromPref);
      tempList.forEach((element) {
        _downloadedMeditationList.add(MeditationModel.fromJson(element));
      });
    }

    return _downloadedMeditationList;
  }

  @override
  Future<void> addMeditationInPreference(List<MeditationModel> meditationList) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.downloads,
      json.encode(meditationList),
    );
  }

  @override
  Future<void> addCurrentlyPlayingMeditationInPreference(
    MeditationModel meditation,
  ) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.currentPlayingMeditation,
      json.encode(meditation),
    );
  }

  @override
  Future<MeditationModel?> fetchCurrentlyPlayingMeditationFromPreference() async {
    var _meditation = await SharedPreferencesService.getStringFromSharedPref(
      SharedPreferenceConstants.currentPlayingMeditation,
    );
    if (_meditation != null) {
      return MeditationModel.fromJson(json.decode(_meditation));
    }

    return null;
  }
}

@riverpod
MeditationRepository meditationRepository(ref) {
  return MeditationRepositoryImpl(client: ref.watch(dioClientProvider));
}
