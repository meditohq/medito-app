import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SessionButtons extends StatelessWidget {
  final List<SessionAudioModel> audios;
  const SessionButtons({super.key, required this.audios});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: audios.length,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                audios[i].guideName,
                style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                      color: MeditoColors.walterWhite,
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
      children: audios[i].files.map((e) => _getGridItem(context, e)).toList(),
    );
  }

  InkWell _getGridItem(BuildContext context, SessionFilesModel files) {
    return InkWell(
      onTap: () {
        context.go(GoRouter.of(context).location + files.path.toString());
      },
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 171,
        height: 56,
        decoration: BoxDecoration(
          color: MeditoColors.greyIsTheNewGrey,
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
        ),
        child: Center(
          child: Text(
            '${convertDurationToMinutes(milliseconds: files.duration)} mins',
            style: Theme.of(context)
                .primaryTextTheme
                .bodyLarge
                ?.copyWith(color: MeditoColors.walterWhite, fontFamily: DmMono),
          ),
        ),
      ),
    );
  }
}
