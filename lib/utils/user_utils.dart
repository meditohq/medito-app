import 'package:shared_preferences/shared_preferences.dart';

Future<bool> hasOpenedBefore() async {
  var prefs = await SharedPreferences.getInstance();
  var opened = prefs.getBool('hasOpened') ?? false;
  if (!opened) {
    await prefs.setBool('hasOpened', true);
  }
  return opened;
}
