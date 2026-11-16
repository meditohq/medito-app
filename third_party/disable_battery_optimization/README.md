# Vendored disable_battery_optimization 1.1.2

Unmodified copy of https://pub.dev/packages/disable_battery_optimization/versions/1.1.2
(`lib/`, `android/`, `ios/`, `LICENSE`) plus these compatibility changes in
`android/build.gradle`:

- Remove the two `jcenter()` repository calls, which Gradle 9 removed.
- Raise `compileSdkVersion` from 31 to 36 to match the app and satisfy the
  AndroidX dependencies' AAR metadata checks. The minimum and target SDKs
  remain unchanged.

Delete this directory and the `dependency_overrides` entry in `pubspec.yaml`
once upstream publishes a release that builds on Gradle 9.
