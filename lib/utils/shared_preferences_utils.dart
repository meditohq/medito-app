import 'package:shared_preferences/shared_preferences.dart';

void addIntToSF(file, key, value) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  file = file.toString();
  prefs.setInt(file+'_'+key, value);
}
Future<int> getIntValuesSF(file, key) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  file=file.toString();
  return prefs.getInt(file+'_'+key) ?? 0;
}
void addCurrentDateToSF(key) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  key = key.toString();
  DateTime date = DateTime.now();
  var epochDate = date.millisecondsSinceEpoch;
  prefs.setInt(key, epochDate);
}

Future<int> daysSinceDate(key) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if(!prefs.containsKey(key)) return 365;
  DateTime savedDate = DateTime.fromMillisecondsSinceEpoch(prefs.get(key));
  Duration difference = DateTime.now().difference(savedDate);
  return difference.inDays;
}