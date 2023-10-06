import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'Accessing SharedPreferences without initializing the container',
  );
});

Future<SharedPreferences> initializeSharedPreferences() async {
  return await SharedPreferences.getInstance();
}
