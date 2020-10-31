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