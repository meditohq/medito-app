import 'package:flutter/material.dart';
import 'package:medito/widgets/shimmers/folder_shimmer_widget.dart';
import 'package:medito/widgets/shimmers/track_shimmer_widget.dart';
import 'package:medito/widgets/shimmers/explore_initial_page_shimmer_widget.dart';
import 'package:medito/widgets/shimmers/background_sounds_shimmer_widget.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: FolderShimmerWidget)
Widget folderShimmer(BuildContext context) {
  return const FolderShimmerWidget();
}

@UseCase(name: 'Default', type: TrackShimmerWidget)
Widget trackShimmer(BuildContext context) {
  return const TrackShimmerWidget();
}

@UseCase(name: 'Default', type: ExploreInitialPageShimmerWidget)
Widget exploreShimmer(BuildContext context) {
  return const ExploreInitialPageShimmerWidget();
}

@UseCase(name: 'Default', type: BackgroundSoundsShimmerWidget)
Widget backgroundSoundsShimmer(BuildContext context) {
  return const BackgroundSoundsShimmerWidget();
}
