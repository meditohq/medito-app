import 'package:shared_preferences/shared_preferences.dart';

const BG_SOUND_PREF = 'bg_sound_prefs';
const BG_SOUND_PREF_NAME = 'bg_sound_prefs_name';

void addIntToSF(file, key, value) async {
  var prefs = await SharedPreferences.getInstance();
  file = file.toString();
  await prefs.setInt(file + '_' + key, value);
}

Future<int> getIntValuesSF(file, key) async {
  var prefs = await SharedPreferences.getInstance();
  file = file.toString();
  return prefs.getInt(file + '_' + key) ?? 0;
}

void addCurrentDateToSF(key) async {
  var prefs = await SharedPreferences.getInstance();
  key = key.toString();
  var date = DateTime.now();
  var epochDate = date.millisecondsSinceEpoch;
  await prefs.setInt(key, epochDate);
}

Future<int> daysSinceDate(key) async {
  var prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(key)) return 365;
  var savedDate = DateTime.fromMillisecondsSinceEpoch(prefs.get(key));
  var difference = DateTime.now().difference(savedDate);
  return difference.inDays;
}

Future<void> addBgSoundSelectionToSharedPrefs(String file, String name) async {
  var prefs = await SharedPreferences.getInstance();
  await prefs.setString(BG_SOUND_PREF, file);
  await prefs.setString(BG_SOUND_PREF_NAME, name);
}

Future<String> getBgSoundFileFromSharedPrefs() async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.getString(BG_SOUND_PREF);
}

Future<String> getBgSoundNameFromSharedPrefs() async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.getString(BG_SOUND_PREF_NAME);
}