import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

var appOpenedEventProvider = FutureProvider<void>((ref) async {
  var deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
  var data = _createAppOpenedModelData(deviceInfo);

  await ref.read(eventsProvider(event: data.toJson()).future);
});

EventsModel _createAppOpenedModelData(DeviceAndAppInfoModel val) {
  var appOpenedModel = AppOpenedModel(
    deviceOs: val.os,
    deviceLanguage: val.languageCode,
    deviceModel: val.model,
    buildNumber: val.buildNumber,
    appVersion: val.appVersion,
  );
  var event = EventsModel(
    name: EventTypes.appOpened,
    payload: appOpenedModel.toJson(),
  );

  return event;
}
