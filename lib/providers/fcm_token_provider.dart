import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/models/models.dart';

final fcmTokenProvider = Provider<Future<void> Function()>((ref) {
  return () => _saveFCMToken(ref);
});

Future<void> _saveFCMToken(Ref ref) async {
  var token = await ref.read(firebaseMessagingProvider).getToken();
  if (token != null) {
    var fcm = SaveFcmTokenModel(token: token);
    await ref.read(fcmSaveEventProvider(
        event: fcm.toJson().map(
              (key, value) => MapEntry(key, value.toString()),
            )).future);
  }
}
