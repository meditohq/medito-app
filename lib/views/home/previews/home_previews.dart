// Widget previews for the Home tab.
//
// Run from the project root:
//
//   flutter widget-preview start --web-server
//
// and open the printed URL. The real [HomeView] renders through the shared
// [PreviewShell] with the home data providers overridden by fixtures, so no
// backend, Firebase or device is needed. Edits to the home widgets hot-reload.
//
// Reference: https://flutter.dev/to/widget-previews

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:medito/constants/constants.dart';
import 'package:medito/mock/mock_data.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/home/announcement/announcement_model.dart';
import 'package:medito/models/home/product/product_model.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/announcement_provider.dart';
import 'package:medito/providers/home/home_provider.dart';
import 'package:medito/providers/home/products_provider.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/views/home/home_view.dart';
import 'package:medito/views/home/widgets/shortcuts/shortcuts_items_widget.dart';
import 'package:medito/views/home/widgets/up_next/up_next_widget.dart';
import 'package:medito/views/previews/preview_support.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Streak number in the pill, explainer strip already dismissed.
const Map<String, Object> homePrefsDark = {
  SharedPreferenceConstants.themePreference: 'dark',
  SharedPreferenceConstants.streakCircleDisplayPreference: 'currentStreak',
  SharedPreferenceConstants.hasSeenYourPathExplainer: true,
};

const Map<String, Object> homePrefsLight = {
  SharedPreferenceConstants.themePreference: 'light',
  SharedPreferenceConstants.streakCircleDisplayPreference: 'currentStreak',
  SharedPreferenceConstants.hasSeenYourPathExplainer: true,
};

/// First run: explainer strip visible, consistency score in the pill.
const Map<String, Object> homePrefsFirstRun = {
  SharedPreferenceConstants.themePreference: 'dark',
};

/// Icon keys must exist in MeditoRemoteIcon's asset map — the mock-mode
/// shortcuts use emoji strings and would render blank.
final previewHome = HomeModel(
  greeting: 'Welcome back',
  shortcuts: const [
    ShortcutsModel(
      id: 'shortcut-calm',
      type: 'track',
      title: 'Daily Calm',
      path: 'tracks/track-1',
      icon: 'solidRoundedSun01',
    ),
    ShortcutsModel(
      id: 'shortcut-sleep',
      type: 'pack',
      title: 'Sleep',
      path: 'packs/pack-2',
      icon: 'solidRoundedSleeping',
    ),
    ShortcutsModel(
      id: 'shortcut-timer',
      type: 'track',
      title: 'Timer',
      path: 'tracks/track-3',
      icon: 'solidRoundedTime01',
    ),
    ShortcutsModel(
      id: 'shortcut-streak',
      type: 'pack',
      title: 'Streak',
      path: 'packs/pack-3',
      icon: 'solidRoundedMedal06',
    ),
  ],
  carousel: [
    mockHome.carousel.first.copyWith(showBanner: true),
    ...mockHome.carousel.skip(1),
    const HomeCarouselModel(
      id: 'carousel-3',
      title: 'Focus at Work',
      subtitle: 'Short resets for busy days',
      coverUrl: 'https://picsum.photos/seed/medito3/800/400',
      path: 'packs/pack-3',
      type: 'pack',
    ),
  ],
  todayQuote: mockHome.todayQuote,
);

/// Seven-session pack, three done, so the hero reads "3 of 7".
final PackModel previewPack = () {
  const titles = [
    'Introduction to Meditation',
    'Breath Awareness',
    'Body Scan',
    'Noting Thoughts',
    'Working with Emotions',
    'Loving Kindness',
    'Open Awareness',
  ];
  return mockPacks.first.copyWith(
    items: List.generate(
      titles.length,
      (i) => PackItemsModel(
        type: 'track',
        id: 'track-${i + 1}',
        title: titles[i],
        subtitle: '${10 + i} min',
        coverUrl: 'https://picsum.photos/seed/track${i + 1}/400/400',
        path: 'tracks/track-${i + 1}',
        isCompleted: i < 3,
      ),
    ),
  );
}();

final previewUpNext = UpNextData(
  pack: previewPack,
  nextSession: previewPack.items[3],
  completedCount: 3,
  totalCount: previewPack.items.length,
);

LocalAllStats _stats({required bool doneToday}) {
  final now = DateTime.now();
  return LocalAllStats(
    streakCurrent: 12,
    streakLongest: 30,
    totalTracksCompleted: 48,
    totalTimeListened: 48 * 12 * 60,
    tracksChecked: const [],
    audioCompleted: doneToday
        ? [
            LocalAudioCompleted(
              id: 'track-3',
              timestamp: now.millisecondsSinceEpoch,
            ),
          ]
        : [
            LocalAudioCompleted(
              id: 'track-3',
              timestamp: now
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch,
            ),
          ],
    updated: now.millisecondsSinceEpoch,
    freezeUsageDates: const [],
    consistencyScore: 82,
  );
}

final previewStats = _stats(doneToday: false);
final previewStatsDoneToday = _stats(doneToday: true);

ProductGroupModel _product(String name, String seed, {bool isNew = false}) {
  final image = 'https://picsum.photos/seed/$seed/400/400';
  return ProductGroupModel(
    groupId: name,
    name: name,
    url: 'https://shop.meditofoundation.org',
    imageUrl: image,
    variants: [
      ProductModel(
        id: '$seed-1',
        name: name,
        price: 25,
        currency: 'EUR',
        imageUrl: image,
        firstSeenDate: isNew ? DateTime.now() : null,
      ),
    ],
    allImageUrls: [image],
    displayImageUrl: image,
  );
}

final previewProducts = [
  _product('Medito Tee', 'tee', isNew: true),
  _product('Meditation Cushion', 'cushion'),
  _product('Enamel Mug', 'mug'),
];

/// [StatsNotifier] that serves a fixture instead of syncing.
class _PreviewStatsNotifier extends StatsNotifier {
  _PreviewStatsNotifier(this._fixture);

  final LocalAllStats _fixture;

  @override
  Future<LocalAllStats> build() async => _fixture;
}

List<Override> _homeOverrides({
  required LocalAllStats stats,
  AnnouncementModel? announcement,
}) => [
  fetchHomeProvider.overrideWith((ref) async => previewHome),
  upNextProvider.overrideWith((ref) => AsyncData(previewUpNext)),
  statsProvider.overrideWith(() => _PreviewStatsNotifier(stats)),
  fetchLatestAnnouncementProvider.overrideWith((ref) async => announcement),
  productsProvider.overrideWith((ref) async => previewProducts),
];

// Wrappers must be top-level functions so they can be referenced from a
// const annotation.
Widget wrapHomeDark(Widget child) => PreviewShell(
  prefs: homePrefsDark,
  overrides: _homeOverrides(stats: previewStats),
  child: child,
);

Widget wrapHomeLight(Widget child) => PreviewShell(
  prefs: homePrefsLight,
  themeMode: ThemeMode.light,
  overrides: _homeOverrides(stats: previewStats),
  child: child,
);

Widget wrapHomeAnnouncement(Widget child) => PreviewShell(
  prefs: homePrefsDark,
  overrides: _homeOverrides(
    stats: previewStats,
    announcement: mockAnnouncement,
  ),
  child: child,
);

Widget wrapHomeStreakDone(Widget child) => PreviewShell(
  prefs: homePrefsDark,
  overrides: _homeOverrides(stats: previewStatsDoneToday),
  child: child,
);

Widget wrapHomeFirstRun(Widget child) => PreviewShell(
  prefs: homePrefsFirstRun,
  overrides: _homeOverrides(stats: previewStats),
  child: child,
);

/// Single sections on a plain scaffold with page padding.
Widget _section(Widget child) => Scaffold(
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Align(alignment: Alignment.topCenter, child: child),
    ),
  ),
);

Widget wrapSectionDark(Widget child) => PreviewShell(
  prefs: homePrefsDark,
  overrides: _homeOverrides(stats: previewStats),
  child: _section(child),
);

Widget wrapSectionLight(Widget child) => PreviewShell(
  prefs: homePrefsLight,
  themeMode: ThemeMode.light,
  overrides: _homeOverrides(stats: previewStats),
  child: _section(child),
);

// ---------------------------------------------------------------------------
// Full page
// ---------------------------------------------------------------------------

@Preview(group: 'Home', name: 'Dark', size: phoneSize, wrapper: wrapHomeDark)
Widget homeDark() => const HomeView();

@Preview(group: 'Home', name: 'Light', size: phoneSize, wrapper: wrapHomeLight)
Widget homeLight() => const HomeView();

@Preview(
  group: 'Home',
  name: 'Dark · announcement',
  size: phoneSize,
  wrapper: wrapHomeAnnouncement,
)
Widget homeAnnouncement() => const HomeView();

@Preview(
  group: 'Home',
  name: 'Dark · streak done today',
  size: phoneSize,
  wrapper: wrapHomeStreakDone,
)
Widget homeStreakDone() => const HomeView();

@Preview(
  group: 'Home',
  name: 'Dark · first run (explainer strip)',
  size: phoneSize,
  wrapper: wrapHomeFirstRun,
)
Widget homeFirstRun() => const HomeView();

@Preview(
  group: 'Home',
  name: 'Large text (1.5×)',
  size: phoneSize,
  textScaleFactor: 1.5,
  wrapper: wrapHomeDark,
)
Widget homeLargeText() => const HomeView();

@Preview(
  group: 'Home',
  name: 'Small phone (360×640)',
  size: Size(360, 640),
  wrapper: wrapHomeDark,
)
Widget homeSmall() => const HomeView();

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

@Preview(
  group: 'Home sections',
  name: 'Your Path · dark',
  size: Size(390, 200),
  wrapper: wrapSectionDark,
)
Widget upNextDark() => const UpNextWidget();

@Preview(
  group: 'Home sections',
  name: 'Your Path · light',
  size: Size(390, 200),
  wrapper: wrapSectionLight,
)
Widget upNextLight() => const UpNextWidget();

@Preview(
  group: 'Home sections',
  name: 'Shortcuts · dark',
  size: Size(390, 140),
  wrapper: wrapSectionDark,
)
Widget shortcutsDark() => ShortcutsItemsWidget(data: previewHome.shortcuts);
