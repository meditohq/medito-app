# Medito App

Meditation can positively transform people's lives. We believe no one should have to pay for it. 

We are the [Medito Foundation](https://meditofoundation.org), and we've built the Medito App for people who have never meditated before or want to deepen their meditation practice. 

The app is free, forever: no ads, no spam, no need to sign up or pay. 

Medito App is a flutter project available on Android and iOS maintained by the Medito Foundation and its community.


## Download the app
- Play Store: https://play.google.com/store/apps/details?id=meditofoundation.medito
- App Store: https://apps.apple.com/us/app/medito/id1500780518
- APK: <a href="https://github.com/meditohq/medito-app/releases/latest"><img alt="GitHub release (latest by date)" src="https://img.shields.io/github/v/release/meditohq/medito-app?color=success&label=APK"></a>

NOTE: If you istall Medito app using APK file, please make sure to verify that the APK file is signed by Medito Foundation. See [VERIFY_APK](VERIFY_APK.md) for more information.

## Install
[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/meditohq/medito-app?label=latest%20version&sort=semver)](https://github.com/meditohq/medito-app/releases)

| Android | iOS |
| :--: | :--: |
| <a href="https://play.google.com/store/apps/details?id=meditofoundation.medito"><img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="80"/></a><br/>|<a href="https://apps.apple.com/us/app/medito/id1500780518"><img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="55"/></a> |

## How to use this code
The best way to start is by opening the project with [Android Studio](https://developer.android.com/studio) or [Visual Studio](https://visualstudio.microsoft.com/).

You will need an the 2 .env files to build the project. (See "Contributing" below)

To build the code you also need to run 

```flutter pub run pigeon --input pigeon_conf.dart``` and 
```dart run build_runner watch --delete-conflicting-outputs```

Need more details? [Feel free to raise an issue](https://github.com/meditohq/medito-app/issues).

## Contributing

API keys are generated for regular contributors (called "volunteers").

To volunteer, join our [Telegram channel](https://t.me/medito.app) and go to "Discussion", then ask there for a key.

Please note that we are looking for people who are interested in investing at least 2 hours a week regularly. :)

Don't feel like contributing to the code?
Feature requests, feedback and suggestions are welcome. Reach us via Discord/email, or create a new issue.

## About the Medito Foundation

We are a registered Dutch nonprofit:

```html
Medito Foundation (or in Dutch "Medito Stichting") 
KvK-nummer: 75284251
RSIN: 860222627 
```

- [About us](https://meditofoundation.org/about)
- [Why we started Medito](https://meditofoundation.org/blog/why-meditation-should-be-free)
- [Press release](https://meditofoundation.org/blog/medito-foundation-launches-app-to-free-meditation-from-clutches-of-big-business)
- [Medito on Product Hunt](https://www.producthunt.com/posts/medito)

## License
- App: [GNU AFFERO GENERAL PUBLIC LICENSE](https://github.com/meditohq/medito-app/blob/master/LICENSE).
- Our original content is licensed under a Creative Commons licence. For more information please refer to [meditofoundation.org/license](https://meditofoundation.org/license).
- Sometimes we aggregate content from other sources that do not have the same license. This content is generally not published under "Medito". Make sure to respect the original copyright. 
Now that you know, we cannot be held responsible if you are miss-using this content. If you need more info, reach us on Discord or by email.

Medito Foundation https://meditofoundation.org/.

## Development

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

## Development and Production Configurations

This project supports separate development and production configurations. Here's how to set up and use them in different IDEs:

### Visual Studio Code

1. Open the project in VSCode.
2. Go to the Run and Debug view (Ctrl+Shift+D or Cmd+Shift+D on macOS).
3. In the dropdown at the top of the sidebar, you can choose between:
   - "Flutter (Dev)" for development configuration
   - "Flutter (Prod)" for production configuration
4. Click the play button or press F5 to start debugging with the selected configuration.

### Android Studio

1. Open the project in Android Studio.
2. In the toolbar, you'll see a dropdown next to the run button.
3. Select either "Flutter (Dev)" or "Flutter (Prod)" from this dropdown.
4. Click the run button or press Shift+F10 to run the selected configuration.

### Configuration Details

- Development configuration:
  - Entry point: `lib/main_dev.dart`
  - Flavor: dev

- Production configuration:
  - Entry point: `lib/main_prod.dart`
  - Flavor: prod

Temp solution for  iOS
   - Entry point: `lib/main.dart`

These configurations are defined in:
- `.vscode/launch.json` for VSCode
- `.run/Flutter_Dev.run.xml` and `.run/Flutter_Prod.run.xml` for Android Studio

Ensure that your `android/app/build.gradle` file has the corresponding flavor configurations set up correctly.
