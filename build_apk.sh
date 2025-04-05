#!/bin/zsh

# Exit on error
set -e

echo "🧹 Cleaning project..."
flutter clean

# Extract version number from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
echo "📱 Building APK for version $VERSION..."

# Build the APK
flutter build apk --flavor prod --release --dart-define-from-file=../.prod.json

# Define source and destination paths
SOURCE_APK="build/app/outputs/apk/prod/release/app-prod-release.apk"
DEST_APK="build/app/outputs/apk/prod/release/medito-${VERSION}-prod.apk"

# Check if the APK was built successfully
if [ -f "$SOURCE_APK" ]; then
  echo "✅ APK built successfully"
  
  # Rename the APK
  cp "$SOURCE_APK" "$DEST_APK"
  
  # Get full path
  FULL_PATH="$(pwd)/$DEST_APK"
  
  echo "🏷️ APK renamed to medito-${VERSION}-prod.apk"
  echo "📂 APK location: $DEST_APK"
  echo "📂 Full path: $FULL_PATH"
else
  echo "❌ Failed to build APK"
  exit 1
fi

echo "✨ Build process completed successfully"

# Open Finder and reveal the APK
open -R "$DEST_APK"

# Open Telegram app
open -a "Telegram"

echo "📤 Finder opened at APK location, and Telegram launched"