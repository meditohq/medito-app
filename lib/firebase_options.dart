// Dummy firebase_options.dart for contributors running in mock mode.
// CI overwrites this file with real values from secrets.FIREBASE_OPTIONS_DART.
//
// If you are a Medito team member, get the real file from your team lead.
// If you are a contributor, use mock mode:
//   flutter run --dart-define-from-file=.mock.json

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'mock-api-key',
      appId: 'mock-app-id',
      messagingSenderId: 'mock-sender-id',
      projectId: 'mock-project-id',
    );
  }
}
