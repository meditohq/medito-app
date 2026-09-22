import 'package:medito/views/home/widgets/quote/quote_share_sheet.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/models/me/me_model.dart';

import 'package:medito/views/explore/widgets/explore_view.dart';
import 'package:medito/views/search/search_view.dart';
import 'package:medito/views/pack/pack_view.dart';
import 'package:medito/views/track/track_view.dart';
import 'package:medito/views/end_screen/end_screen_view.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/models/track/track.dart' as model;
import 'package:medito/providers/tags/tags_provider.dart';
import 'package:medito/models/tags/tag_model.dart';
import 'package:medito/providers/review_service_provider.dart';
import 'package:medito/services/review_service.dart';
import 'package:medito/providers/donation/donation_page_provider.dart';
import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:medito/views/splash_welcome_layout.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:medito/providers/onboarding/onboarding_donation_timing_experiment.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/home/products_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/views/home/home_view.dart';
import 'package:medito/views/home/previews/home_previews.dart';
import 'package:medito/views/home/widgets/shortcuts/shortcuts_items_widget.dart';
import 'package:medito/views/home/widgets/up_next/up_next_widget.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/views/player/widgets/artist_title_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/player_action_bar.dart';
import 'package:medito/views/player/widgets/duration_indicator_widget.dart';
import 'package:medito/views/player/widgets/player_buttons/player_buttons_widget.dart';
import 'package:medito/views/previews/preview_support.dart';
import 'package:medito/views/bottom_navigation/widgets/medito_sidebar.dart';
import 'package:medito/widgets/adaptive/adaptive_content.dart';
import 'package:medito/widgets/report_button_widget.dart';

import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/onboarding/onboarding_question_screen.dart';
import 'package:medito/views/onboarding/notifications_screen.dart';
import 'package:medito/widgets/onboarding/onboarding_header_image.dart';
import 'package:medito/widgets/onboarding/onboarding_option_button.dart';
import 'package:medito/widgets/onboarding/progress_indicator_widget.dart';

import 'package:medito/views/onboarding/onboarding_donation_screen.dart';
import 'package:medito/views/onboarding/onboarding_result_screen.dart';
import 'package:medito/views/onboarding/tracking_permission_screen.dart';
import 'package:medito/views/onboarding/battery_optimization_screen.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';

import '../../helpers/firebase_test_helper.dart';
import '../../helpers/firebase_analytics_test_helper.dart';
import 'adaptive_layout_test.dart' show destinations;

const request = PlaybackRequest(
  trackId: 'preview',
  fileId: 'preview-file',
  title: 'Noting Thoughts',
  description: '',
  coverUrl: 'https://preview.medito.test/cover.png',
  remoteUrl: 'https://example.test/audio.mp3',
  duration: 600000,
  hasBackgroundSound: true,
  guideName: 'Will',
);

class _PreviewAudio extends AudioStateNotifier {
  @override
  PlaybackState build() => PlaybackState(
    position: 154000,
    duration: 600000,
    isPlaying: false,
    isBuffering: false,
    isSeeking: false,
    isCompleted: false,
    speed: Speed(speed: 1),
    volume: 100,
    track: Track(
      id: 'preview',
      title: 'Noting Thoughts',
      fileId: 'preview-file',
      description: '',
      imageUrl: '',
      artist: 'Will',
    ),
  );
}

class _OnboardingStats extends StatsNotifier {
  @override
  Future<LocalAllStats> build() async => previewStats;
}

PaywallConfigModel _onboardingPaywall(bool native) => PaywallConfigModel(
  defaults: PaywallDefaults(config: {'nativePaywall': native}),
  pricing: const PaymentPricing(
    oneTime: [500, 1000, 2500],
    monthly: [200, 500, 1000],
    yearly: [2500, 5000, 10000],
    currency: 'usd',
    country: 'US',
    suggested: SuggestedPricing(oneTime: 1000, monthly: 500, yearly: 5000),
  ),
);

class _JourneyTracks extends Tracks {
  @override
  Future<model.Track> build({required String trackId}) async => model.Track(
    id: trackId,
    title: 'Noting Thoughts',
    description:
        'Learn to notice your thoughts without getting caught up in them. This guided meditation helps you gently return your attention to the present moment.',
    coverUrl: request.coverUrl,
    isPublished: true,
    hasBackgroundSound: true,
    voices: [
      model.TrackVoice(
        guideName: 'Will',
        audioFiles: [
          model.TrackAudioFile(
            id: 'sample',
            path: 'https://example.test/audio.mp3',
            duration: 600000,
          ),
        ],
      ),
    ],
  );
}

class _JourneyFavorites extends FavoritesNotifier {
  @override
  Future<List<FavoriteItem>> build() async => [];
}

class _JourneyReview implements ReviewService {
  @override
  Future<void> checkAndRequestReview() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    await FirebaseTestHelper.initializeFirebaseForTest();
    FirebaseAnalyticsTestHelper.setupFirebaseAnalyticsMocks();
    for (final entry in {
      'Google Sans': 'assets/fonts/google-sans/GoogleSans-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  testWidgets('Home fits tablet and foldable widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Only the image data is a fixture. CachedNetworkImage and every Home
    // component still render through their production implementations.
    final bytes = await rootBundle.load('assets/images/open_awareness.png');
    final codec = await tester.runAsync(
      () => ui.instantiateImageCodec(bytes.buffer.asUint8List()),
    );
    final frame = await tester.runAsync(() => codec!.getNextFrame());
    for (final url in {
      previewPack.coverUrl,
      ...previewHome.carousel.map((item) => item.coverUrl),
      ...previewProducts.map((item) => item.displayImageUrl),
    }) {
      PaintingBinding.instance.imageCache.putIfAbsent(
        CachedNetworkImageProvider(url!),
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: frame!.image.clone())),
        ),
      );
    }
    for (final size in [const Size(1200, 900), const Size(820, 900)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        wrapHomeDark(
          ProviderScope(
            // One sample product keeps the real shop's random ordering from
            // making visual snapshots nondeterministic.
            overrides: [
              productsProvider.overrideWith(
                (ref) async => [previewProducts.first],
              ),
            ],
            child: Scaffold(
              body: Row(
                children: [
                  MeditoSidebar(
                    extended: size.width >= 1100,
                    items: destinations,
                    selectedIndex: 0,
                    onSelected: (_) {},
                  ),
                  const Expanded(child: AdaptiveContent(child: HomeView())),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(ShortcutsItemsWidget), findsOneWidget);
      expect(find.byType(UpNextWidget), findsOneWidget);
      final play = find.descendant(
        of: find.byType(UpNextWidget),
        matching: find.byIcon(Icons.play_arrow_rounded),
      );
      expect(size.width - tester.getCenter(play).dx, closeTo(32 + 52 / 2, 0.1));

      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    frame!.image.dispose();
    codec!.dispose();
  });

  testWidgets(
    'real player preserves controls and close/speed callbacks at all sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var closed = false;
      double? speed;
      for (final size in [
        const Size(1200, 800),
        const Size(820, 800),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        final bytes = await rootBundle.load('assets/images/open_awareness.png');
        final codec = await tester.runAsync(
          () => ui.instantiateImageCodec(bytes.buffer.asUint8List()),
        );
        final frame = await tester.runAsync(() => codec!.getNextFrame());
        final provider = ResizeImage.resizeIfNeeded(
          size.width.toInt(),
          null,
          const NetworkImage('https://preview.medito.test/cover.png'),
        );
        final key = await provider.obtainKey(ImageConfiguration.empty);
        PaintingBinding.instance.imageCache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: frame!.image.clone())),
          ),
        );
        frame!.image.dispose();
        codec!.dispose();
        await tester.pumpWidget(
          PreviewShell(
            prefs: prefsDark,
            overrides: [audioStateProvider.overrideWith(_PreviewAudio.new)],
            child: PlayerScreenLayout(
              currentlyPlayingTrack: request,
              isPlaying: false,
              isAudioLoading: false,
              isBackgroundSoundSelected: false,
              onPlayPausePressed: () {},
              onSpeedChanged: (value) => speed = value,
              onClosePressed: () => closed = true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final type in [
          ArtistTitleWidget,
          DurationIndicatorWidget,
          PlayerButtonsWidget,
          PlayerActionBar,
          ReportButtonWidget,
        ]) {
          expect(find.byType(type), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('1.0×'));
      await tester.pump();
      expect(speed, 0.6);
      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    },
  );
  testWidgets('onboarding keeps existing steps readable when resized', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selected;
    for (final size in [
      const Size(1200, 900),
      const Size(820, 900),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        PreviewShell(
          prefs: prefsDark,
          child: Scaffold(
            body: SafeArea(
              top: false,
              child: SizedBox(
                child: Column(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context)!;
                          return OnboardingQuestionScreen(
                            headerImage: AssetConstants.onboardingImage1,
                            question: l10n.onboardingExperienceQuestion,
                            subtext: l10n.onboardingExperienceSubtext,
                            options: [
                              l10n.onboardingExperienceNever,
                              l10n.onboardingExperienceALittle,
                              l10n.onboardingExperienceRegular,
                            ],
                            // Fix fixture order only; the live question still shuffles.
                            pinnedTrailingCount: 3,
                            onOptionSelected: (index) => selected = index,
                          );
                        },
                      ),
                    ),
                    const OnboardingProgressIndicator(
                      currentIndex: 0,
                      totalSteps: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(AssetConstants.onboardingImage1),
          tester.element(find.byType(Scaffold)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(OnboardingOptionButton).first).width,
        (size.width > 600 ? 600 : size.width) - 48,
      );
      expect(find.byType(OnboardingOptionButton), findsNWidgets(3));
      expect(
        tester.getSize(find.byType(OnboardingHeaderImage)).width,
        size.width,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byType(OnboardingOptionButton).first);
    await tester.pump(const Duration(milliseconds: 250));
    expect(selected, 0);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpWidget(
      PreviewShell(
        prefs: prefsDark,
        child: Scaffold(
          body: SafeArea(
            top: false,
            child: SizedBox(
              child: Column(
                children: [
                  Expanded(
                    child: NotificationsScreen(
                      headerImage: AssetConstants.onboardingImage3,
                      onNext: () {},
                    ),
                  ),
                  const OnboardingProgressIndicator(
                    currentIndex: 2,
                    totalSteps: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(AssetConstants.onboardingImage3),
        tester.element(find.byType(Scaffold).first),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('audit every onboarding step across sizes and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final steps = <String, Widget Function()>{
      'question': () => Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return OnboardingQuestionScreen(
            headerImage: AssetConstants.onboardingImage1,
            question: l10n.onboardingExperienceQuestion,
            subtext: l10n.onboardingExperienceSubtext,
            options: [
              l10n.onboardingExperienceNever,
              l10n.onboardingExperienceALittle,
              l10n.onboardingExperienceRegular,
            ],
            pinnedTrailingCount: 3,
            onOptionSelected: (_) {},
          );
        },
      ),
      'donation-intro': () => OnboardingDonationScreen(
        headerImage: AssetConstants.onboardingImage2,
        onNext: () {},
      ),
      'donation-native': () => OnboardingDonationScreen(
        headerImage: AssetConstants.onboardingImage2,
        onNext: () {},
      ),
      'reminder': () => NotificationsScreen(
        headerImage: AssetConstants.onboardingImage3,
        onNext: () {},
      ),
      'battery': () => BatteryOptimizationScreen(
        headerImage: AssetConstants.onboardingImage3,
        onNext: () {},
      ),
      'tracking': () => TrackingPermissionScreen(
        headerImage: AssetConstants.onboardingImage3,
        onNext: () {},
      ),
      'first-meditation': () => OnboardingResultScreen(
        headerImage: AssetConstants.onboardingImage3,
        state: OnboardingResultState.stateA,
        showMeditation: true,
        onGetStarted: () {},
      ),
      'returning-meditation': () => OnboardingResultScreen(
        headerImage: AssetConstants.onboardingImage3,
        state: OnboardingResultState.stateB,
        showMeditation: true,
        onGetStarted: () {},
      ),
      'experienced-meditation': () => OnboardingResultScreen(
        headerImage: AssetConstants.onboardingImage3,
        state: OnboardingResultState.stateC,
        showMeditation: true,
        onGetStarted: () {},
      ),
      'get-started': () => OnboardingResultScreen(
        headerImage: AssetConstants.onboardingImage3,
        state: OnboardingResultState.stateC,
        onGetStarted: () {},
      ),
    };
    for (final entry in steps.entries) {
      for (final configuration in [
        (const Size(360, 640), 1.0, ThemeMode.dark),
        (const Size(820, 900), 1.0, ThemeMode.dark),
        (const Size(1200, 900), 1.0, ThemeMode.dark),
        (const Size(1024, 500), 1.0, ThemeMode.dark),
        (const Size(1200, 900), 1.6, ThemeMode.dark),
        (const Size(360, 640), 1.6, ThemeMode.dark),
        (const Size(1200, 900), 1.0, ThemeMode.light),
      ]) {
        final (size, scale, mode) = configuration;
        tester.view.physicalSize = size;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          PreviewShell(
            prefs: mode == ThemeMode.dark ? prefsDark : prefsLight,
            themeMode: mode,
            overrides: [
              audioStateProvider.overrideWith(_PreviewAudio.new),
              statsProvider.overrideWith(_OnboardingStats.new),
              paywallConfigProvider.overrideWith(
                (ref) async =>
                    _onboardingPaywall(entry.key == 'donation-native'),
              ),
              availablePaymentMethodsProvider.overrideWith(
                (ref) async => const [
                  PaymentMethod(
                    id: 'card',
                    type: PaymentMethodType.card,
                    displayName: 'Card',
                    isAvailable: true,
                  ),
                ],
              ),
            ],
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Expanded(child: entry.value()),
                        if (!entry.key.contains('meditation') &&
                            entry.key != 'get-started')
                          const OnboardingProgressIndicator(
                            currentIndex: 1,
                            totalSteps: 3,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          for (final path in [
            AssetConstants.onboardingImage1,
            AssetConstants.onboardingImage2,
            AssetConstants.onboardingImage3,
          ]) {
            await precacheImage(
              AssetImage(path),
              tester.element(find.byType(Scaffold).first),
            );
          }
        });
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key}: $size text $scale',
        );
        // Exercise the scroll view so lower-page controls are laid out too.
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          await tester.drag(scrollables.first, const Offset(0, -1200));
          await tester.pump();
          await tester.pump(const Duration(seconds: 3));
          await tester.pump(const Duration(seconds: 1));
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} scrolled: $size text $scale',
          );
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('iOS onboarding preserves step counts and audience variants', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final config = _onboardingPaywall(false);
    expect(config.nativePaywallEnabled, isFalse);
    for (final width in [1200.0, 820.0]) {
      tester.view.physicalSize = Size(width, 900);
      for (final variant in ['A', 'B']) {
        for (final experience in [0, 1, 2, 3]) {
          // 2/3 exercise both regular-practice experiment assignments.
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            PreviewShell(
              prefs: {
                ...prefsDark,
                OnboardingDonationTimingExperiment.preferenceKey: variant,
                SharedPreferenceConstants
                    .onboardingExperiencedMeditationVariant: experience == 3
                    ? 'offered'
                    : 'control',
              },
              overrides: [
                onboardingTrackingStepProvider.overrideWithValue(true),
                audioStateProvider.overrideWith(_PreviewAudio.new),
                statsProvider.overrideWith(_OnboardingStats.new),
                paywallConfigProvider.overrideWith((ref) async => config),
              ],
              child: const OnboardingPagerScreen(),
            ),
          );
          await tester.runAsync(() async {
            for (final path in [
              AssetConstants.onboardingImage1,
              AssetConstants.onboardingImage2,
              AssetConstants.onboardingImage3,
            ]) {
              await precacheImage(
                AssetImage(path),
                tester.element(find.byType(OnboardingPagerScreen)),
              );
            }
          });
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          Future<void> checkLayout(String name) async {
            expect(tester.takeException(), isNull, reason: name);
          }

          if (experience == 0) await checkLayout('01-question');
          final question = tester.widget<OnboardingQuestionScreen>(
            find.byType(OnboardingQuestionScreen),
          );
          await tester.tap(
            find.text(question.options[experience > 1 ? 2 : experience]),
          );
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          final steps = OnboardingDonationTimingExperiment.steps(
            variant: variant,
            showBattery: false,
            showTracking: true,
          );
          final controller = tester
              .widget<PageView>(find.byType(PageView))
              .controller!;
          for (var index = 1; index < steps.length; index++) {
            controller.jumpToPage(index);
            await tester.pump();
            await tester.pump(const Duration(seconds: 3));
            await tester.pump(const Duration(seconds: 1));
            final step = steps[index];
            if (step == OnboardingStep.result) {
              expect(find.byType(OnboardingProgressIndicator), findsNothing);
              final result = tester.widget<OnboardingResultScreen>(
                find.byType(OnboardingResultScreen),
              );
              expect(result.showMeditation, experience != 2);
              await checkLayout('${index + 1}-result-$experience');
            } else if (experience == 0) {
              final progress = tester.widget<OnboardingProgressIndicator>(
                find.byType(OnboardingProgressIndicator),
              );
              expect(progress.totalSteps, 4);
              expect(
                progress.currentIndex,
                steps
                        .take(index + 1)
                        .where((s) => s != OnboardingStep.result)
                        .length -
                    1,
              );
              await checkLayout('${index + 1}-${step.name}');
            }
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('splash and settings at wide and compact sizes', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async => 0,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_dynamic_icon'),
          (call) async => null,
        );
    var started = 0;
    var signedIn = 0;
    for (final size in [
      const Size(1200, 900),
      const Size(820, 900),
      const Size(390, 844),
      const Size(1024, 500),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        PreviewShell(
          prefs: prefsDark,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SplashWelcomeLayout(
              showAccountButtons: true,
              isSigningIn: false,
              onGetStarted: () => started++,
              onSignIn: () => signedIn++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Get started'));
      await tester.tap(find.text('Get started'));
      final signIn = find.byType(TextButton);
      await tester.ensureVisible(signIn);
      await tester.tap(signIn);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        PreviewShell(
          prefs: prefsDark,
          child: Scaffold(
            body: Row(
              children: [
                if (size.width >= 700)
                  MeditoSidebar(
                    extended: size.width >= 1100,
                    items: destinations,
                    selectedIndex: 3,
                    onSelected: (_) {},
                  ),
                const Expanded(child: AdaptiveContent(child: SettingsScreen())),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    expect(started, 4);
    expect(signedIn, 4);
  });
  testWidgets(
    'Explore, Search and detail screens fit wide and compact viewports',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (call) async => 0,
          );
      final packs =
          [
                'Beginner’s Guide',
                'Daily Meditations',
                'Sleep',
                'Stress & Anxiety',
                'Mindfulness',
                'Compassion',
              ]
              .asMap()
              .entries
              .map(
                (e) => PackItem(
                  id: 'pack-${e.key}',
                  title: e.value,
                  subtitle: 'Meditations for every day',
                  coverUrl: request.coverUrl,
                  path: 'packs/${e.key}',
                ),
              )
              .toList();
      ui.FrameInfo? frame;
      await tester.runAsync(() async {
        final bytes = await rootBundle.load('assets/images/open_awareness.png');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        frame = await codec.getNextFrame();
      });
      for (final url in [
        request.coverUrl,
        previewPack.coverUrl,
        ...previewPack.items.map((e) => e.coverUrl),
      ].whereType<String>()) {
        PaintingBinding.instance.imageCache.putIfAbsent(
          CachedNetworkImageProvider(url),
          () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: frame!.image.clone())),
          ),
        );
      }
      for (final size in [
        const Size(1200, 900),
        const Size(820, 900),
        const Size(390, 844),
        const Size(1024, 500),
      ]) {
        tester.view.physicalSize = size;
        for (final name in [
          'explore',
          'search',
          'pack',
          'track',
          'completion',
        ]) {
          Widget page = switch (name) {
            'explore' => const ExploreView(),
            'search' => const SearchView(),
            'pack' => PackView(id: previewPack.id),
            'track' => const TrackView(trackId: 'preview'),
            _ => const EndScreenView(request: request),
          };
          if (name == 'explore' || name == 'search') {
            page = Scaffold(
              body: Row(
                children: [
                  if (size.width >= 700)
                    MeditoSidebar(
                      extended: size.width >= 1100,
                      items: destinations,
                      selectedIndex: name == 'explore' ? 1 : 2,
                      onSelected: (_) {},
                    ),
                  Expanded(child: AdaptiveContent(child: page)),
                ],
              ),
            );
          }
          await tester.pumpWidget(
            PreviewShell(
              prefs: {
                ...prefsDark,
                SharedPreferenceConstants.endScreenDonationAskVariant: 'A',
              },
              overrides: [
                meProvider.overrideWith(
                  (ref) async => const MeModel(id: 'preview'),
                ),
                explorePacksProvider.overrideWith((ref) async => packs),
                searchTracksProvider('mind').overrideWith(
                  (ref) async => [
                    TrackItem(
                      id: 'preview',
                      title: 'Mindful Breathing',
                      subtitle: '10 min · Will',
                      coverUrl: request.coverUrl,
                      path: 'tracks/preview',
                    ),
                  ],
                ),
                packDataProvider(
                  packId: previewPack.id,
                ).overrideWith((ref) async => previewPack),
                tracksProvider(
                  trackId: 'preview',
                ).overrideWith(_JourneyTracks.new),
                favoritesNotifierProvider.overrideWith(_JourneyFavorites.new),
                statsProvider.overrideWith(_OnboardingStats.new),
                tagCatalogProvider.overrideWithValue(
                  TagCatalog(
                    tags: const [
                      TagModel(
                        id: 'sleep',
                        group: 'goal',
                        description: 'Sleep',
                      ),
                      TagModel(
                        id: 'anxiety',
                        group: 'goal',
                        description: 'Anxiety',
                      ),
                      TagModel(
                        id: 'breathing',
                        group: 'technique',
                        description: 'Breathing',
                      ),
                    ],
                    trackTags: {
                      'preview': ['breathing'],
                      'track-1': ['breathing'],
                    },
                  ),
                ),
                reviewServiceProvider.overrideWithValue(_JourneyReview()),
                fetchDonationPageProvider.overrideWith(
                  (ref) async => const DonationPageModel(
                    title: 'Keep meditation free',
                    text:
                        'Your support helps us make meditation accessible to everyone.',
                    buttons: [
                      ButtonModel(
                        title: 'Donate',
                        path: 'https://meditofoundation.org/donate',
                        type: 'link',
                      ),
                    ],
                  ),
                ),
              ],
              child: RepaintBoundary(
                key: const ValueKey('capture'),
                child: page,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 3));
          if (name == 'search') {
            await tester.enterText(find.byType(TextField), 'mind');
            await tester.pump(const Duration(milliseconds: 600));
            await tester.pump(const Duration(seconds: 1));
          }
          await tester.pump(const Duration(seconds: 3));
          expect(tester.takeException(), isNull, reason: '$name at $size');
          if (name == 'track') {
            final image = find
                .descendant(
                  of: find.byType(TrackView),
                  matching: find.byType(AspectRatio),
                )
                .first;
            final title = find.text('Noting Thoughts').first;
            expect(
              tester.getBottomLeft(image).dy,
              lessThan(tester.getTopLeft(title).dy),
            );
            expect(tester.getSize(image).width, lessThanOrEqualTo(560));
          }

          if (name == 'search') {
            await tester.tap(find.text('Tracks'));
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull);
          }
          if (name == 'search') {
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pump();
            expect(
              tester.getBottomLeft(find.byType(TextField)).dy,
              lessThan(size.height - 300),
            );
            expect(tester.takeException(), isNull);
            tester.view.resetViewInsets();
            await tester.pump();
          }
          if (name == 'completion') {
            await tester.drag(
              find.byType(SingleChildScrollView).first,
              const Offset(0, -500),
            );
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }
      }
    },
  );

  testWidgets('quote card stays square and share control scrolls into view', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(820, 900), const Size(1024, 500)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        const PreviewShell(
          prefs: prefsDark,
          child: QuoteShareScreen(
            data: HomeQuoteModel(
              id: 'layout-test',
              quote:
                  'The present moment is filled with joy and happiness. If you are attentive, you will see it.',
              author: 'Thich Nhat Hanh',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.descendant(
        of: find.byType(QuoteShareScreen),
        matching: find.byType(AspectRatio),
      );
      expect(tester.getSize(card).width, tester.getSize(card).height);
      expect(tester.getSize(card).width, lessThanOrEqualTo(440));
      final share = find.widgetWithText(FilledButton, 'Share');
      await tester.ensureVisible(share);
      await tester.pumpAndSettle();
      expect(share.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
