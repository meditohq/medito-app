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
import 'package:medito/widgets/medito_huge_icon.dart';
import 'package:medito/widgets/track_card_widget.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:medito/widgets/pack_card_widget.dart';
import 'package:medito/utils/utils.dart';

final filteredPacksProvider =
    Provider.autoDispose.family<List<PackItem>, String>((ref, query) {
  final packs = ref.watch(
    explorePacksProvider.select((asyncValue) => asyncValue.valueOrNull ?? []),
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

  @override
  void initState() {
    super.initState();
    _logScreenView();
    AppLogger.d('ExploreView', 'initState');
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
    AppLogger.d('ExploreView', 'build started');
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
    final tracksCount = searchTracksAsync.valueOrNull?.length ?? 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
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

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: padding16),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                children: ExploreFilter.values
                    .where((filter) => filter != ExploreFilter.all)
                    .map((filter) {
                  final count =
                      filter == ExploreFilter.packs ? packsCount : tracksCount;
                  return _buildFilterChip(filter, count);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(ExploreFilter filter, int count) {
    final isSelected = _currentFilter == filter;

    return ChoiceChip(
      label: Text(
        '${filter.label(context)} ($count)',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
      ),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (selected) {
        if (selected) {
          setState(() => _currentFilter = filter);
        }
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      iconTheme: IconThemeData(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  List<Widget> _buildContentSlivers(WidgetRef ref) {
    AppLogger.d('ExploreView', '_buildContentSlivers query: $_searchQuery');
    if (_searchQuery.isEmpty) {
      final explorePacks = ref.watch(explorePacksProvider);
      return explorePacks.when(
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
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            Icons.clear,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: onClear,
        ),
        filled: true,
        fillColor:
            Theme.of(context).colorScheme.surfaceTint.withOpacityValue(0.1),
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacityValue(0.69),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      onChanged: onChanged,
    );
  }
}
