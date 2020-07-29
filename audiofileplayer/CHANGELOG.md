## 1.3.1 - 23 May 2020
  * Fix null pointer issues on Android.

## 1.3.0 - 27 Mar 2020
  * Migrate to Android v2 embedding.

## 1.2.0 - 28 Dec 2019
  * Add loading audio from local files, via Audio.loadFromAbsolutePath().

## 1.1.1 - 28 Dec 2019
  * README tweaks.

## 1.1.0 - 24 Dec 2019
  * Proper background audio on Android (using MediaBrowserService).
  * Caller can set supported media actions, metadata, and Android notification buttons.
  * Minor breaking change: 'shouldPlayInBackground' static flag is removed, and a per-Audio 'playInBackground' flag is
    used on each Audio load.
  * Expanded documentation.

## 1.0.3 - 2 Dec 2019

  * Support older versions of Android.
  * Fix error handling in Dart lib, so failed loads get cleaned up before calling onError().

## 1.0.2 - 21 Nov 2019

  * Fix background audio on iOS, add ability to specify iOS audio category (which defaults to 'playback').

## 1.0.1 - 21 Nov 2019

  * Fix new build issues in podfile, add pubspec.yaml dependency versions

## 1.0.0 - 7 Nov 2019

  * Initial open source release

