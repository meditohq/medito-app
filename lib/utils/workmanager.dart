import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../constants/types/type_constants.dart';
import '../models/events/audio_completed/audio_completed_model.dart';
import '../models/events/events_model.dart';
import '../repositories/events/events_repository.dart';
import '../services/network/dio_api_service.dart';

const audioCompletedTaskKey = 'com.AVFoundation.medito.audioCompletedTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    try {
      switch (task) {
        case audioCompletedTaskKey:
          var audio = AudioCompletedModel(
            audioFileId: inputData?[TypeConstants.fileIdKey],
            trackId: inputData?[TypeConstants.trackIdKey],
            updateStats: true,
          );
          var event = EventsModel(
            name: EventTypes.audioCompleted,
            payload: audio.toJson(),
          );
          var eventsRpo = EventsRepositoryImpl(client: DioApiService());
          if (inputData != null) eventsRpo.trackEvent(event.toJson());

          break;
      }
    } catch (err) {
      unawaited(Sentry.captureException(
        err,
        Hint(),
        stackTrace: err,
      ));

      return Future.value(false);
    }

    return Future.value(true);
  });
}
