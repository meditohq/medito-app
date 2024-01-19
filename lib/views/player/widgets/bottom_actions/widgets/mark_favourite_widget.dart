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
    return IconButton(
      onPressed: handleLike,
      icon: Icon(
        Icons.favorite,
        color:
            isLiked ? ColorConstants.lightPurple : ColorConstants.walterWhite,
      ),
    );
  }

  void handleLike() async {
    try {
      setState(() {
        isLiked = !isLiked;
      });
      var data = LikeDislikeModel(isLiked, widget.trackModel, widget.file);
      await ref.read(
        likeDislikeCombineProvider(data).future,
      );
    } catch (e) {
      setState(() {
        isLiked = !isLiked;
      });
      showSnackBar(context, e.toString());
    }
  }
}
