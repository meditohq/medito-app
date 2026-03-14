#!/bin/bash
set -e

FLUTTER_VERSION="3.41.4"
FLUTTER_DIR="/opt/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git \
    --branch "$FLUTTER_VERSION" \
    --depth 1 \
    "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# Make flutter available to all users
echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> ~/.bashrc
echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> ~/.profile

flutter config --no-analytics
flutter precache --no-ios --no-macos --no-web --no-windows --no-linux --no-fuchsia
flutter pub get
