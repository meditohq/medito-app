import '../utils/utils.dart';

/// Service for handling report URL generation and launching
class ReportService {
  static const String _tallyFormBaseUrl = 'https://tally.so/r/wz9Nyq';

  /// Generates the report URL with the required parameters
  static String generateReportUrl({
    required String locale,
    required String trackId,
    required int timestamp,
  }) {
    final uri = Uri.parse(_tallyFormBaseUrl).replace(
      queryParameters: {
        'locale': locale,
        'track_id': trackId,
        'timestamp': timestamp.toString(),
      },
    );

    return uri.toString();
  }

  /// Launches the report form in the browser with the provided parameters
  static Future<void> launchReportForm({
    required String locale,
    required String trackId,
    required int timestamp,
  }) async {
    final url = generateReportUrl(
      locale: locale,
      trackId: trackId,
      timestamp: timestamp,
    );

    await launchURLInBrowser(url);
  }
}
