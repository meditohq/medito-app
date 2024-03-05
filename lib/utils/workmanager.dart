import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/workmanager_constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../main.dart';
import '../repositories/events/events_repository.dart';
import '../services/network/dio_api_service.dart';

const audioCompletedTaskKey = 'com.AVFoundation.medito.audioCompletedTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await dotenv.load(fileName: currentEnvironment);

    try {
      switch (task) {
        case audioCompletedTaskKey:
          var eventsRpo = EventsRepositoryImpl(
            client: DioApiService(),
          );
          if (inputData != null) {
            await eventsRpo.markAudioAsListenedEvent(
              inputData[TypeConstants.trackIdKey],
              inputData[TypeConstants.timestampIdKey],
              inputData[TypeConstants.durationIdKey],
              inputData[TypeConstants.fileIdKey],
              inputData[TypeConstants.guideIdKey],
              userToken: inputData[WorkManagerConstants.userTokenKey],
            );
          }

          break;
      }
    } catch (err) {
      unawaited(Sentry.captureException(
        err,
        hint: Hint()
          ..addAll(
            {'task': task, 'inputData': inputData?.toString() ?? ''},
          ),
        stackTrace: err,
      ));

      return Future.value(false);
    }

    return Future.value(true);
  });
}
