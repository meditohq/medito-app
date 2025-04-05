#!/bin/zsh

# Exit on error
set -e

# Build the APK using the existing script
./build_apk.sh

# Get the package name from the app
PACKAGE_NAME="meditofoundation.medito"

# Get the APK path (using the same logic as build_prod_apk.sh)
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
APK_PATH="build/app/outputs/apk/prod/release/medito-${VERSION}-prod.apk"

# Get the first connected device
DEVICE_SERIAL=$(adb devices | grep -v "List" | head -n 1 | cut -f1)

if [ -z "$DEVICE_SERIAL" ]; then
    echo "❌ No device connected"
    exit 1
fi

# echo "📱 Using device: $DEVICE_SERIAL"
# echo "🗑️ Uninstalling old app..."
# mcp droidmind uninstall-app --serial "$DEVICE_SERIAL" --package "$PACKAGE_NAME"

echo "📦 Installing new APK..."
mcp droidmind install-app --serial "$DEVICE_SERIAL" --apk-path "$APK_PATH" --grant-permissions true --reinstall true

echo "🚀 Starting app..."
mcp droidmind start-app --serial "$DEVICE_SERIAL" --package "$PACKAGE_NAME"

echo "✅ Deployment complete!" 