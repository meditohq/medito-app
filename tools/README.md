# Medito Tools

## Debug Print Replacer

This tool helps to replace all `debugPrint` statements in the codebase with proper `AppLogger` calls
that only log in debug mode. This ensures no debug logs are shown in production builds.

### Usage

1. Make sure you have the latest Dart SDK installed.
2. Run the script from the project root directory:

```bash
cd /path/to/medito_new
dart tools/replace_debug_print.dart
```

The script will:
1. Find all files containing `debugPrint` calls
2. Add the required import for the logger
3. Replace `debugPrint` calls with appropriate `AppLogger` methods based on content:
   - `AppLogger.e()` for error messages
   - `AppLogger.w()` for warning messages
   - `AppLogger.i()` for info messages
   - `AppLogger.d()` for regular debug messages
4. Attempt to determine an appropriate tag for each log based on the file name

### After Running

After running the script, you should:

1. Review all changes carefully
2. Test the app in debug mode to ensure logs still appear
3. Test the app in release mode to confirm logs do not appear in production builds

### Making Manual Adjustments

You may need to manually adjust some replacements for better context or filtering. Consider:

- Providing more specific tags for each module
- Adjusting log levels where the automatic detection wasn't accurate
- Ensuring proper formatting of log messages

## Logging Best Practices

When using the AppLogger, follow these guidelines:

1. Use appropriate log levels:
   - `d()` for general debug information
   - `i()` for noteworthy but expected events
   - `w()` for potential issues that aren't errors
   - `e()` for errors or exceptions

2. Use consistent tags for each module/component for easier filtering

3. Include relevant context in log messages while avoiding sensitive information 