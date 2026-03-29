# About Medito

## About

Meditation can positively transform people's lives, and we believe no one should have to pay for it. We are the [Medito Foundation](https://meditofoundation.org), and we've built the Medito App for people who have never meditated before or want to deepen their meditation practice. 

The app is free, forever: no ads, no spam, no need to sign up or pay. Medito App is a Flutter project available on Android and iOS maintained by the Medito Foundation and its community.

## Download

- Play Store: [Download on Google Play](https://play.google.com/store/apps/details?id=meditofoundation.medito)
- App Store: [Download on the App Store](https://apps.apple.com/us/app/medito/id1500780518)
- APK: <a href="https://github.com/meditohq/medito-app/releases/latest"><img alt="GitHub release (latest by date)" src="https://img.shields.io/github/v/release/meditohq/medito-app?color=success&label=APK"></a>

**NOTE:** If you install the Medito app using the APK file, please make sure to verify that the APK file is signed by Medito Foundation. See [VERIFY_APK](VERIFY_APK.md) for more information.

### Contributions (Running in Mock Mode (no keys required))

Contributors can run the app without any API keys or Firebase setup using mock mode. All network calls are intercepted and return hardcoded sample data — no real credentials are needed.

1. Clone the repository and install dependencies:
   ```
   git clone https://github.com/meditohq/medito-app.git
   cd medito-app
   flutter pub get
   ```

2. Generate required code (Pigeon + Riverpod):
   ```
   flutter pub run pigeon --input pigeon_conf.dart
   dart run build_runner build --delete-conflicting-outputs
   ```

3. Create `android/keystore.properties` using your own debug keystore. The Android SDK auto-creates one at `~/.android/debug.keystore` with default credentials:
   ```
   cp android/keystore.properties.example android/keystore.properties
   ```
   Then edit `android/keystore.properties` with your keystore details:
   ```
   storePassword=<your-keystore-password>
   keyPassword=<your-key-password>
   keyAlias=<your-key-alias>
   storeFile=<absolute-path-to-your-keystore>
   appId=meditofoundation.medito
   versionCode=1
   versionName=1.0.0
   ```
   For the default Android debug keystore the password, key password, and alias are `android`, `android`, and `androiddebugkey` respectively.

4. Create a placeholder `android/app/google-services.json` (Firebase is skipped in mock mode, but Gradle requires the file)

5. Run the app using the **"Flutter (Mock)"** run configuration in VS Code or Android Studio, or from the terminal:
   ```
   flutter run --flavor dev --dart-define=MOCK_MODE=true -d <device-id>
   ```

In mock mode, Firebase, Superwall, Stripe, and Meta SDK are all skipped. The app runs with sample content so you can work on UI and logic without real credentials.

### Setup (with real keys)

1. Clone the repository:
   ```
   git clone https://github.com/meditohq/medito-app.git
   cd medito-app
   ```

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Set up environment files:
   - Create `.env.staging` and `.env.production` files in the root directory.
   - Contact a team member for the contents of these files.

4. Set up Firebase:
   - You need `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) from the Firebase console.
   - You also need the `/lib/firebase_options.dart` file.
   - Contact a team member for the contents of these files.

### Generating Code

To generate Pigeon code. This is required to communicate with native iOS and Android code.
```
flutter pub run pigeon --input pigeon_conf.dart
```

To generate API and state management code with Riverpod:
```
dart run build_runner build --delete-conflicting-outputs
```

### Development and Production Configurations

This project supports separate development and production configurations. Here's how to set up and use them in different IDEs:

#### Visual Studio Code

Add the following to your `.vscode/launch.json` (this file is gitignored, so each developer maintains their own):

```json
{
  "version": "0.2.0",
  "configurations": [
    { "name": "Flutter (Dev)", "request": "launch", "type": "dart", "args": ["--flavor", "dev", "--dart-define-from-file=../.staging.json"] },
    { "name": "Flutter (Prod)", "request": "launch", "type": "dart", "args": ["--flavor", "prod"] },
    { "name": "Flutter (Mock)", "request": "launch", "type": "dart", "args": ["--flavor", "dev", "--dart-define=MOCK_MODE=true"] }
  ]
}
```

#### Android Studio

1. Open the project in Android Studio.
2. In the toolbar, you'll see a dropdown next to the run button.
3. Select "Flutter (Dev)", "Flutter (Prod)", or "Flutter (Mock)" from this dropdown.
4. Click the run button or press Shift+F10 to run the selected configuration.

These configurations are defined in `.run/Flutter (Dev).run.xml`, `.run/Flutter (Prod).run.xml`, and `.run/Flutter (Mock).run.xml`.

Ensure that your `android/app/build.gradle` file has the corresponding flavor configurations set up correctly.

## Android Setup

For Android APK signing, you need to create a `keystore.properties` file in the `android/` directory:

1. Copy `android/keystore.properties.example` to `android/keystore.properties`
2. Fill in your actual keystore information
3. Generate or obtain a keystore file (`.jks`) for signing APKs

**Note:** Never commit `keystore.properties` or your `.jks` files to version control.

## License

- App: [GNU AFFERO GENERAL PUBLIC LICENSE](https://github.com/meditohq/medito-app/blob/master/LICENSE).
- The content available within the Medito app is subject to a custom license. For more information, please refer to [meditofoundation.org/license](https://meditofoundation.org/license).
- Sometimes we aggregate content from other sources that do not have the same license. This content is generally not published under "Medito." Make sure to respect the original copyright. 

Medito Foundation: [https://meditofoundation.org/](https://meditofoundation.org/).
