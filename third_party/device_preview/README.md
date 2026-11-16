# Vendored device_preview 3.0.0

Unmodified copy of https://pub.dev/packages/device_preview/versions/3.0.0
(`lib/`, `extension/`, `LICENSE`) plus one change: `PreviewPlatformDispatcher`
implements `resetInternalState`, which Flutter 3.50 added to
`ui.PlatformDispatcher`. 3.0.0 does not compile on Flutter >= 3.50 without it.

Delete this directory and the `dependency_overrides` entry in `pubspec.yaml`
once upstream publishes a release that builds on Flutter 3.50.

The prebuilt DevTools panel (`extension/devtools/build/`, 48 MB) is gitignored.
The app builds and `DevicePreview.enable` works without it; to get the panel
in DevTools, copy that directory from the pub cache copy of 3.0.0.
