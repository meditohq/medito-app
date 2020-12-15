import 'package:shared_preferences/shared_preferences.dart';

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
