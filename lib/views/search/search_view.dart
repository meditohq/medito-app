import 'package:Medito/views/search/widgets/search_result_card_widget.dart';
import 'package:flutter/material.dart';

import 'widgets/search_appbar_widget.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    const listViewPadding =
        EdgeInsets.only(top: 20, bottom: 60, left: 15, right: 15);

    return Scaffold(
      appBar: SearchAppbarWidget(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: listViewPadding,
              itemBuilder: (BuildContext context, int index) {
                return SearchResultCardWidget(
                  title: 'Practice',
                  description:
                      'A trip to a cabin near a beautiful lake during summer',
                  coverUrlPath:
                      'https://images.medito.space/nsUsoAf9PMwuBXNk.png',
                );
              },
              itemCount: 10,
            ),
          ),
        ],
      ),
    );
  }
}
