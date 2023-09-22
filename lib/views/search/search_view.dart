import 'package:flutter/material.dart';
import 'widgets/search_appbar_widget.dart';
import 'widgets/search_result_widget.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: SearchAppbarWidget(),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: SearchResultWidget(),
          ),
        ],
      ),
    );
  }
}
