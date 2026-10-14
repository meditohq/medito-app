import 'package:connectivity_plus/connectivity_plus.dart';

import 'logger.dart';

/// The `network_type` analytics param: wifi | mobile | ethernet | none |
/// other | unknown. A permission-free "probably at home" proxy — we never read
/// the SSID, which would need location permission.
class NetworkType {
  NetworkType._();

  /// Source of the raw connectivity list. Overridable in tests, where the
  /// connectivity platform channel isn't available.
  static Future<List<ConnectivityResult>> Function() source = () =>
      Connectivity().checkConnectivity();

  /// Collapses the connectivity list to one value. A VPN reports alongside the
  /// underlying transport, so the physical link wins; the lookup is capped so
  /// a slow platform call can't hold up the event it's attached to.
  static Future<String> current() async {
    try {
      final results = await source().timeout(const Duration(milliseconds: 500));
      if (results.contains(ConnectivityResult.wifi)) return 'wifi';
      if (results.contains(ConnectivityResult.ethernet)) return 'ethernet';
      if (results.contains(ConnectivityResult.mobile)) return 'mobile';
      if (results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none)) {
        return 'none';
      }
      return 'other';
    } catch (e) {
      AppLogger.e('NETWORK', 'Failed to read connectivity', e);
      return 'unknown';
    }
  }
}
