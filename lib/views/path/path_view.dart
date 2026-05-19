import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/player/next_track_provider.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/path/components/track_item_widget.dart';
import 'package:medito/widgets/errors/medito_error_widget.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:medito/exceptions/app_error.dart';

import '../../models/models.dart';
import '../../providers/pack/pack_provider.dart';

class JourneyView extends ConsumerStatefulWidget {
  const JourneyView({super.key});

  static const double kItemWidth = 64.0;
  static const double kItemHeight = 64.0;

  @override
  ConsumerState<JourneyView> createState() => _JourneyViewState();
}

class _JourneyViewState extends ConsumerState<JourneyView>
    with AutomaticKeepAliveClientMixin<JourneyView> {
  final ScrollController _scrollController = ScrollController();
  static const String pathId = 'Izv6OObcu3X2H9fu';
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.position.isScrollingNotifier.value) {
        _initialScrollDone = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pathState = ref.watch(packProvider(packId: pathId));

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: ColorConstants.ebony,
        title: Column(
          children: [
            HomeHeaderWidget(
              greeting: AppLocalizations.of(context)!.path,
            ),
          ],
        ),
        elevation: 0.0,
      ),
      body: pathState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          final error = err is AppError ? err : const UnknownError();
          return MeditoErrorWidget(
            error: error,
            onTap: () => ref.refresh(packDataProvider(packId: pathId)),
          );
        },
        data: (pack) {
          if (!_initialScrollDone) {
            _scrollToFirstUncompleted(pack);
          }
          return _buildContent(pack);
        },
      ),
    );
  }

  void _scrollToFirstUncompleted(PackModel pack) {
    final firstUncompleted = pack.items.firstWhere(
      (item) => !(item.isCompleted ?? false),
      orElse: () => pack.items.first,
    );
    final index = pack.items.indexOf(firstUncompleted);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final position = index * JourneyView.kItemHeight;
        _scrollController.jumpTo(position.clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        ));
        _initialScrollDone = true;
      }
    });
  }

  Widget _buildContent(PackModel pack) {
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(packDataProvider(packId: pathId)),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final firstUncompletedIndex = pack.items.indexWhere(
                    (item) => !(item.isCompleted ?? false),
                  );

                  final screenWidth = MediaQuery.of(context).size.width;
                  final availableWidth =
                      screenWidth - 80; // 40px padding on both sides
                  final maxOffset = availableWidth * 0.25;

                  return Center(
                    child: Transform.translate(
                      offset: Offset(
                        sin(index * 0.5 - pi / 2) * maxOffset,
                        0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        child: TrackItemWidget(
                          key: ValueKey('track_item_${pack.items[index].id}'),
                          item: pack.items[index],
                          index: index,
                          isFirstUncompleted: index == firstUncompletedIndex,
                        ),
                      ),
                    ),
                  );
                },
                childCount: pack.items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

final nextTrackProvider = AsyncNotifierProvider<NextTrackNotifier, void>(
  NextTrackNotifier.new,
);
