// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  // Regular expressions to detect different patterns of debugPrint usage
  final debugPrintPattern = RegExp(r'debugPrint\((.*?)\);');
  final debugPrintStackPattern = RegExp(
    r'debugPrintStack\(stackTrace: (.*?)\);',
  );

  // Files to process
  final result = await Process.run('find', [
    '.',
    '-type',
    'f',
    '-name',
    '*.dart',
    '-not',
    '-path',
    '*/build/*',
    '-not',
    '-path',
    '*/\\.dart_tool/*',
    '-exec',
    'grep',
    '-l',
    'debugPrint',
    '{}',
    ';',
  ]);

  if (result.exitCode != 0) {
    print('Error finding files: ${result.stderr}');
    exit(1);
  }

  final files = (result.stdout as String).trim().split('\n');

  // Skip the logger.dart file itself
  files.removeWhere((file) => file.endsWith('logger.dart'));

  print('Found ${files.length} files with debugPrint calls.');

  // Process each file
  for (final file in files) {
    if (file.isEmpty) continue;

    print('Processing $file');

    try {
      final fileContent = await File(file).readAsString();
      var updatedContent = fileContent;

      // Add the logger import if not present
      if (!updatedContent.contains(
            "import 'package:medito/utils/logger.dart';",
          ) &&
          !updatedContent.contains("import '../utils/logger.dart';") &&
          !updatedContent.contains("import '../../utils/logger.dart';") &&
          !updatedContent.contains("import 'logger.dart';")) {
        // Determine the correct import path
        String importPath = 'package:medito/utils/logger.dart';

        // If file is in /lib/utils/ folder, use relative import
        if (file.startsWith('./lib/utils/')) {
          importPath = 'logger.dart';
        } else if (file.startsWith('./lib/')) {
          // Count the directory depth from lib
          final parts = file.substring('./lib/'.length).split('/');
          final depth = parts.length - 1; // exclude the file itself

          if (depth == 0) {
            importPath = 'utils/logger.dart';
          } else {
            importPath = '${'../' * (depth - 1)}../utils/logger.dart';
          }
        }

        // Add import after other imports
        final importLines = updatedContent
            .split('\n')
            .takeWhile(
              (line) => line.trim().startsWith('import') || line.trim().isEmpty,
            )
            .toList();

        if (importLines.isNotEmpty) {
          final lastImportIndex =
              updatedContent.lastIndexOf(importLines.last) +
              importLines.last.length;
          updatedContent =
              '${updatedContent.substring(0, lastImportIndex)}\nimport \'$importPath\';${updatedContent.substring(lastImportIndex)}';
        }
      }

      // Try to determine appropriate tag for logger
      String tag = 'GENERAL';

      final fileName = file
          .split('/')
          .last
          .replaceAll('.dart', '')
          .toUpperCase();
      if (fileName.contains('_')) {
        tag = fileName.split('_').first;
      } else {
        tag = fileName;
      }

      // Replace debugPrintStack
      updatedContent = updatedContent.replaceAllMapped(
        debugPrintStackPattern,
        (match) => 'AppLogger.e(\'$tag\', \'Error\', null, ${match.group(1)});',
      );

      // Replace debugPrint with log level based on content
      updatedContent = updatedContent.replaceAllMapped(debugPrintPattern, (
        match,
      ) {
        final content = match.group(1)!;
        if (content.toLowerCase().contains('error') ||
            content.contains('❌') ||
            content.contains('Failed') ||
            content.contains('Exception')) {
          return 'AppLogger.e(\'$tag\', $content);';
        } else if (content.contains('⚠️')) {
          return 'AppLogger.w(\'$tag\', $content);';
        } else if (content.contains('ℹ️')) {
          return 'AppLogger.i(\'$tag\', $content);';
        } else {
          return 'AppLogger.d(\'$tag\', $content);';
        }
      });

      // Write the updated content back to the file
      if (updatedContent != fileContent) {
        await File(file).writeAsString(updatedContent);
        print('Updated $file');
      } else {
        print('No changes needed for $file');
      }
    } catch (e) {
      print('Error processing $file: $e');
    }
  }

  print('\nFinished processing files. Please review the changes manually.');
}
