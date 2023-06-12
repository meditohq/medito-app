import 'package:Medito/constants/styles/widget_styles.dart';
import 'widgets/card_widget.dart';
import 'package:flutter/material.dart';
import 'widgets/card_title_widget.dart';

class CardListWidget extends StatelessWidget {
  const CardListWidget({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return SizedBox(
      width: size.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CardTitleWidget(title: title),
          height16,
          SizedBox(
            height: 165,
            child: ListView.builder(
              itemCount: 10,
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, snapshot) {
                return CardWidget(
                  tag: 'Tag 1',
                  title: 'The skill of mindfulness',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
