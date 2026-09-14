import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/providers/explore/track_search_provider.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/explore/widgets/pack_grid_sliver.dart';
import 'package:medito/views/explore/widgets/track_list_sliver.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/widgets.dart';

/// Packs whose title or subtitle contains [query]; all packs for an empty
/// query.
final searchFilteredPacksProvider = Provider.autoDispose
    .family<List<PackItem>, String>((ref, query) {
      final packs = ref.watch(
        explorePacksProvider.select((asyncValue) => asyncValue.value ?? []),
      );
      if (query.isEmpty) return packs;
      final lowerQuery = query.toLowerCase();
      return packs
          .where(
            (p) =>
                p.title.toLowerCase().contains(lowerQuery) ||
                p.subtitle.toLowerCase().contains(lowerQuery),
          )
          .toList();
    });

enum SearchFilter {
  packs,
  tracks;

  String label(BuildContext context) => switch (this) {
    SearchFilter.packs => AppLocalizations.of(context)!.packs,
    SearchFilter.tracks => AppLocalizations.of(context)!.tracks,
  };
}

/// Search results for [query]: a hint while empty, otherwise Packs and Tracks
/// tabs with counts that auto-switch to whichever has matches. Rendered as an
/// overlay above the tabs while the nav capsule holds the search field, so
/// the bottom padding follows the bar height from the enclosing Scaffold.
class SearchResults extends ConsumerStatefulWidget {
  const SearchResults({super.key, required this.query, this.onBeforeNavigate});

  final String query;

  /// Runs before a result navigates, e.g. to dismiss the keyboard.
  final VoidCallback? onBeforeNavigate;

  @override
  ConsumerState<SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends ConsumerState<SearchResults> {
  SearchFilter _filter = SearchFilter.packs;
  int? _previousPacksCount;
  int? _previousTracksCount;
  bool _filterSwitchScheduled = false;

  @override
  void didUpdateWidget(covariant SearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query.isEmpty && oldWidget.query.isNotEmpty) {
      _filter = SearchFilter.packs;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: widget.query.isEmpty
          ? [_buildEmptyState()]
          : [_buildFilterTabs(), ..._buildResults()],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(padding24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MeditoIcon(
                assetName: MeditoIcons.search,
                size: 32,
                color: theme.colorScheme.onSurface.withOpacityValue(0.3),
              ),
              const SizedBox(height: padding12),
              Text(
                AppLocalizations.of(context)!.searchEmptyHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacityValue(0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final query = widget.query;
    final packsCount = ref.watch(searchFilteredPacksProvider(query)).length;
    final tracksCount =
        ref.watch(searchTracksProvider(query)).value?.length ?? 0;

    if ((_previousPacksCount != packsCount ||
            _previousTracksCount != tracksCount) &&
        !_filterSwitchScheduled) {
      _previousPacksCount = packsCount;
      _previousTracksCount = tracksCount;
      _filterSwitchScheduled = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _filterSwitchScheduled = false;
        if (!mounted) return;
        if (_filter == SearchFilter.packs &&
            packsCount == 0 &&
            tracksCount > 0) {
          setState(() => _filter = SearchFilter.tracks);
        } else if (_filter == SearchFilter.tracks &&
            tracksCount == 0 &&
            packsCount > 0) {
          setState(() => _filter = SearchFilter.packs);
        }
      });
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(padding16, 4, padding16, 0),
        child: Row(
          children: [
            for (final filter in SearchFilter.values)
              Expanded(
                child: _FilterTab(
                  label: filter.label(context),
                  count: filter == SearchFilter.packs
                      ? packsCount
                      : tracksCount,
                  selected: _filter == filter,
                  onTap: () => setState(() => _filter = filter),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults() {
    final query = widget.query;
    final tracksAsync = ref.watch(searchTracksProvider(query));
    final packs = ref.watch(searchFilteredPacksProvider(query));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return tracksAsync.when(
      data: (tracks) {
        final shownPacks = _filter == SearchFilter.tracks
            ? <PackItem>[]
            : packs;
        final shownTracks = _filter == SearchFilter.packs
            ? <TrackItem>[]
            : tracks;

        if (shownPacks.isEmpty && shownTracks.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(padding16),
                  child: Text(
                    l10n.noResultsFound,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacityValue(0.7),
                    ),
                  ),
                ),
              ),
            ),
          ];
        }

        return [
          if (shownPacks.isNotEmpty)
            PackGridSliver(
              packs: shownPacks,
              onBeforeNavigate: widget.onBeforeNavigate,
            ),
          if (shownTracks.isNotEmpty)
            TrackListSliver(
              tracks: shownTracks,
              onBeforeNavigate: widget.onBeforeNavigate,
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + padding16,
            ),
          ),
        ];
      },
      error: (err, _) {
        final error = err is AppError ? err : const UnknownError();
        return [
          SliverFillRemaining(
            child: MeditoErrorWidget(
              error: error,
              isScaffold: false,
              onTap: () => ref.invalidate(searchTracksProvider(query)),
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

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final textColor = selected ? onSurface : onSurface.withOpacityValue(0.5);

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? primary
                  : theme.colorScheme.outline.withOpacityValue(0.2),
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? primary.withOpacityValue(0.15)
                    : onSurface.withOpacityValue(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? primary : textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
