import 'package:Medito/constants/constants.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class SearchResultCardWidget extends StatelessWidget {
  const SearchResultCardWidget({
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

    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: ColorConstants.onyx,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 145,
              width: 175,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: NetworkImageWidget(
                  url: coverUrlPath,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: 15,
                top: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(textTheme, title: title),
                  height4,
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
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: textTheme.titleMedium?.copyWith(
        letterSpacing: 0,
      ),
    );
  }

  Text _description(TextTheme textTheme, {required String description}) {
    return Text(
      description,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: textTheme.titleMedium
          ?.copyWith(letterSpacing: 0, color: ColorConstants.walterWhite),
    );
  }
}
