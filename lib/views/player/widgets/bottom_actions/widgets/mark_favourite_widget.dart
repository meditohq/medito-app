import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarkFavouriteWidget extends ConsumerWidget {
  const MarkFavouriteWidget({
    super.key,
    required this.trackModel,
    required this.file,
  });
  final TrackModel trackModel;
  final TrackFilesModel file;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 60,
      child: IconButton(
        onPressed: () {},
        icon: Icon(
          Icons.favorite,
          color: ColorConstants.walterWhite,
        ),
      ),
    );
  }
}
