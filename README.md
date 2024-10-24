# About Medito

## About

Meditation can positively transform people's lives, and we believe no one should have to pay for it. We are the [Medito Foundation](https://meditofoundation.org), and we've built the Medito App for people who have never meditated before or want to deepen their meditation practice. 

The app is free, forever: no ads, no spam, no need to sign up or pay. Medito App is a Flutter project available on Android and iOS maintained by the Medito Foundation and its community.

## Download

- Play Store: [Download on Google Play](https://play.google.com/store/apps/details?id=meditofoundation.medito)
- App Store: [Download on the App Store](https://apps.apple.com/us/app/medito/id1500780518)
- APK: <a href="https://github.com/meditohq/medito-app/releases/latest"><img alt="GitHub release (latest by date)" src="https://img.shields.io/github/v/release/meditohq/medito-app?color=success&label=APK"></a>

**NOTE:** If you install the Medito app using the APK file, please make sure to verify that the APK file is signed by Medito Foundation. See [VERIFY_APK](VERIFY_APK.md) for more information.

## How to Contribute

We are a small team and are not looking for people who can contribute to the project at the moment. We don't have time to onboard anyone, sorry.

~~To contribute, please message us on our Telegram channel. You can access it by joining [https://t.me/meditoapp](https://t.me/meditoapp) and then going to "Discussion." Let us know that you are looking to contribute to the code, specify for how many hours per week, and how many years of experience with Flutter you have. Also, please include a link to your GitHub profile or portfolio.~~

## How to Build the Project

You will not be able to run the project without the necessary keys. Please message us on Telegram first to request access to these keys. We use external libraries that require specific keys, and we will need to chat with you directly to provide these.

### Setup

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
dart run build_runner watch --delete-conflicting-outputs
```

### Development and Production Configurations

This project supports separate development and production configurations. Here's how to set up and use them in different IDEs:

#### Visual Studio Code

1. Open the project in VSCode.
2. Go to the Run and Debug view (Ctrl+Shift+D or Cmd+Shift+D on macOS).
3. In the dropdown at the top of the sidebar, you can choose between:
   - "Flutter (Dev)" for development configuration
   - "Flutter (Prod)" for production configuration
4. Click the play button or press F5 to start debugging with the selected configuration.

#### Android Studio

1. Open the project in Android Studio.
2. In the toolbar, you'll see a dropdown next to the run button.
3. Select either "Flutter (Dev)" or "Flutter (Prod)" from this dropdown.
4. Click the run button or press Shift+F10 to run the selected configuration.

These configurations are defined in:
- `.vscode/launch.json` for VSCode
- `.run/Flutter_Dev.run.xml` and `.run/Flutter_Prod.run.xml` for Android Studio

Ensure that your `android/app/build.gradle` file has the corresponding flavor configurations set up correctly.

## License

- App: [GNU AFFERO GENERAL PUBLIC LICENSE](https://github.com/meditohq/medito-app/blob/master/LICENSE).
- The content available within the Medito app is subject to a custom license. For more information, please refer to [meditofoundation.org/license](https://meditofoundation.org/license).
- Sometimes we aggregate content from other sources that do not have the same license. This content is generally not published under "Medito." Make sure to respect the original copyright. 

Medito Foundation: [https://meditofoundation.org/](https://meditofoundation.org/).
