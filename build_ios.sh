#!/bin/bash

set -e

# Load iOS credentials if available
if [ -f "ios_credentials.sh" ]; then
  source ios_credentials.sh
fi

# Build the iOS app for production

echo "\n[1/3] Building iOS app for production..."
flutter build ios --dart-define-from-file=../.prod.json --dart-define=ENABLE_DEVICE_PREVIEW=false --release

echo "\n[2/3] Exporting .ipa..."

# Path to the generated archive
ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
EXPORT_PATH="build/ios/ipa"
EXPORT_OPTIONS_PLIST="ios/ExportOptions.plist"

# Clean previous builds
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

# Archive the app
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive

# Upload dSYMs to Firebase Crashlytics
if [ -f "ios/upload_dsyms.sh" ]; then
  echo "\n[2.5/3] Uploading dSYMs to Firebase Crashlytics..."
  ios/upload_dsyms.sh "$ARCHIVE_PATH"
else
  echo "\n[Warning] upload_dsyms.sh not found. Skipping dSYM upload."
fi

# Export the .ipa
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

IPA_PATH="$EXPORT_PATH/Runner.ipa"

if [ ! -f "$IPA_PATH" ]; then
  echo "\n[ERROR] .ipa file not found at $IPA_PATH"
  exit 1
fi

echo "\n[3/3] Uploading .ipa to TestFlight..."

# Check for environment variables first
if [ -z "$APPLE_ID_ENV" ] || [ -z "$APP_SPECIFIC_PASSWORD_ENV" ]; then
  echo "Environment variables APPLE_ID_ENV or APP_SPECIFIC_PASSWORD_ENV not set. Falling back to manual input."
  echo "Enter your Apple ID: "
  read APPLE_ID
  echo "Enter your app-specific password (https://appleid.apple.com/account/manage): "
  read -s APP_PASSWORD
else
  echo "Using credentials from environment variables."
  APPLE_ID="$APPLE_ID_ENV"
  APP_PASSWORD="$APP_SPECIFIC_PASSWORD_ENV"
fi

xcrun altool --upload-app -f "$IPA_PATH" -t ios -u "$APPLE_ID" -p "$APP_PASSWORD"

if [ $? -eq 0 ]; then
  echo "\n[Success] .ipa uploaded to TestFlight."
else
  echo "\n[ERROR] Upload failed."
  exit 1
fi
