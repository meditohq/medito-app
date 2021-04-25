import 'package:Medito/viewmodel/cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> clearStorageIfFirstOpen() async {
  var prefs = await SharedPreferences.getInstance();
  var opened = prefs.getBool('hasOpened') ?? false;
  if (!opened) {
    await clearStorage();
    await prefs.setBool('hasOpened', true);
  }
  return;
}
