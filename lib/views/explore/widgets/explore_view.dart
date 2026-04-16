import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/providers/explore/track_search_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/track_card_widget.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:medito/utils/utils.dart';

final filteredPacksProvider =
    Provider.autoDispose.family<List<PackItem>, String>((ref, query) {
  final packs = ref.watch(
    explorePacksProvider.select((asyncValue) => asyncValue.value ?? []),
  );
  if (query.isEmpty) return packs;
  final lowerQuery = query.toLowerCase();
  return packs
      .where((p) =>
          p.title.toLowerCase().contains(lowerQuery) ||
          p.subtitle.toLowerCase().contains(lowerQuery))
      .toList();
});

enum ExploreFilter {
  all,
  packs,
  tracks;

  String label(BuildContext context) => switch (this) {
        ExploreFilter.all => AppLocalizations.of(context)!.all,
        ExploreFilter.packs => AppLocalizations.of(context)!.packs,
        ExploreFilter.tracks => AppLocalizations.of(context)!.tracks,
      };
}

class ExploreView extends ConsumerStatefulWidget {
  final FocusNode searchFocusNode;

  const ExploreView({super.key, required this.searchFocusNode});

  @override
  ConsumerState<ExploreView> createState() => ExploreViewState();
}

class ExploreViewState extends ConsumerState<ExploreView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  Timer? _debounce;
  bool _hasLoadedData = false;
  ExploreFilter _currentFilter = ExploreFilter.packs;
  final _analytics = FirebaseAnalyticsService();
  int? _previousPacksCount;
  int? _previousTracksCount;
  bool _isFilterSwitchCallbackScheduled = false;

  @override
  void initState() {
    super.initState();
    _logScreenView();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void unfocusSearch() {
    widget.searchFocusNode.unfocus();
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(screenName: 'ExploreView');
  }

  void loadData() {
    if (!_hasLoadedData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(explorePacksProvider);
        _hasLoadedData = true;
      });
    }
  }

  Future<void> _refreshExploreList() async {
    AppLogger.d('ExploreView', 'Refreshing explore list');
    if (_searchQuery.isEmpty) {
      ref.invalidate(explorePacksProvider);
    } else {
      ref.invalidate(searchTracksProvider(_searchQuery));
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final asciiQuery = value.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
      setState(() {
        _searchQuery = asciiQuery;
        if (asciiQuery.isEmpty) {
          _currentFilter = ExploreFilter.packs;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshExploreList,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeader(),
              if (_searchQuery.isNotEmpty) _buildFilterChips(ref),
              ..._buildContentSlivers(ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          padding16,
          padding16,
          padding16,
          18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeHeaderWidget(
              greeting: AppLocalizations.of(context)!.explore,
            ),
            const SizedBox(height: 18),
            SearchBox(
              controller: _searchController,
              focusNode: widget.searchFocusNode,
              onChanged: _onSearchChanged,
              onClear: () {
                setState(() {
                  _searchQuery = '';
                  _currentFilter = ExploreFilter.packs;
                  _searchController.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(WidgetRef ref) {
    final packs = ref.watch(filteredPacksProvider(_searchQuery));
    final searchTracksAsync = ref.watch(searchTracksProvider(_searchQuery));

    final packsCount = packs.length;
    final tracksCount = searchTracksAsync.value?.length ?? 0;

    if ((_previousPacksCount != packsCount ||
            _previousTracksCount != tracksCount) &&
        !_isFilterSwitchCallbackScheduled) {
      _previousPacksCount = packsCount;
      _previousTracksCount = tracksCount;
      _isFilterSwitchCallbackScheduled = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isFilterSwitchCallbackScheduled = false;
        if (!mounted) return;

        if (_currentFilter == ExploreFilter.packs &&
            packsCount == 0 &&
            tracksCount > 0) {
          setState(() => _currentFilter = ExploreFilter.tracks);
        } else if (_currentFilter == ExploreFilter.tracks &&
            tracksCount == 0 &&
            packsCount > 0) {
          setState(() => _currentFilter = ExploreFilter.packs);
        }
      });
    }

    final tabs = ExploreFilter.values
        .where((filter) => filter != ExploreFilter.all)
        .toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(padding16, 4, padding16, 0),
        child: Row(
          children: tabs.map((filter) {
            final count =
                filter == ExploreFilter.packs ? packsCount : tracksCount;
            return Expanded(child: _buildFilterTab(filter, count));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterTab(ExploreFilter filter, int count) {
    final theme = Theme.of(context);
    final isSelected = _currentFilter == filter;
    final selectedColor = theme.colorScheme.onSurface;
    final unselectedColor = theme.colorScheme.onSurface.withOpacityValue(0.5);

    return InkWell(
      onTap: () => setState(() => _currentFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacityValue(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              filter.label(context),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected ? selectedColor : unselectedColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacityValue(0.15)
                    : theme.colorScheme.onSurface.withOpacityValue(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected ? theme.colorScheme.primary : unselectedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(WidgetRef ref) {
    if (_searchQuery.isEmpty) {
      final explorePacksAsync = ref.watch(explorePacksProvider);
      return explorePacksAsync.when(
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
          return _buildPackList(context, ref, packs);
        },
        error: (err, stack) {
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
        loading: () => [
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    } else {
      return _buildSearchResults(ref);
    }
  }

  List<Widget> _buildSearchResults(WidgetRef ref) {
    final searchTracksAsync = ref.watch(searchTracksProvider(_searchQuery));
    final packs = ref.watch(filteredPacksProvider(_searchQuery));

    return searchTracksAsync.when(
      data: (tracks) {
        final filteredPacks =
            _currentFilter == ExploreFilter.tracks ? <PackItem>[] : packs;
        final filteredTracks =
            _currentFilter == ExploreFilter.packs ? <TrackItem>[] : tracks;

        if (filteredPacks.isEmpty && filteredTracks.isEmpty) {
          return [
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(padding16),
                  child: Text(
                    AppLocalizations.of(context)!.noResultsFound,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacityValue(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ];
        }

        final slivers = <Widget>[];

        if (filteredPacks.isNotEmpty) {
          slivers.addAll(_buildPackList(context, ref, filteredPacks));
        }

        if (filteredTracks.isNotEmpty) {
          slivers.addAll(_buildTrackList(context, ref, filteredTracks));
        }

        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));

        return slivers;
      },
      error: (err, stack) {
        final error = err is AppError ? err : const UnknownError();
        return [
          SliverFillRemaining(
            child: MeditoErrorWidget(
              error: error,
              isScaffold: false,
              onTap: () => ref.invalidate(searchTracksProvider(_searchQuery)),
            ),
          ),
        ];
      },
      loading: () => [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  List<Widget> _buildTrackList(
    BuildContext context,
    WidgetRef ref,
    List<TrackItem> tracks,
  ) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          padding16,
          padding16,
          padding16,
          0,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = tracks[index];
              return Padding(
                key: ValueKey('track_${item.id}'),
                padding: const EdgeInsets.only(bottom: padding16),
                child: TrackCardWidget(
                  title: item.title,
                  subTitle: item.subtitle,
                  coverUrlPath: item.coverUrl,
                  onTap: () {
                    unfocusSearch();
                    handleNavigation(
                      TypeConstants.track,
                      [item.id, item.path],
                      context,
                      ref: ref,
                    );
                  },
                ),
              );
            },
            childCount: tracks.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildPackList(
    BuildContext context,
    WidgetRef ref,
    List<PackItem> packItems,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          padding16,
          padding16,
          padding16,
          0,
        ),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: padding16,
          crossAxisSpacing: padding16,
          itemBuilder: (context, index) {
            final item = packItems[index];
            return RepaintBoundary(
              key: ValueKey('pack_${item.id}'),
              child: PackCardWidget(
                title: item.title,
                subTitle: item.subtitle,
                coverUrlPath: item.coverUrl,
                onTap: () {
                  unfocusSearch();
                  handleNavigation(
                    TypeConstants.pack,
                    [item.id, item.path],
                    context,
                    ref: ref,
                  );
                },
              ),
            );
          },
          childCount: packItems.length,
        ),
      ),
    ];
  }
}

class SearchBox extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final TextEditingController controller;
  final FocusNode focusNode;

  const SearchBox({
    super.key,
    required this.onChanged,
    required this.onClear,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlineSide = BorderSide(
      color: theme.colorScheme.outline.withOpacityValue(0.3),
      width: 0.5,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.searchMeditations,
        prefixIcon: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: MeditoIcon(
              assetName: MeditoIcons.search,
              size: 24,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        suffixIcon: IconButton(
          tooltip: AppLocalizations.of(context)!.clearSearch,
          icon: Icon(
            Icons.clear,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: onClear,
        ),
        filled: true,
        fillColor: theme.cardColor,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacityValue(0.69),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: outlineSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: outlineSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: outlineSide,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: outlineSide,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: outlineSide,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: outlineSide,
        ),
      ),
      style: TextStyle(color: theme.colorScheme.onSurface),
      onChanged: onChanged,
    );
  }
}
