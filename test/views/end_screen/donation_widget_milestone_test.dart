import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/donation/donation_page_provider.dart';
import 'package:medito/providers/donation/end_screen_milestone_experiment.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/views/end_screen/widgets/donation_thank_you_card.dart';
import 'package:medito/views/end_screen/widgets/donation_widget.dart';
import 'package:medito/views/previews/preview_support.dart';

LocalAllStats stats({int sessions = 0, int streak = 0}) => LocalAllStats(
  streakCurrent: streak,
  streakLongest: streak,
  totalTracksCompleted: sessions,
  totalTimeListened: 0,
  tracksChecked: const [],
  audioCompleted: const [],
  updated: 0,
  freezeUsageDates: const [],
);

class _FakeStats extends StatsNotifier {
  _FakeStats(this.value);
  final LocalAllStats value;

  @override
  Future<LocalAllStats> build() async => value;

  void arrive(LocalAllStats next) => state = AsyncValue.data(next);
}

void main() {
  setUp(() => EndScreenMilestoneExperiment.activeMilestone = null);

  late _FakeStats fake;

  Future<void> pump(
    WidgetTester tester, {
    required String arm,
    required LocalAllStats? prior,
    required LocalAllStats current,
    Map<String, Object> extraPrefs = const {},
    bool unmount = false,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      PreviewShell(
        locale: const Locale('en'),
        prefs: {
          SharedPreferenceConstants.endScreenMilestoneRefreshVariant: arm,
          ...extraPrefs,
        },
        overrides: [
          fetchDonationPageProvider.overrideWith(
            (ref) async => const DonationPageModel(
              title: 'Support Medito',
              text: 'Server copy',
              buttons: [ButtonModel()],
            ),
          ),
          endScreenPaywallConfigProvider.overrideWith(
            (ref) async => throw const NetworkConnectionError(),
          ),
          statsProvider.overrideWith(() => fake = _FakeStats(current)),
        ],
        child: Scaffold(
          body: SingleChildScrollView(
            child: unmount
                ? const SizedBox.shrink()
                : DonationWidget(priorStats: prior),
          ),
        ),
      ),
    );
    await tester.pump();
    if (!settle) return;
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('arm B shows the personal card on a session milestone', (
    tester,
  ) async {
    await pump(
      tester,
      arm: 'B',
      prior: stats(sessions: 24),
      current: stats(sessions: 25),
    );
    expect(find.text("That's 25 meditations with Medito."), findsOneWidget);
    expect(find.textContaining('people who use it chip in'), findsOneWidget);
    expect(find.text('Server copy'), findsNothing);
    // The ask itself is unchanged: same CTA as the normal card.
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(
      EndScreenMilestoneExperiment.activeMilestone,
      const EndScreenMilestone('sessions', 25),
    );
  });

  testWidgets('arm B shows the streak card on a streak milestone', (
    tester,
  ) async {
    await pump(
      tester,
      arm: 'B',
      prior: stats(sessions: 40, streak: 29),
      current: stats(sessions: 41, streak: 30),
    );
    expect(find.text('30 days in a row.'), findsOneWidget);
  });

  testWidgets('arm A keeps the normal card but still records the milestone', (
    tester,
  ) async {
    await pump(
      tester,
      arm: 'A',
      prior: stats(sessions: 24),
      current: stats(sessions: 25),
    );
    expect(find.text('Support Medito'), findsOneWidget);
    expect(find.text('Server copy'), findsOneWidget);
    expect(find.textContaining('25 meditations'), findsNothing);
    expect(
      EndScreenMilestoneExperiment.activeMilestone,
      const EndScreenMilestone('sessions', 25),
    );
  });

  testWidgets('arm B shows the normal card on an ordinary session', (
    tester,
  ) async {
    await pump(
      tester,
      arm: 'B',
      prior: stats(sessions: 25),
      current: stats(sessions: 26),
    );
    expect(find.text('Server copy'), findsOneWidget);
    expect(EndScreenMilestoneExperiment.activeMilestone, isNull);
  });

  testWidgets('no snapshot, no milestone', (tester) async {
    await pump(tester, arm: 'B', prior: null, current: stats(sessions: 5));
    expect(find.text('Server copy'), findsOneWidget);
  });

  testWidgets('a donor on a milestone still sees only the thank-you', (
    tester,
  ) async {
    final now = DateTime.now();
    await pump(
      tester,
      arm: 'B',
      prior: stats(sessions: 24),
      current: stats(sessions: 25),
      extraPrefs: {
        SharedPreferenceConstants.lastSuccessfulDonationAtMs:
            now.millisecondsSinceEpoch,
        SharedPreferenceConstants.donationAskSnoozedUntilMs: now
            .add(const Duration(days: 30))
            .millisecondsSinceEpoch,
      },
    );
    expect(find.byType(DonationThankYouCard), findsOneWidget);
    expect(find.textContaining('25 meditations'), findsNothing);
    expect(EndScreenMilestoneExperiment.activeMilestone, isNull);
  });

  // The end screen opens before the finished session reaches statsProvider.
  testWidgets('a milestone is still caught when the stats arrive late', (
    tester,
  ) async {
    await pump(
      tester,
      arm: 'B',
      prior: stats(sessions: 24),
      current: stats(sessions: 24),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(EndScreenMilestoneExperiment.activeMilestone, isNull);
    fake.arrive(stats(sessions: 25));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("That's 25 meditations with Medito."), findsOneWidget);
    expect(
      EndScreenMilestoneExperiment.activeMilestone,
      const EndScreenMilestone('sessions', 25),
    );
  });

  testWidgets('stats that never arrive fall back to the normal card', (
    tester,
  ) async {
    await pump(
      tester,
      arm: 'B',
      prior: stats(sessions: 24),
      current: stats(sessions: 24),
    );
    expect(find.text('Server copy'), findsOneWidget);
    expect(find.byType(ElevatedButton).hitTestable(), findsOneWidget);
    expect(EndScreenMilestoneExperiment.activeMilestone, isNull);
  });

  testWidgets('leaving the end screen clears the milestone on display', (
    tester,
  ) async {
    await pump(
      tester,
      arm: 'B',
      prior: stats(sessions: 24),
      current: stats(sessions: 25),
    );
    expect(EndScreenMilestoneExperiment.activeMilestone, isNotNull);
    await pump(
      tester,
      arm: 'B',
      prior: stats(sessions: 24),
      current: stats(sessions: 25),
      unmount: true,
    );
    expect(EndScreenMilestoneExperiment.activeMilestone, isNull);
  });
}
