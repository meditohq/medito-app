#!/bin/zsh

# Exit on error
set -e

# Get the current version from pubspec.yaml
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')

# Get the version and relative date from the last commit where pubspec.yaml was changed
LAST_COMMITTED_VERSION=$(git show HEAD:pubspec.yaml | grep '^version:' | awk '{print $2}')
LAST_COMMIT_DATE_AGO=$(git log -1 --pretty=format:%ar -- pubspec.yaml)

echo "Current version: $CURRENT_VERSION"
echo "Last committed version for pubspec.yaml: $LAST_COMMITTED_VERSION (committed $LAST_COMMIT_DATE_AGO)"

# Check if the version has been updated
if [ "$CURRENT_VERSION" = "$LAST_COMMITTED_VERSION" ]; then
    echo "⚠️ The version in pubspec.yaml ($CURRENT_VERSION) has not been updated since the last commit ($LAST_COMMIT_DATE_AGO)."
    echo -n "Do you want to continue building with this version? (y/N): "
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "🛑 Build cancelled. Please update the version in pubspec.yaml and commit the change."
        exit 1
    fi
fi

echo "🧪 Running Flutter tests..."
flutter test

echo "🚀 Starting Android build and deploy..."
./build_apk.sh

# Create dated APKs directory if it doesn't exist
DATED_APKS_DIR="dated_apks"
mkdir -p "$DATED_APKS_DIR"

# Generate dated filename with format xxx-ddMMMYYYY.apk
DATE_STAMP=$(date +"%d%b%Y")
SOURCE_APK="build/app/outputs/apk/prod/release/app-prod-release.apk"
DEST_APK="$DATED_APKS_DIR/medito-$CURRENT_VERSION-$DATE_STAMP.apk"

# Copy the APK with the new name
cp "$SOURCE_APK" "$DEST_APK"
echo "✅ APK copied to $DEST_APK"

# Open the dated APKs directory
echo "✅ All builds completed! Opening dated APKs directory..."
open "$DATED_APKS_DIR"

echo "🚀 Starting iOS build and upload..."

# Source credentials from a separate, ignored file
if [ -f "ios_credentials.sh" ]; then
    source ios_credentials.sh
else
    echo "⚠️ 'ios_credentials.sh' not found. You may be prompted for credentials."
fi

./build_and_upload_ios.sh

# It's a good practice to unset the variables after use if set within the script
if [ -n "$APPLE_ID_ENV" ]; then
    unset APPLE_ID_ENV
fi
if [ -n "$APP_SPECIFIC_PASSWORD_ENV" ]; then
    unset APP_SPECIFIC_PASSWORD_ENV
fi
