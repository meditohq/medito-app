#!/bin/zsh

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --android-only    Build and deploy Android only"
    echo "  --ios-only        Build and deploy iOS only"
    echo "  --help           Show this help message"
    echo ""
    echo "Without any flags, builds both Android and iOS"
    echo ""
    exit 0
}

# Parse command line arguments
BUILD_ANDROID=true
BUILD_IOS=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --android-only)
            BUILD_ANDROID=true
            BUILD_IOS=false
            shift
            ;;
        --ios-only)
            BUILD_ANDROID=false
            BUILD_IOS=true
            shift
            ;;
        --help)
            show_usage
            ;;
        *)
            print_colored $RED "❌ Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_colored $GREEN "🚀 Medito Build & Deploy Script"
print_colored $GREEN "==============================="

if [ "$BUILD_ANDROID" = true ] && [ "$BUILD_IOS" = true ]; then
    print_colored $BLUE "This script will build both Android and iOS apps"
elif [ "$BUILD_ANDROID" = true ]; then
    print_colored $BLUE "This script will build Android app only"
elif [ "$BUILD_IOS" = true ]; then
    print_colored $BLUE "This script will build iOS app only"
fi

print_colored $BLUE "You'll choose the paywall environment below"
echo ""

# Get the current version from pubspec.yaml
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')

# Get the version and relative date from the last commit where pubspec.yaml was changed
LAST_COMMITTED_VERSION=$(git show HEAD:pubspec.yaml | grep '^version:' | awk '{print $2}')
LAST_COMMIT_DATE_AGO=$(git log -1 --pretty=format:%ar -- pubspec.yaml)

print_colored $BLUE "Current version: $CURRENT_VERSION"
print_colored $BLUE "Last committed version for pubspec.yaml: $LAST_COMMITTED_VERSION (committed $LAST_COMMIT_DATE_AGO)"

# Check if the version has been updated
if [ "$CURRENT_VERSION" = "$LAST_COMMITTED_VERSION" ]; then
    print_colored $YELLOW "⚠️ The version in pubspec.yaml ($CURRENT_VERSION) has not been updated since the last commit ($LAST_COMMIT_DATE_AGO)."
    echo -n "Do you want to continue building with this version? (y/N): "
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_colored $RED "🛑 Build cancelled. Please update the version in pubspec.yaml and commit the change."
        exit 1
    fi
fi

# Paywall environment selection
print_colored $BLUE "🎯 Paywall Environment Selection"
print_colored $BLUE "================================"
echo "1) Live paywalls (for production users)"
echo "2) Dev paywalls (for testing)"
echo ""
echo -n "Select paywall environment (1-2): "
read paywall_choice

case $paywall_choice in
    1)
        PAYWALL_ENV="live"
        print_colored $GREEN "✅ Selected: Live paywalls"
        ;;
    2)
        PAYWALL_ENV="dev"
        print_colored $YELLOW "🧪 Selected: Dev paywalls"
        print_colored $YELLOW "⚠️  WARNING: You are building with DEV paywalls!"
        print_colored $YELLOW "   Make sure this is for testing only, not production deployment."
        echo ""
        print_colored $YELLOW "Are you sure you want to continue with DEV paywalls? (y/N): "
        read dev_confirm
        if [[ ! "$dev_confirm" =~ ^[Yy]$ ]]; then
            print_colored $RED "❌ Build cancelled."
            exit 1
        fi
        ;;
    *)
        print_colored $RED "❌ Invalid selection. Please run the script again."
        exit 1
        ;;
esac

# Play Console upload selection (before building)
UPLOAD_TO_PLAY_STORE=false
PLAY_STORE_TRACK=""

if [ "$BUILD_ANDROID" = true ]; then
    echo ""
    print_colored $BLUE "📤 Play Console Upload Selection"
    print_colored $BLUE "=================================="
    echo -n "Do you want to upload the APK to Google Play Console after building? (y/N): "
    read upload_choice

    if [[ "$upload_choice" =~ ^[Yy]$ ]]; then
        UPLOAD_TO_PLAY_STORE=true
        
        # Determine track based on paywall environment
        if [ "$PAYWALL_ENV" = "dev" ]; then
            PLAY_STORE_TRACK="internal"
            print_colored $YELLOW "Will upload to 'internal' track (dev paywalls)"
        else
            echo ""
            print_colored $BLUE "Select Play Console track:"
            echo "1) internal (for internal testing)"
            echo "2) beta (for beta testing)"
            echo "3) production (for production release)"
            echo ""
            echo -n "Select track (1-3, default: 1): "
            read track_choice
            
            case $track_choice in
                2)
                    PLAY_STORE_TRACK="beta"
                    ;;
                3)
                    PLAY_STORE_TRACK="production"
                    print_colored $YELLOW "⚠️  Will upload to PRODUCTION track!"
                    echo -n "Are you sure? (y/N): "
                    read prod_confirm
                    if [[ ! "$prod_confirm" =~ ^[Yy]$ ]]; then
                        print_colored $YELLOW "Upload cancelled."
                        UPLOAD_TO_PLAY_STORE=false
                        PLAY_STORE_TRACK=""
                    fi
                    ;;
                *)
                    PLAY_STORE_TRACK="internal"
                    ;;
            esac
        fi
    fi
fi

echo ""
echo "🧪 Running Flutter tests..."
flutter test

# Generate common variables
DATED_APKS_DIR="dated_apks"
DATE_STAMP=$(date +"%d%b%Y")

# Android build section
if [ "$BUILD_ANDROID" = true ]; then
    print_colored $BLUE "🚀 Starting Android build and deploy..."
    print_colored $BLUE "Paywall environment: $PAYWALL_ENV"

    # Build Android APK with paywall environment
    flutter build apk --flavor prod --release --dart-define-from-file=../.prod.json --dart-define=PAYWALL_ENV=$PAYWALL_ENV

    # Create dated APKs directory if it doesn't exist
    mkdir -p "$DATED_APKS_DIR"

    SOURCE_APK="build/app/outputs/apk/prod/release/app-prod-release.apk"
    DEST_APK="$DATED_APKS_DIR/medito-$CURRENT_VERSION-$PAYWALL_ENV-paywall-$DATE_STAMP.apk"

    # Copy the APK with the new name
    cp "$SOURCE_APK" "$DEST_APK"
    print_colored $GREEN "✅ APK copied to $DEST_APK"
    if [ "$PAYWALL_ENV" = "dev" ]; then
        print_colored $YELLOW "⚠️  This build has DEV paywalls - do NOT deploy to production!"
    else
        print_colored $GREEN "✅ This build has LIVE paywalls - safe for production deployment"
    fi

    # Upload to Play Console if requested
    if [ "$UPLOAD_TO_PLAY_STORE" = true ] && [ -n "$PLAY_STORE_TRACK" ]; then
        echo ""
        print_colored $BLUE "📤 Uploading APK to Play Console ($PLAY_STORE_TRACK track)..."
        
        # Check if Google Play API key exists (try multiple locations)
        PLAY_API_KEY=""
        if [ -f "../play-store-credentials.json" ]; then
            PLAY_API_KEY="../play-store-credentials.json"
        elif [ -f "android/fastlane/keys/google-play-api-key.json" ]; then
            PLAY_API_KEY="android/fastlane/keys/google-play-api-key.json"
        fi
        
        if [ -z "$PLAY_API_KEY" ]; then
            print_colored $RED "❌ Google Play API key not found"
            print_colored $YELLOW "Checked locations:"
            print_colored $YELLOW "  - ../play-store-credentials.json"
            print_colored $YELLOW "  - android/fastlane/keys/google-play-api-key.json"
            print_colored $YELLOW "Please ensure the API key file exists before uploading."
        else
            print_colored $GREEN "✅ Found Google Play credentials at: $PLAY_API_KEY"
            
            # Get absolute paths
            ABS_APK_PATH="$(pwd)/$SOURCE_APK"
            
            # Convert credentials path to absolute
            if [[ "$PLAY_API_KEY" == /* ]]; then
                ABS_CREDENTIALS_PATH="$PLAY_API_KEY"
            elif [[ "$PLAY_API_KEY" == ../* ]]; then
                ABS_CREDENTIALS_PATH="$(cd .. && pwd)/$(basename "$PLAY_API_KEY")"
            else
                ABS_CREDENTIALS_PATH="$(pwd)/$PLAY_API_KEY"
            fi
            
            # Change to android directory to run Fastlane
            cd android
            
            # Check if bundle is available
            if command -v bundle &> /dev/null; then
                # Check if Gemfile exists and install dependencies if needed
                if [ -f "Gemfile" ]; then
                    print_colored $BLUE "📦 Installing Fastlane dependencies..."
                    bundle install
                fi
                bundle exec fastlane android upload_apk apk_path:"$ABS_APK_PATH" track:"$PLAY_STORE_TRACK" json_key:"$ABS_CREDENTIALS_PATH"
            else
                print_colored $YELLOW "⚠️  bundle not found, trying fastlane directly..."
                fastlane android upload_apk apk_path:"$ABS_APK_PATH" track:"$PLAY_STORE_TRACK" json_key:"$ABS_CREDENTIALS_PATH"
            fi
            
            UPLOAD_RESULT=$?
            cd ..
            
            if [ $UPLOAD_RESULT -eq 0 ]; then
                print_colored $GREEN "✅ APK uploaded to Play Console successfully!"
                print_colored $BLUE "Track: $PLAY_STORE_TRACK"
            else
                print_colored $RED "❌ Failed to upload APK to Play Console"
                print_colored $YELLOW "APK is still available at: $DEST_APK"
            fi
        fi
    fi

    # Open the dated APKs directory
    echo ""
    print_colored $BLUE "✅ Android build completed! Opening dated APKs directory..."
    open "$DATED_APKS_DIR"
else
    print_colored $YELLOW "⏭️  Skipping Android build (--ios-only flag used)"
fi

# iOS build section
if [ "$BUILD_IOS" = true ]; then
    print_colored $BLUE "🚀 Starting iOS build and upload..."
    print_colored $BLUE "Paywall environment: $PAYWALL_ENV"

    # Source credentials from a separate, ignored file
    if [ -f "ios_credentials.sh" ]; then
        source ios_credentials.sh
    else
        print_colored $YELLOW "⚠️ 'ios_credentials.sh' not found. You may be prompted for credentials."
    fi

    # Build iOS with paywall environment
    flutter build ios --dart-define-from-file=../.prod.json --dart-define=ENABLE_DEVICE_PREVIEW=false --dart-define=PAYWALL_ENV=$PAYWALL_ENV --release

    # Archive and export
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
        print_colored $BLUE "📤 Uploading dSYMs to Firebase Crashlytics..."
        ios/upload_dsyms.sh "$ARCHIVE_PATH"
    else
        print_colored $YELLOW "⚠️  upload_dsyms.sh not found. Skipping dSYM upload."
    fi

    # Export the .ipa
    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE_PATH" \
      -exportPath "$EXPORT_PATH" \
      -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

    IPA_PATH="$EXPORT_PATH/Runner.ipa"

    if [ -f "$IPA_PATH" ]; then
        # Rename IPA with paywall environment
        NEW_IPA_PATH="$EXPORT_PATH/medito-${CURRENT_VERSION}-${PAYWALL_ENV}-paywall-${DATE_STAMP}.ipa"
        cp "$IPA_PATH" "$NEW_IPA_PATH"
        
        print_colored $GREEN "✅ iOS IPA built: $NEW_IPA_PATH"
        if [ "$PAYWALL_ENV" = "dev" ]; then
            print_colored $YELLOW "⚠️  This build has DEV paywalls - do NOT deploy to production!"
        else
            print_colored $GREEN "✅ This build has LIVE paywalls - safe for production deployment"
        fi
    else
        print_colored $RED "❌ Failed to build iOS IPA"
        exit 1
    fi

    print_colored $BLUE "📤 Uploading to TestFlight..."

    # Check for environment variables first
    if [ -z "$APPLE_ID_ENV" ] || [ -z "$APP_SPECIFIC_PASSWORD_ENV" ]; then
        print_colored $YELLOW "Environment variables APPLE_ID_ENV or APP_SPECIFIC_PASSWORD_ENV not set. Falling back to manual input."
        echo "Enter your Apple ID: "
        read APPLE_ID
        echo "Enter your app-specific password (https://appleid.apple.com/account/manage): "
        read -s APP_PASSWORD
    else
        print_colored $GREEN "Using credentials from environment variables."
        APPLE_ID="$APPLE_ID_ENV"
        APP_PASSWORD="$APP_SPECIFIC_PASSWORD_ENV"
    fi

    xcrun altool --upload-app -f "$IPA_PATH" -t ios -u "$APPLE_ID" -p "$APP_PASSWORD"

    if [ $? -eq 0 ]; then
        print_colored $GREEN "✅ iOS app uploaded to TestFlight successfully"
    else
        print_colored $RED "❌ iOS upload failed"
        exit 1
    fi

    # Clean up environment variables
    if [ -n "$APPLE_ID_ENV" ]; then
        unset APPLE_ID_ENV
    fi
    if [ -n "$APP_SPECIFIC_PASSWORD_ENV" ]; then
        unset APP_SPECIFIC_PASSWORD_ENV
    fi
else
    print_colored $YELLOW "⏭️  Skipping iOS build (--android-only flag used)"
fi

# Final summary
echo ""
print_colored $GREEN "🎉 Build and Deploy Complete!"
print_colored $GREEN "============================="
print_colored $BLUE "Version: $CURRENT_VERSION"
print_colored $BLUE "Paywall Environment: $PAYWALL_ENV"

# Show which platforms were built
if [ "$BUILD_ANDROID" = true ] && [ "$BUILD_IOS" = true ]; then
    print_colored $BLUE "Platforms: Android & iOS"
elif [ "$BUILD_ANDROID" = true ]; then
    print_colored $BLUE "Platforms: Android only"
elif [ "$BUILD_IOS" = true ]; then
    print_colored $BLUE "Platforms: iOS only"
fi

echo ""
if [ "$PAYWALL_ENV" = "dev" ]; then
    print_colored $YELLOW "⚠️  REMINDER: This build has DEV paywalls"
    print_colored $YELLOW "   Safe for: TestFlight, Play Store Internal Testing"
    print_colored $YELLOW "   NOT safe for: Production deployment"
else
    print_colored $GREEN "✅ This build has LIVE paywalls"
    print_colored $GREEN "   Safe for: Production deployment"
fi
echo ""

# Only open Telegram if at least one build was completed
if [ "$BUILD_ANDROID" = true ] || [ "$BUILD_IOS" = true ]; then
    print_colored $BLUE "📤 Opening Telegram for easy sharing..."
    open -a "Telegram"
fi
