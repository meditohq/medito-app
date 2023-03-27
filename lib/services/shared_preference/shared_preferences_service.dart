import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static Future<void> addStringInSF(String key, String value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setString(key, value);
  }

  static Future<String?> getStringFromSF(String key) async {
    var pref = await SharedPreferences.getInstance();
    var stringValue = pref.getString(key);

    return stringValue;
  }

  static Future<void> addIntInSF(String key, int value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setInt(key, value);
  }

  static Future<int?> getIntFromSF(String key) async {
    var pref = await SharedPreferences.getInstance();
    var intValue = pref.getInt(key);

    return intValue;
  }

  static Future<void> addDoubleInSF(String key, double value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setDouble(key, value);
  }

  static Future<double?> getDoubleFromSF(String key) async {
    var pref = await SharedPreferences.getInstance();
    var doubleValue = pref.getDouble(key);

    return doubleValue;
  }

  static Future<void> addBoolInPref(String key, bool value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setBool(key, value);
  }

  static Future<bool?> getBoolFromPref(String key) async {
    var pref = await SharedPreferences.getInstance();

    return pref.getBool(key);
  }

  static Future<bool> removeValueFromSF(String key) async {
    var pref = await SharedPreferences.getInstance();
    var isRemoved = await pref.remove(key);

    return isRemoved;
  }

  static Future<bool> checkValueInSF(String key) async {
    var pref = await SharedPreferences.getInstance();
    var isRemoved = pref.containsKey(key);

    return isRemoved;
  }
}
