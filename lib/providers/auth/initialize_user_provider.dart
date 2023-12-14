import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final initializeUserProvider = FutureProvider<bool>((ref) async {
  var auth = ref.read(authProvider);
  await auth.initializeUser();
  var response = auth.userResponse;
  if (response.body != null) {
    await ref.read(assignDioHeadersProvider.future);
    await ref.read(appOpenedEventProvider.future);

    return true;
  }

  return false;
});
