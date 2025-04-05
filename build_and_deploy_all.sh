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

echo "🚀 Starting iOS build and upload..."
./build_and_upload_ios.sh

echo "🚀 Starting Android build and deploy..."
./build_and_deploy_android.sh

echo "✅ All builds completed! Opening APK directory..."
open build/app/outputs/apk/prod/release/ # Open the specific APK output directory 