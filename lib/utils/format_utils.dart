import 'package:medito/utils/duration_extensions.dart';

/// Utility class for formatting values for display
class FormatUtils {
  /// Format the total minutes listened into a display string
  static String formatMinutesToDisplay(int totalMinutes) {
    if (totalMinutes < 60) {
      return '$totalMinutes min';
    } else {
      var hours = totalMinutes ~/ 60;
      var minutes = totalMinutes % 60;

      if (minutes == 0) {
        return '$hours hr';
      } else {
        return '$hours hr $minutes min';
      }
    }
  }

  /// Formats a duration in seconds to a readable format
  static String formatDurationFromSeconds(int seconds) {
    var duration = Duration(seconds: seconds);
    return duration.toReadable();
  }
}
