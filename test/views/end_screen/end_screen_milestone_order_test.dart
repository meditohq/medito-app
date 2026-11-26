import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/me/me_model.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/donation/donation_page_provider.dart';
import 'package:medito/providers/donation/end_screen_milestone_experiment.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/providers/settings/reminder_prompt_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/views/end_screen/end_screen_view.dart';
import 'package:medito/views/end_screen/widgets/donation_widget.dart';
import 'package:medito/views/end_screen/widgets/soft_ask_card.dart';
import 'package:medito/views/previews/preview_support.dart';

const _request = PlaybackRequest(
  trackId: 'preview',
  fileId: 'preview-file',
  title: 'Noting Thoughts',
  description: '',
  coverUrl: '',
  remoteUrl: 'https://example.test/audio.mp3',
  duration: 600000,
  hasBackgroundSound: false,
);

LocalAllStats _stats(int sessions) => LocalAllStats(
  streakCurrent: 1,
  streakLongest: 1,
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
}

void main() {
  setUp(() => EndScreenMilestoneExperiment.activeMilestone = null);

  Future<void> pump(
    WidgetTester tester, {
    required String arm,
    required int from,
    required int to,
  }) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PreviewShell(
        locale: const Locale('en'),
        prefs: {
          SharedPreferenceConstants.endScreenMilestoneRefreshVariant: arm,
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
          statsProvider.overrideWith(() => _FakeStats(_stats(to))),
          shouldShowReminderPromptProvider.overrideWithValue(true),
          meProvider.overrideWith((ref) async => const MeModel(id: 'preview')),
        ],
        child: EndScreenView(request: _request, priorStats: _stats(from)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 2));
  }

  double top(WidgetTester tester, Type type) =>
      tester.getTopLeft(find.byType(type)).dy;

  testWidgets('arm B puts the milestone card above the reminders card', (
    tester,
  ) async {
    await pump(tester, arm: 'B', from: 24, to: 25);
    expect(find.text("That's 25 meditations with Medito."), findsOneWidget);
    expect(find.byType(SoftAskCard), findsOneWidget);
    expect(top(tester, DonationWidget), lessThan(top(tester, SoftAskCard)));
  });

  testWidgets('arm B keeps the usual order on an ordinary session', (
    tester,
  ) async {
    await pump(tester, arm: 'B', from: 25, to: 26);
    expect(top(tester, SoftAskCard), lessThan(top(tester, DonationWidget)));
  });

  testWidgets('arm A keeps the usual order on a milestone session', (
    tester,
  ) async {
    await pump(tester, arm: 'A', from: 24, to: 25);
    expect(find.text('Server copy'), findsOneWidget);
    expect(top(tester, SoftAskCard), lessThan(top(tester, DonationWidget)));
  });
}
