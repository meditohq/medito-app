import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final initializeUserProvider = FutureProvider((ref) async {
  var auth = ref.read(authProvider);
  await auth.initializeUser();
  var response = auth.userRes;
  if (response.body != null) {
    await ref.read(assignDioHeadersProvider.future);
    await ref.read(appOpenedEventProvider.future);
  }
});
