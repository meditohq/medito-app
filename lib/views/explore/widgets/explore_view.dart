import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/explore/track_search_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/views/explore/widgets/pack_grid_sliver.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/widgets/widgets.dart';

/// The Explore tab: every published pack in a masonry grid. Search lives on
/// its own page, opened from the floating nav's search button.
class ExploreView extends ConsumerStatefulWidget {
  const ExploreView({super.key});

  @override
  ConsumerState<ExploreView> createState() => ExploreViewState();
}

class ExploreViewState extends ConsumerState<ExploreView> {
  final _analytics = FirebaseAnalyticsService();
  bool _hasLoadedData = false;

  @override
  void initState() {
    super.initState();
    _analytics.logScreenView(screenName: 'ExploreView');
  }

  /// Fetches the pack list the first time the tab is shown.
  void loadData() {
    if (_hasLoadedData) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(explorePacksProvider);
      _hasLoadedData = true;
    });
  }

  Future<void> _refresh() async {
    AppLogger.d('ExploreView', 'Refreshing explore list');
    ref.invalidate(explorePacksProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No bottom inset: the floating nav pill sits over the content, which
      // scrolls underneath it. The trailing sliver keeps the last row clear.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    padding16,
                    padding16,
                    padding16,
                    0,
                  ),
                  child: HomeHeaderWidget(
                    greeting: AppLocalizations.of(context)!.explore,
                  ),
                ),
              ),
              ..._buildPacks(),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + padding16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPacks() {
    final packsAsync = ref.watch(explorePacksProvider);
    return packsAsync.when(
      data: (packs) {
        if (packs.isEmpty) {
          return [
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No packs available',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ];
        }
        return [PackGridSliver(packs: packs)];
      },
      error: (err, _) {
        final error = err is AppError ? err : const UnknownError();
        return [
          SliverFillRemaining(
            child: MeditoErrorWidget(
              error: error,
              isScaffold: false,
              onTap: () => ref.invalidate(explorePacksProvider),
            ),
          ),
        ];
      },
      loading: () => const [
        SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      ],
    );
  }
}
