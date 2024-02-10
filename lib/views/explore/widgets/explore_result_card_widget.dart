import 'package:Medito/constants/constants.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class ExploreResultCardWidget extends StatelessWidget {
  const ExploreResultCardWidget({
    super.key,
    required this.description,
    required this.title,
    required this.coverUrlPath,
    this.onTap,
  });

  final String title;
  final String description;
  final String coverUrlPath;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              height: 56,
              width: 56,
              child: NetworkImageWidget(
                url: coverUrlPath,
              ),
            ),
            width12,
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(textTheme, title: title),
                  _description(
                    textTheme,
                    description: description,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Text _title(TextTheme textTheme, {required String title}) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          textTheme.titleMedium?.copyWith(letterSpacing: 0, fontFamily: DmMono),
    );
  }

  Text _description(TextTheme textTheme, {required String description}) {
    return Text(
      description,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: textTheme.titleMedium?.copyWith(
        letterSpacing: 0,
        color: ColorConstants.walterWhite,
        fontSize: 16,
        height: 1.28,
      ),
    );
  }
}
