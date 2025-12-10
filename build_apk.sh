#!/bin/zsh

# Exit on error
set -e

# Accept PAYWALL_ENV as first argument or use environment variable, default to "live"
PAYWALL_ENV="${1:-${PAYWALL_ENV:-live}}"

# Validate PAYWALL_ENV
if [ "$PAYWALL_ENV" != "live" ] && [ "$PAYWALL_ENV" != "dev" ]; then
  echo "❌ Invalid PAYWALL_ENV: $PAYWALL_ENV"
  echo "Usage: $0 [live|dev]"
  echo "   or: PAYWALL_ENV=dev $0"
  exit 1
fi

echo "🧹 Cleaning project..."
flutter clean

# Extract version number from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
echo "📱 Building APK for version $VERSION..."
echo "🎯 Paywall environment: $PAYWALL_ENV"

# Build the APK with specified paywall environment
flutter build apk --flavor prod --release --dart-define-from-file=../.prod.json --dart-define=PAYWALL_ENV=$PAYWALL_ENV

# Define source and destination paths
SOURCE_APK="build/app/outputs/apk/prod/release/app-prod-release.apk"
  DEST_APK="build/app/outputs/apk/prod/release/medito-${VERSION}-${PAYWALL_ENV}-paywall.apk"

# Check if the APK was built successfully
if [ -f "$SOURCE_APK" ]; then
  echo "✅ APK built successfully"
  
  # Rename the APK
  cp "$SOURCE_APK" "$DEST_APK"
  
  # Get full path
  FULL_PATH="$(pwd)/$DEST_APK"
  
  echo "🏷️ APK renamed to medito-${VERSION}-${PAYWALL_ENV}-paywall.apk"
  echo "📂 APK location: $DEST_APK"
  echo "📂 Full path: $FULL_PATH"
else
  echo "❌ Failed to build APK"
  exit 1
fi

echo "✨ Build process completed successfully"
if [ "$PAYWALL_ENV" = "dev" ]; then
  echo "⚠️  WARNING: This build has DEV paywalls - do NOT deploy to production!"
else
  echo "✅ This build has LIVE paywalls - safe for production deployment"
fi

# Open Finder and reveal the APK
open -R "$DEST_APK"

# Open Telegram app
open -a "Telegram"

echo "📤 Finder opened at APK location, and Telegram launched"