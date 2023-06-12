import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class CardTitleWidget extends StatelessWidget {
  const CardTitleWidget({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(fontSize: 22, fontFamily: ClashDisplay),
      ),
    );
  }
}
