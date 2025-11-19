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

// Create a filtered provider to handle search logic efficiently
final filteredPacksProvider =
    Provider.autoDispose.family<List<PackItem>, String>((ref, query) {
  final packsAsync = ref.watch(explorePacksProvider);
  return packsAsync.maybeWhen(
    data: (packs) {
      if (query.isEmpty) return packs;
      final lowerQuery = query.toLowerCase();
      return packs
          .where((p) =>
              p.title.toLowerCase().contains(lowerQuery) ||
              p.subtitle.toLowerCase().contains(lowerQuery))
          .toList();
    },
    orElse: () => [],
  );
});

class ExploreView extends ConsumerStatefulWidget {
  final FocusNode searchFocusNode;

  const ExploreView({super.key, required this.searchFocusNode});

  @override
  ConsumerState<ExploreView> createState() => ExploreViewState();
}

// Make the state class public so it can be referenced by GlobalKey
class ExploreViewState extends ConsumerState<ExploreView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  bool _hasLoadedData = false;
  final _analytics = FirebaseAnalyticsService();

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void unfocusSearch() {
    widget.searchFocusNode.unfocus();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      var asciiQuery = value.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
      setState(() {
        _searchQuery = asciiQuery;
        if (_searchQuery.isEmpty) ref.invalidate(explorePacksProvider);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _logScreenView();
    AppLogger.d('ExploreView', 'initState');
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

  @override
  Widget build(BuildContext context) {
    AppLogger.d('ExploreView', 'build started');
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          edgeOffset: 150,
          onRefresh: _refreshExploreList,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                expandedHeight: 134.0,
                collapsedHeight: 0,
                toolbarHeight: 0,
                floating: true,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: padding16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HomeHeaderWidget(
                            greeting: AppLocalizations.of(context)!.explore),
                        const SizedBox(height: 18.0),
                        SearchBox(
                          controller: _searchController,
                          focusNode: widget.searchFocusNode,
                          onChanged: _onSearchChanged,
                          onClear: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 18.0),
                      ],
                    ),
                  ),
                ),
              ),
              ..._buildContentSlivers(ref),
            ],
          ),
        ),
      ),
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
              const SliverToBoxAdapter(
                child: Center(child: Text('No packs available')),
              ),
            ];
          }
          return _buildPackList(context, ref, packs);
        },
        error: (err, stack) {
          final error = err is AppError ? err : const UnknownError();
          return [
            SliverToBoxAdapter(
              child: MeditoErrorWidget(
                error: error,
                isScaffold: false,
                onTap: () => ref.invalidate(explorePacksProvider),
              ),
            )
          ];
        },
        loading: () => [
          const SliverToBoxAdapter(child: LoadingWidget()),
        ],
      );
    } else {
      final searchTracksAsync = ref.watch(searchTracksProvider(_searchQuery));
      final packs = ref.watch(filteredPacksProvider(_searchQuery));

      // We still need to handle loading state of packs if they are being fetched for the first time
      final explorePacksAsync = ref.watch(explorePacksProvider);

      return searchTracksAsync.when(
        data: (tracks) {
          // Check if packs are still loading
          if (explorePacksAsync.isLoading) {
            return [const SliverToBoxAdapter(child: LoadingWidget())];
          }

          if (packs.isEmpty && tracks.isEmpty) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: padding16, vertical: padding16),
                  child: Text(
                    AppLocalizations.of(context)!.noResultsFound,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(((0.7).clamp(0.0, 1.0) * 255).round()),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ];
          }

          List<Widget> slivers = [];

          if (packs.isNotEmpty) {
            slivers.add(
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: padding16, right: padding16, bottom: padding16),
                  child: Text(
                    AppLocalizations.of(context)!.packsSectionHeader,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            );
            slivers.addAll(_buildPackList(context, ref, packs));
            slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
          }

          if (tracks.isNotEmpty) {
            slivers.add(
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: padding16,
                    top: padding8,
                    left: padding16,
                    right: padding16,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.tracksSectionHeader,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            );
            slivers.addAll(_buildTrackList(context, ref, tracks));
          }

          return slivers;
        },
        error: (err, stack) {
          var errorMsg = err.toString();
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Track search error:',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(errorMsg,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ];
        },
        loading: () => [
          const SliverToBoxAdapter(child: LoadingWidget()),
        ],
      );
    }
  }

  List<Widget> _buildTrackList(
      BuildContext context, WidgetRef ref, List<TrackItem> tracks) {
    final isWideScreen = MediaQuery.of(context).size.shortestSide >= 600;

    if (isWideScreen) {
      return [
        SliverPadding(
          padding: const EdgeInsets.only(
              top: padding16, left: padding16, right: padding16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: padding16,
              crossAxisSpacing: padding16,
              childAspectRatio: 1.0, // Adjust as needed
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                var item = tracks[index];
                return TrackCardWidget(
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
                );
              },
              childCount: tracks.length,
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: padding16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              var item = tracks[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
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
      BuildContext context, WidgetRef ref, List<PackItem> packItems) {
    final width = MediaQuery.of(context).size.width;
    var crossAxisCount = width > 600 ? 3 : 2;

    return [
      SliverPadding(
        padding: const EdgeInsets.only(
          left: padding16,
          right: padding16,
          top: padding16,
        ),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: padding16,
          crossAxisSpacing: padding16,
          childCount: packItems.length,
          itemBuilder: (context, index) {
            var item = packItems[index];
            return PackCardWidget(
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
            );
          },
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
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceTint
            .withAlpha(((0.1).clamp(0.0, 1.0) * 255).round()),
        hintStyle: TextStyle(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withAlpha(((0.6).clamp(0.0, 1.0) * 255).round()),
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

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
