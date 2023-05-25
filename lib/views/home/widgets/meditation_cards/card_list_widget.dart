import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:go_router/go_router.dart';
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
              itemBuilder: (context, index) {
                var element = row.items[index];

                return CardWidget(
                  title: element.title,
                  coverUrlPath: element.coverUrl,
                  onTap: () {
                    context.push(getPathFromString(
                      element.type,
                      [element.id.toString()],
                    ));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
