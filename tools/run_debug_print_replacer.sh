#!/bin/bash

# Change to the project root directory, assuming the script is run from the tools directory
if [[ $(basename $(pwd)) = "tools" ]]; then
  cd ..
fi

# Check if the script exists
if [ ! -f "tools/replace_debug_print.dart" ]; then
  echo "Error: replace_debug_print.dart not found in the tools directory."
  exit 1
fi

# Run the script
echo "Starting to replace debugPrint calls with AppLogger..."
dart tools/replace_debug_print.dart

# Make the script executable if it wasn't already
chmod +x tools/replace_debug_print.dart

# Prompt user to review changes
echo ""
echo "Script completed. Please review all changes carefully before committing."
echo "You can do this using: git diff" 