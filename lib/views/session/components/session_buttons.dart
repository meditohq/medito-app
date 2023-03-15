import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionButtons extends StatelessWidget {
  final SessionModel sessionModel;
  const SessionButtons({super.key, required this.sessionModel});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: sessionModel.audio.length,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sessionModel.audio[i].guideName,
                style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                      color: ColorConstants.walterWhite,
                    ),
              ),
              height8,
              _gridList(context, i),
              SizedBox(height: 30),
            ],
          );
        });
  }

  Wrap _gridList(
    BuildContext context,
    int i,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: sessionModel.audio[i].files
          .map((e) => _getGridItem(context, i, e))
          .toList(),
    );
  }

  Consumer _getGridItem(
    BuildContext context,
    int audioIndex,
    SessionFilesModel file,
  ) {
    return Consumer(
      builder: (context, ref, child) => InkWell(
        onTap: () {
          context.go(
            GoRouter.of(context).location + PlayerPath,
            extra: {'sessionModel': sessionModel, 'file': file},
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 171,
          height: 56,
          decoration: BoxDecoration(
            color: ColorConstants.greyIsTheNewGrey,
            borderRadius: BorderRadius.all(
              Radius.circular(14),
            ),
          ),
          child: Center(
            child: Text(
              '${convertDurationToMinutes(milliseconds: file.duration)} mins',
              style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                  color: ColorConstants.walterWhite, fontFamily: DmMono),
            ),
          ),
        ),
      ),
    );
  }
}
