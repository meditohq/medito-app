import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

var retryCounter = 0;
final maxRetryCount = 2;

final userInitializationProvider =
    FutureProvider<UserInitializationStatus>((ref) async {
  try {
    var auth = ref.read(authProvider);
    await auth.initializeUser();
    var response = auth.userResponse;
    if (response.body != null) {
      await ref.read(assignDioHeadersProvider.future);
      await ref.read(appOpenedEventProvider.future);

      return UserInitializationStatus.successful;
    }

    return UserInitializationStatus.error;
  } catch (e) {
    if (retryCounter < maxRetryCount) {
      await Future.delayed(Duration(seconds: 2), () {
        _incrementCounter();
      });

      return UserInitializationStatus.retry;
    }

    return UserInitializationStatus.error;
  }
});

void _incrementCounter() => retryCounter += 1;

//ignore: prefer-match-file-name
enum UserInitializationStatus { retry, error, successful }
