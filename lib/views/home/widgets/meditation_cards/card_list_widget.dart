import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'widgets/card_widget.dart';
import 'package:flutter/material.dart';
import 'widgets/card_title_widget.dart';

class CardListWidget extends StatelessWidget {
  const CardListWidget({super.key, required this.row});

  final HomeRowsModel row;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return SizedBox(
      width: size.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CardTitleWidget(title: row.title),
          height16,
          SizedBox(
            height: 165,
            child: ListView.builder(
              itemCount: row.items.length,
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                var element = row.items[index];

                return Padding(
                  padding: EdgeInsets.only(
                    right: 16,
                    left: index == 0 ? 16 : 0,
                  ),
                  child: CardWidget(
                    title: element.title,
                    coverUrlPath: element.coverUrl,
                    onTap: () => handleNavigation(
                      context: context,
                      element.type,
                      [element.path.toString().getIdFromPath(), element.path],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
