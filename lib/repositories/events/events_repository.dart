import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_repository.g.dart';

abstract class EventsRepository {
  Future<void> appOpened(AppOpenedModel appOpenedModel);
  Future<void> audioStarted(AudioStartedModel audioStartedModel);
  Future<void> audioCompleted(AudioCompletedModel audioCompletedModel);
  Future<void> backgroundSoundSelected(
    BgSoundSelectedModel bgSoundSelectedModel,
  );
  Future<void> folderViewed(FolderViewedModel folderViewedModel);
  Future<void> chipTapped(ChipTappedModel chipTappedModel);
  Future<void> menuItemTapped(MenuItemTappedModel menuItemTappedModel);
  Future<void> transferStats(TransferStatsModel transferStatsModel);
  Future<void> announcementCtaTapped(
    AnnouncementCtaTappedModel announcementCtaTappedModel,
  );
}

class EventsRepositoryImpl extends EventsRepository {
  final DioApiService client;

  EventsRepositoryImpl({required this.client});

  @override
  Future<void> announcementCtaTapped(
    AnnouncementCtaTappedModel announcementCtaTappedModel,
  ) async {
    try {
      await client.postRequest(
        HTTPConstants.EVENTS,
        data: announcementCtaTappedModel.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> appOpened(AppOpenedModel appOpenedModel) async {
    try {
      await client.postRequest(
        HTTPConstants.EVENTS,
        data: appOpenedModel.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> audioCompleted(AudioCompletedModel audioCompletedModel) async {
    try {
      await client.postRequest(
        HTTPConstants.EVENTS,
        data: audioCompletedModel.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> audioStarted(AudioStartedModel audioStartedModel) async {
    try {
      await client.postRequest(
        HTTPConstants.EVENTS,
        data: audioStartedModel.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> backgroundSoundSelected(
    BgSoundSelectedModel bgSoundSelectedModel,
  ) async {
    try {
      await client.postRequest(
        HTTPConstants.EVENTS,
        data: bgSoundSelectedModel.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> chipTapped(ChipTappedModel chipTappedModel) async {
    try {
      await client.postRequest(
        HTTPConstants.EVENTS,
        data: chipTappedModel.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> folderViewed(FolderViewedModel folderViewedModel) async {
    try {
      await client.postRequest(
        HTTPConstants.EVENTS,
        data: folderViewedModel.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> menuItemTapped(MenuItemTappedModel menuItemTappedModel) async {
    try {
      await client.postRequest(
        HTTPConstants.EVENTS,
        data: menuItemTappedModel.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> transferStats(TransferStatsModel transferStatsModel) async {
    try {
      await client.postRequest(
        HTTPConstants.EVENTS,
        data: transferStatsModel.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
EventsRepository eventsRepository(ref) {
  return EventsRepositoryImpl(client: ref.watch(dioClientProvider));
}
