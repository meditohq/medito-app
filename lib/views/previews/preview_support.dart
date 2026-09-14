// Shared scaffolding for `flutter widget-preview start` previews.
//
// Previews render the REAL widgets against an in-memory SharedPreferences and
// a fake AuthRepository, so no backend, Firebase or device is needed. Each
// screen's preview file (settings, home, ...) adds its own provider overrides
// on top of this shell.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const phoneSize = Size(390, 844);

/// Preference seeds for the different states we want to look at.
const Map<String, Object> prefsDark = {
  SharedPreferenceConstants.themePreference: 'dark',
};

const Map<String, Object> prefsLight = {
  SharedPreferenceConstants.themePreference: 'light',
};

/// Minimal [AuthRepository] that never touches the network.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.email});

  final String? email;

  @override
  User? get currentUser => User(id: 'preview-user', email: email);

  @override
  String? getUserEmail() => email;

  @override
  Future<String> getToken() async => 'preview-token';

  @override
  Future<void> initializeUser() async {}

  @override
  Future<bool> isLoggedIn() async => email != null;

  @override
  Future<void> migrateEmailToStorage() async {}

  @override
  Future<void> requestOtp(String email) async {}

  @override
  void resetAuthState() {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<bool> signOut() async => true;

  @override
  Future<bool> verifyOtp(String email, String otp) async => true;
}

/// Per-preview in-memory [SharedPreferences]. The real
/// `SharedPreferences.setMockInitialValues` is a process-wide singleton, so
/// previews rendered side by side would all read whichever seed was applied
/// last. Only the accessors the previewed widgets use are implemented;
/// anything else falls through to [noSuchMethod].
class MemoryPrefs implements SharedPreferences {
  MemoryPrefs(Map<String, Object> seed) : _data = Map.of(seed);

  final Map<String, Object> _data;

  @override
  Object? get(String key) => _data[key];
  @override
  bool? getBool(String key) => _data[key] as bool?;
  @override
  int? getInt(String key) => _data[key] as int?;
  @override
  double? getDouble(String key) => _data[key] as double?;
  @override
  String? getString(String key) => _data[key] as String?;
  @override
  List<String>? getStringList(String key) =>
      (_data[key] as List?)?.cast<String>();
  @override
  bool containsKey(String key) => _data.containsKey(key);
  @override
  Set<String> getKeys() => _data.keys.toSet();

  Future<bool> _set(String key, Object value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) => _set(key, value);
  @override
  Future<bool> setInt(String key, int value) => _set(key, value);
  @override
  Future<bool> setDouble(String key, double value) => _set(key, value);
  @override
  Future<bool> setString(String key, String value) => _set(key, value);
  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _set(key, value);
  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Future<void> reload() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Not supported in previews: ${invocation.memberName}',
  );
}

/// Builds the app shell (theme, l10n, Riverpod) the previewed widgets expect.
class PreviewShell extends StatelessWidget {
  const PreviewShell({
    super.key,
    required this.child,
    required this.prefs,
    this.email,
    this.themeMode = ThemeMode.dark,
    this.padded = false,
    this.overrides = const [],
  });

  final Widget child;
  final Map<String, Object> prefs;
  final String? email;
  final ThemeMode themeMode;

  /// Wrap standalone tiles in a card-like surface with page padding.
  final bool padded;

  /// Extra provider overrides layered on top of prefs and auth.
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(MemoryPrefs(prefs)),
        authRepositorySyncProvider.overrideWithValue(
          FakeAuthRepository(email: email),
        ),
        ...overrides,
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(context, ThemeMode.light),
          darkTheme: appTheme(context, ThemeMode.dark),
          themeMode: themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: padded
              ? Scaffold(
                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: Material(
                          type: MaterialType.transparency,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                )
              : child,
        ),
      ),
    );
  }
}
