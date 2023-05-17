import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static Future<void> addStringInSharedPref(String key, String value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setString(key, value);
  }

  static Future<String?> getStringFromSharedPref(String key) async {
    var pref = await SharedPreferences.getInstance();
    var stringValue = pref.getString(key);

    return stringValue;
  }

  static Future<void> addIntInSharedPref(String key, int value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setInt(key, value);
  }

  static Future<int?> getIntFromSharedPref(String key) async {
    var pref = await SharedPreferences.getInstance();
    var intValue = pref.getInt(key);

    return intValue;
  }

  static Future<void> addDoubleInSharedPref(String key, double value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setDouble(key, value);
  }

  static Future<double?> getDoubleFromSharedPref(String key) async {
    var pref = await SharedPreferences.getInstance();
    var doubleValue = pref.getDouble(key);

    return doubleValue;
  }

  static Future<void> addBoolInSharedPref(String key, bool value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setBool(key, value);
  }

  static Future<bool?> getBoolFromSharedPref(String key) async {
    var pref = await SharedPreferences.getInstance();

    return pref.getBool(key);
  }

  static Future<bool> removeValueFromSharedPref(String key) async {
    var pref = await SharedPreferences.getInstance();
    var isRemoved = await pref.remove(key);

    return isRemoved;
  }

  static Future<bool> checkValueInSharedPref(String key) async {
    var pref = await SharedPreferences.getInstance();
    var isRemoved = pref.containsKey(key);

    return isRemoved;
  }
}
