import 'package:Medito/views/search/widgets/search_result_card_widget.dart';
import 'package:flutter/material.dart';

import 'widgets/search_appbar_widget.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SearchAppbarWidget(),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 15.0,
                childAspectRatio: 0.72,
              ),
              padding:
                  EdgeInsets.only(top: 15, bottom: 60, left: 15, right: 15),
              itemBuilder: (BuildContext context, int index) {
                return SearchResultCardWidget(
                  title: 'Practice',
                  description: 'Anti-racism with your friends & loved ones',
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
