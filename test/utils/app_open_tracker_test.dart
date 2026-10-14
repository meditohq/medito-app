import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/utils/app_open_tracker.dart';
import 'package:medito/utils/network_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tracker = AppOpenTracker.instance;
  late List<Map<String, Object>> opens;
  late DateTime clock;

  setUp(() {
    opens = [];
    clock = DateTime(2026, 10, 14, 9);
    AppOpenTracker.now = () => clock;
    AppOpenTracker.logSink = (name, params) async {
      expect(name, AnalyticsEventConstants.appOpen);
      opens.add(params);
    };
    NetworkType.source = () async => [ConnectivityResult.wifi];
    tracker.resetForTesting();
  });

  test('cold start logs once with launch and network type', () async {
    await tracker.onColdStart();
    // The initial resume some platforms deliver on launch must not double-log.
    await tracker.onForegrounded();

    expect(opens, hasLength(1));
    expect(opens.single[AnalyticsEventConstants.paramLaunchType], 'cold');
    expect(opens.single[AnalyticsEventConstants.paramNetworkType], 'wifi');
  });

  test('short trips away do not count as a new open', () async {
    tracker.onBackgrounded();
    clock = clock.add(const Duration(minutes: 29));
    await tracker.onForegrounded();
    expect(opens, isEmpty);
  });

  test('resume after 30+ min logs, with the network at resume time', () async {
    tracker.onBackgrounded();
    clock = clock.add(const Duration(minutes: 30));
    NetworkType.source = () async => [ConnectivityResult.mobile];
    await tracker.onForegrounded();

    expect(opens, hasLength(1));
    expect(opens.single[AnalyticsEventConstants.paramLaunchType], 'resume');
    expect(opens.single[AnalyticsEventConstants.paramNetworkType], 'mobile');
  });

  test('away time runs from the first background, not the last', () async {
    tracker.onBackgrounded();
    clock = clock.add(const Duration(minutes: 20));
    tracker.onBackgrounded(); // e.g. a second pause/detached callback
    clock = clock.add(const Duration(minutes: 15));
    await tracker.onForegrounded();
    expect(opens, hasLength(1));
  });
}
