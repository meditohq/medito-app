#!/bin/bash

# Script to upload a specific missing dSYM to Firebase Crashlytics
# Usage: ./upload_missing_dsym.sh [dSYM_UUID] [version] [build_number]

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DSYM_UUID="${1:-4D1D782F-CCC2-3038-9298-5BB2D4D9393D}"
VERSION="${2:-3.5.23}"
BUILD_NUMBER="${3:-30169}"

# Find GoogleService-Info.plist relative to script location
GOOGLE_SERVICE_INFO="$SCRIPT_DIR/Runner/GoogleService-Info.plist"
if [ ! -f "$GOOGLE_SERVICE_INFO" ]; then
    # Try from project root
    GOOGLE_SERVICE_INFO="$PROJECT_ROOT/ios/Runner/GoogleService-Info.plist"
fi

if [ ! -f "$GOOGLE_SERVICE_INFO" ]; then
    echo "Error: GoogleService-Info.plist not found at $GOOGLE_SERVICE_INFO"
    exit 1
fi

# Find the upload-symbols script
UPLOAD_SYMBOLS_SCRIPT="${PODS_ROOT}/FirebaseCrashlytics/upload-symbols"

if [ ! -f "$UPLOAD_SYMBOLS_SCRIPT" ]; then
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

echo "Looking for dSYM with UUID: $DSYM_UUID"
echo "Version: $VERSION (Build: $BUILD_NUMBER)"
echo ""

# Common locations to search for archives (use absolute paths)
SEARCH_PATHS=(
    "$PROJECT_ROOT/build/ios/archive/Runner.xcarchive"
    "$HOME/Library/Developer/Xcode/Archives"
    "$HOME/Library/Developer/Xcode/Products"
)

FOUND_DSYM=""

# Search for dSYM files matching the UUID
for archive_path in "${SEARCH_PATHS[@]}"; do
    if [ -d "$archive_path" ]; then
        echo "Searching in: $archive_path"
        
        # Search recursively for dSYM files
        while IFS= read -r -d '' dsym; do
            # Check UUID using dwarfdump
            uuid_output=$(dwarfdump -u "$dsym" 2>/dev/null || echo "")
            
            if echo "$uuid_output" | grep -q "$DSYM_UUID"; then
                FOUND_DSYM="$dsym"
                echo "✅ Found matching dSYM: $dsym"
                break
            fi
        done < <(find "$archive_path" -name "*.dSYM" -type d -print0 2>/dev/null || true)
        
        if [ -n "$FOUND_DSYM" ]; then
            break
        fi
    fi
done

if [ -z "$FOUND_DSYM" ]; then
    echo ""
    echo "❌ dSYM with UUID $DSYM_UUID not found in common locations."
    echo ""
    echo "Please provide the path to the dSYM file manually:"
    echo "  $0 $DSYM_UUID $VERSION $BUILD_NUMBER /path/to/Runner.app.dSYM"
    echo ""
    echo "Or if you have the archive:"
    echo "  $0 $DSYM_UUID $VERSION $BUILD_NUMBER /path/to/Runner.xcarchive"
    exit 1
fi

# If a path was provided as 4th argument, use it
if [ -n "$4" ]; then
    if [ -d "$4" ] && [[ "$4" == *.xcarchive ]]; then
        # It's an archive, find dSYM inside
        DSYM_PATH="$4/dSYMs"
        if [ -d "$DSYM_PATH" ]; then
            echo "Searching for matching dSYM in archive: $4"
            while IFS= read -r -d '' dsym; do
                uuid_output=$(dwarfdump -u "$dsym" 2>/dev/null || echo "")
                if echo "$uuid_output" | grep -q "$DSYM_UUID"; then
                    FOUND_DSYM="$dsym"
                    echo "✅ Found matching dSYM: $dsym"
                    break
                fi
            done < <(find "$DSYM_PATH" -name "*.dSYM" -type d -print0 2>/dev/null || true)
        fi
    elif [ -d "$4" ] && [[ "$4" == *.dSYM ]]; then
        FOUND_DSYM="$4"
    fi
fi

if [ -z "$FOUND_DSYM" ] || [ ! -d "$FOUND_DSYM" ]; then
    echo "Error: dSYM file not found or invalid"
    exit 1
fi

echo ""
echo "Uploading dSYM to Firebase Crashlytics..."
echo "dSYM: $FOUND_DSYM"
echo "UUID: $DSYM_UUID"
echo ""

"$UPLOAD_SYMBOLS_SCRIPT" -gsp "$GOOGLE_SERVICE_INFO" -p ios "$FOUND_DSYM"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully uploaded dSYM for version $VERSION (build $BUILD_NUMBER)"
    echo "UUID: $DSYM_UUID"
else
    echo ""
    echo "❌ Failed to upload dSYM"
    exit 1
fi

