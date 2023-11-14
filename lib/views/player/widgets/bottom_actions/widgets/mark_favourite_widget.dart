import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarkFavouriteWidget extends ConsumerStatefulWidget {
  const MarkFavouriteWidget({
    super.key,
    required this.trackModel,
    required this.file,
  });
  final TrackModel trackModel;
  final TrackFilesModel file;
  @override
  ConsumerState<MarkFavouriteWidget> createState() =>
      _MarkFavouriteWidgetState();
}

class _MarkFavouriteWidgetState extends ConsumerState<MarkFavouriteWidget> {
  bool isLiked = false;
  @override
  void initState() {
    isLiked = widget.trackModel.isLiked;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: IconButton(
        onPressed: () => handleLike(ref, widget.trackModel.id, widget.file.id),
        icon: Icon(
          Icons.favorite,
          color:
              isLiked ? ColorConstants.lightPurple : ColorConstants.walterWhite,
        ),
      ),
    );
  }

  void handleLike(
    WidgetRef ref,
    String trackId,
    String audioFileId,
  ) async {
    try {
      setState(() {
        isLiked = !isLiked;
      });
      await ref.read(
        likeDislikeTrackProvider(
          isLike: isLiked,
          trackId: trackId,
          audioFileId: audioFileId,
        ).future,
      );
      ref.invalidate(tracksProvider);
    } catch (e) {
      setState(() {
        isLiked = !isLiked;
      });
      showSnackBar(context, e.toString());
    }
  }
}
