import 'package:Medito/viewmodel/cache.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

void clearStorageIfFirstOpen() async {
  var prefs = await SharedPreferences.getInstance();
  var opened = prefs.getBool('hasOpened') ?? false;
  if (!opened) {
    unawaited(clearStorage());
    await prefs.setBool('hasOpened', true);
  }
}
