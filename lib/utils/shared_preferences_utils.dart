import 'package:Medito/network/session_options/background_sounds.dart';
import 'package:shared_preferences/shared_preferences.dart';

const BG_SOUND_PREF = 'bg_sound_prefs';
const BG_SOUND_PREF_NAME = 'bg_sound_prefs_name';
const BG_OFFLINE_PREF = 'bg_offline_prefs';

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
  var savedDate = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(key) ?? 0);
  var difference = DateTime.now().difference(savedDate);
  return difference.inDays;
}

Future<void> addBgSoundSelectionToSharedPrefs(String? file, String? name) async {
  var prefs = await SharedPreferences.getInstance();
  if(file != null) {
    await prefs.setString(BG_SOUND_PREF, file);
  }
  if(name != null) {
    await prefs.setString(BG_SOUND_PREF_NAME, name);
  }
}

Future<void> addBgSoundToOfflineSharedPrefs(String? name, String file) async {
  if (name == null) return;
  var prefs = await SharedPreferences.getInstance();
  var offlineSounds = prefs.getStringList(BG_OFFLINE_PREF) ?? [];
  print('adding $name to offline bg collection');
  offlineSounds.add(
      name + '%%' + file); // %% acts a delimiter when retrieving the strings
  await prefs.setStringList(BG_OFFLINE_PREF, offlineSounds);
}

Future<List<BackgroundSoundData>> getBgSoundFromOfflineSharedPrefs() async {
  var prefs = await SharedPreferences.getInstance();
  var list = prefs.getStringList(BG_OFFLINE_PREF) ?? [];
  var bgSoundDataList = List<BackgroundSoundData>.filled(
      0, BackgroundSoundData(),
      growable: true);
  for (var i = 0; i < list.length; ++i) {
    var name = list[i].split('%%')[0];
    var filePath = list[i].split('%%')[1];
    try {
      bgSoundDataList
          .add(BackgroundSoundData(id: i, name: name, file: filePath));
    } catch (e) {
      print(e);
    }
  }
  return bgSoundDataList.toList();
}

Future<String> getBgSoundFileFromSharedPrefs() async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.getString(BG_SOUND_PREF) ?? '';
}

Future<String> getBgSoundNameFromSharedPrefs() async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.getString(BG_SOUND_PREF_NAME) ?? '';
}
