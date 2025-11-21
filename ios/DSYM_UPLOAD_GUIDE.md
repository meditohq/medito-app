# dSYM Upload Guide for Firebase Crashlytics

This guide explains how to upload dSYM files to Firebase Crashlytics for proper crash symbolication.

## Missing dSYM Upload

If Crashlytics reports a missing dSYM, you can upload it manually:

### For version 3.5.23 (build 30169) with UUID 4D1D782F-CCC2-3038-9298-5BB2D4D9393D:

```bash
cd ios
./upload_missing_dsym.sh 4D1D782F-CCC2-3038-9298-5BB2D4D9393D 3.5.23 30169
```

The script will automatically search common locations:
- `build/ios/archive/Runner.xcarchive`
- `~/Library/Developer/Xcode/Archives`
- `~/Library/Developer/Xcode/Products`

If the dSYM is found elsewhere, provide the path:

```bash
./upload_missing_dsym.sh 4D1D782F-CCC2-3038-9298-5BB2D4D9393D 3.5.23 30169 /path/to/Runner.xcarchive
```

### Manual Upload

If you have the archive or dSYM file:

```bash
# From archive
./upload_dsyms.sh /path/to/Runner.xcarchive

# Or upload all dSYMs from current build
./upload_dsyms.sh
```

## Automatic Upload Setup

### Option 1: Build Scripts (Already Configured)

The build scripts (`build_ios.sh` and `build_all.sh`) automatically upload dSYMs after archiving. No additional setup needed.

### Option 2: Xcode Build Phase

To automatically upload dSYMs when building from Xcode:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** target
3. Go to **Build Phases** tab
4. Click **+** → **New Run Script Phase**
5. Name it "Upload dSYMs to Firebase Crashlytics"
6. Drag it to run **after** "Thin Binary" phase
7. Add this script:

```bash
if [ -f "${PODS_ROOT}/FirebaseCrashlytics/upload-symbols" ]; then
  "${PODS_ROOT}/FirebaseCrashlytics/upload-symbols" -gsp "${PROJECT_DIR}/Runner/GoogleService-Info.plist" -p ios "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"
fi
```

8. Under **Input Files**, add:
   - `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}`

## Troubleshooting

### Script not found

Ensure CocoaPods dependencies are installed:

```bash
cd ios
pod install
```

### dSYM not found

1. Check if the archive exists: `ls -la build/ios/archive/`
2. Verify UUID matches: `dwarfdump -u /path/to/Runner.app.dSYM`
3. Check Xcode Organizer for archived builds

### Upload fails

- Verify `GoogleService-Info.plist` exists and is valid
- Check Firebase project configuration
- Ensure you have network access to Firebase servers

## Finding dSYM UUID

To find the UUID of a dSYM file:

```bash
dwarfdump -u /path/to/Runner.app.dSYM
```

## Notes

- dSYMs are automatically generated during Release builds
- Archives are stored in `build/ios/archive/` after building
- Xcode also stores archives in `~/Library/Developer/Xcode/Archives/`
- dSYM uploads are required for proper crash symbolication in Crashlytics

