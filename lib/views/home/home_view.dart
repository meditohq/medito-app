import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'widgets/filters/filter_widget.dart';
import 'widgets/header/home_header_widget.dart';
import 'widgets/search/search_widget.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            height8,
            HomeHeaderWidget(),
            SearchWidget(),
            FilterWidget(),
          ],
        ),
      ),
    );
  }
}
