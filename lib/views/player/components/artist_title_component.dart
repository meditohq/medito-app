import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:Medito/models/models.dart';

class ArtistTitleComponent extends StatelessWidget {
  const ArtistTitleComponent({super.key, required this.sessionModel});
  final SessionModel sessionModel;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: Column(
        children: [
          _title(context),
          _subtitle(),
        ],
      ),
    );
  }

  Text _title(BuildContext context) {
    return Text(
      sessionModel.title,
      textAlign: TextAlign.center,
      style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
          fontFamily: ClashDisplay,
          color: ColorConstants.walterWhite,
          fontSize: 24,
          letterSpacing: 1),
    );
  }

  Padding _subtitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: MarkdownComponent(
          body:
              '${sessionModel.artist?.name ?? ''} ${sessionModel.artist?.path ?? ''}'),
    );
  }
}
