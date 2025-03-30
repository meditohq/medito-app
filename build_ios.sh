#!/bin/sh
set -e # Exit immediately if a command exits with a non-zero status.

echo "Cleaning project..."
flutter clean

echo "Building Flutter iOS release..."
flutter build ios --release --dart-define-from-file=../.prod.json

echo "Changing directory to ios..."
cd ios

echo "Archiving Xcode project..."
# Ensure Runner.xcworkspace and Runner scheme are correct for your project.
# If you use flavors, your scheme might be different (e.g., 'prod').
xcodebuild archive \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath $PWD/build/Runner.xcarchive

echo "Returning to project root..."
cd ..

echo "iOS Archive complete! Find it in ios/build/Runner.xcarchive" 