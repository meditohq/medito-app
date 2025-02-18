import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/widgets/errors/medito_error_widget.dart';
import 'package:medito/widgets/widgets.dart';
import '../../providers/pack/pack_provider.dart';
import '../../models/models.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/views/path/components/track_item_widget.dart';

class JourneyView extends ConsumerStatefulWidget {
  const JourneyView({super.key});

  @override
  ConsumerState<JourneyView> createState() => _JourneyViewState();
}

class _JourneyViewState extends ConsumerState<JourneyView>
    with AutomaticKeepAliveClientMixin<JourneyView> {
  final ScrollController _scrollController = ScrollController();
  static const String pathId = 'Izv6OObcu3X2H9fu';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pathState = ref.watch(packProvider(packId: pathId));

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: ColorConstants.ebony,
        title: const Column(
          children: [
            HomeHeaderWidget(
              greeting: StringConstants.path,
            ),
          ],
        ),
        elevation: 0.0,
      ),
      body: pathState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => MeditoErrorWidget(
          message: 'Failed to load path: $error',
          onTap: () => ref.refresh(packProvider(packId: pathId)),
        ),
        data: (pack) => _buildContent(pack),
      ),
    );
  }

  Widget _buildContent(PackModel pack) {
    final firstUncompleted = pack.items.firstWhere(
      (item) => !(item.isCompleted ?? false),
      orElse: () => pack.items.first,
    );
    final firstUncompletedIndex = pack.items.indexOf(firstUncompleted);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentTrack = ref.read(playerProvider);
      if (currentTrack?.id != firstUncompleted.id) {
        ref
            .read(nextTrackProvider.notifier)
            .preloadNextTrack(firstUncompleted.id);
      }
    });

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(packProvider(packId: pathId)),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Center(
                    child: Transform.translate(
                      offset: Offset(
                        sin(index * 0.5 - pi / 2) *
                            100, // Horizontal wave effect from center
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

  void _scrollListener() => setState(() {});

  @override
  bool get wantKeepAlive => true;
}
class _TrackItem extends ConsumerWidget {
  final PackItemsModel item;
  final int index;
  final bool isFirstUncompleted;
  final GlobalKey _buttonKey = GlobalKey();

  _TrackItem({
    required this.item,
    required this.index,
    required this.isFirstUncompleted,
  });

  Future<void> _handleItemTap(BuildContext context, WidgetRef ref) async {
    final guideNameAsync = ref.read(guideNamePreferenceProvider);
    final preferredDuration = ref.read(durationPreferenceProvider);
    final trackId = item.id;
    final cachedTrack = ref.read(playerProvider);

    await PermissionHandler.requestMediaPlaybackPermission(context);

    TrackModel? trackState;

    if (cachedTrack?.id == trackId) {
      trackState = cachedTrack;
    } else {
      trackState = await ref.read(tracksProvider(trackId: trackId).future);
    }

    final selectedAudio = _selectBestAudioMatch(
      trackState?.audio ?? [],
      guideName: guideNameAsync.value,
      preferredDuration: preferredDuration,
    );

    if (selectedAudio != null && trackState != null) {
      await ref.read(playerProvider.notifier).loadSelectedTrack(
            trackModel: trackState,
            file: selectedAudio.files.first,
          );
      _navigateToPlayer(context, ref);
    }
  }

  void _navigateToPlayer(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlayerView()),
    ).then((value) => {
          ref.invalidate(packProvider),
        });
  }

  TrackAudioModel? _selectBestAudioMatch(
    List<TrackAudioModel> audioList, {
    String? guideName,
    int? preferredDuration,
  }) {
    if (audioList.isEmpty) return null;

    // Filter by guide name if available
    List<TrackAudioModel> filtered = guideName != null
        ? audioList.where((a) => a.guideName == guideName).toList()
        : audioList;

    // If no matches for guide name, use all audio
    if (filtered.isEmpty) filtered = audioList;

    // Find closest duration match
    TrackAudioModel? closest;
    int? closestDiff;

    for (final audio in filtered) {
      final duration = audio.files.first.duration;
      final diff = (preferredDuration ?? duration) - duration;

      if (closest == null || diff.abs() < closestDiff!) {
        closest = audio;
        closestDiff = diff.abs();
      }
    }

    return closest ?? audioList.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = item.isCompleted ?? false;
    final backgroundColor = isCompleted
        ? ColorConstants.lightPurple
        : isFirstUncompleted
            ? ColorConstants.amber
            : Colors.grey[800];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        key: _buttonKey,
        onTap: () => _showSpeechBubble(context, ref),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: isFirstUncompleted
                    ? Border.all(color: ColorConstants.white, width: 0.5)
                    : null,
              ),
              child: isCompleted
                  ? HugeIcon(
                      icon: HugeIcons.strokeStandardTick02,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeechBubble(BuildContext context, WidgetRef ref) {
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero);
    final size = renderBox?.size;

    if (offset == null || size == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    const bubbleWidth = 200.0;
    const bubbleHeight = 100.0;
    final leftPosition = (offset.dx + size.width / 2) - bubbleWidth / 2;
    final topPosition = offset.dy - bubbleHeight - 12;

    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Click-outside handler
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => overlayEntry.remove(),
            child: Container(color: Colors.transparent.withAlpha(1)),
          ),
          // Bubble content
          Positioned(
            left: leftPosition.clamp(16.0, screenWidth - bubbleWidth - 16),
            top: topPosition,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  CustomPaint(
                    size: const Size(20, 10),
                    painter: _TrianglePainter(),
                  ),
                  Container(
                    width: bubbleWidth,
                    constraints: const BoxConstraints(minHeight: 100),
                    decoration: BoxDecoration(
                      color: ColorConstants.ebony,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: ColorConstants.amber,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            onPressed: () {
                              overlayEntry.remove();
                              _handleItemTap(context, ref);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ColorConstants.ebony
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NextTrackNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async => null;

  Future<void> preloadNextTrack(String trackId) async {
    state = const AsyncValue.loading();
    try {
      final track = await ref.read(tracksProvider(trackId: trackId).future);
      final selectedAudio = _selectBestAudioMatch(
        track.audio,
        guideName: ref.read(guideNamePreferenceProvider).value,
        preferredDuration: ref.read(durationPreferenceProvider),
      );

      if (selectedAudio != null) {
        ref.read(playerProvider.notifier).cacheTrackData(
              track: track,
              file: selectedAudio.files.first,
            );
      }
      state = AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  TrackAudioModel? _selectBestAudioMatch(
    List<TrackAudioModel> audioList, {
    String? guideName,
    int? preferredDuration,
  }) {
    if (audioList.isEmpty) return null;

    // Filter by guide name if available
    List<TrackAudioModel> filtered = guideName != null
        ? audioList.where((a) => a.guideName == guideName).toList()
        : audioList;

    // If no matches for guide name, use all audio
    if (filtered.isEmpty) filtered = audioList;

    // Find closest duration match
    TrackAudioModel? closest;
    int? closestDiff;

    for (final audio in filtered) {
      final duration = audio.files.first.duration;
      final diff = (preferredDuration ?? duration) - duration;

      if (closest == null || diff.abs() < closestDiff!) {
        closest = audio;
        closestDiff = diff.abs();
      }
    }

    return closest ?? audioList.first;
  }
}

final nextTrackProvider = AsyncNotifierProvider<NextTrackNotifier, void>(
  NextTrackNotifier.new,
);

