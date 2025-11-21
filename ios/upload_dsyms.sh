#!/bin/bash

# Script to upload dSYM files to Firebase Crashlytics
# Usage: ./upload_dsyms.sh [path_to_xcarchive] [path_to_GoogleService-Info.plist]

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ARCHIVE_PATH="${1:-$PROJECT_ROOT/build/ios/archive/Runner.xcarchive}"
GOOGLE_SERVICE_INFO="${2:-$SCRIPT_DIR/Runner/GoogleService-Info.plist}"

# Convert to absolute paths if they exist
if [ -d "$(dirname "$ARCHIVE_PATH")" ]; then
    ARCHIVE_PATH="$(cd "$(dirname "$ARCHIVE_PATH")" && pwd)/$(basename "$ARCHIVE_PATH")"
fi
if [ -d "$(dirname "$GOOGLE_SERVICE_INFO")" ]; then
    GOOGLE_SERVICE_INFO="$(cd "$(dirname "$GOOGLE_SERVICE_INFO")" && pwd)/$(basename "$GOOGLE_SERVICE_INFO")"
fi

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "Error: Archive not found at $ARCHIVE_PATH"
    echo "Usage: $0 [path_to_xcarchive] [path_to_GoogleService-Info.plist]"
    exit 1
fi

if [ ! -f "$GOOGLE_SERVICE_INFO" ]; then
    echo "Error: GoogleService-Info.plist not found at $GOOGLE_SERVICE_INFO"
    exit 1
fi

# Find the upload-symbols script
UPLOAD_SYMBOLS_SCRIPT="${PODS_ROOT}/FirebaseCrashlytics/upload-symbols"

if [ ! -f "$UPLOAD_SYMBOLS_SCRIPT" ]; then
    # Try alternative locations
    UPLOAD_SYMBOLS_SCRIPT="$SCRIPT_DIR/Pods/FirebaseCrashlytics/upload-symbols"
    
    if [ ! -f "$UPLOAD_SYMBOLS_SCRIPT" ]; then
        UPLOAD_SYMBOLS_SCRIPT="$PROJECT_ROOT/ios/Pods/FirebaseCrashlytics/upload-symbols"
    fi
    
    if [ ! -f "$UPLOAD_SYMBOLS_SCRIPT" ]; then
        echo "Error: Firebase Crashlytics upload-symbols script not found."
        echo "Please ensure FirebaseCrashlytics pod is installed."
        echo "Run: cd ios && pod install"
        exit 1
    fi
fi

# Find dSYM files in the archive
DSYM_PATH="${ARCHIVE_PATH}/dSYMs"
if [ ! -d "$DSYM_PATH" ]; then
    echo "Error: dSYMs directory not found in archive at $DSYM_PATH"
    exit 1
fi

echo "Uploading dSYMs from $ARCHIVE_PATH to Firebase Crashlytics..."
echo "Using GoogleService-Info.plist: $GOOGLE_SERVICE_INFO"

# Upload all dSYM files
find "$DSYM_PATH" -name "*.dSYM" -print0 | while IFS= read -r -d '' dsym; do
    echo "Uploading: $dsym"
    "$UPLOAD_SYMBOLS_SCRIPT" -gsp "$GOOGLE_SERVICE_INFO" -p ios "$dsym"
done

echo "✅ dSYM upload completed"

