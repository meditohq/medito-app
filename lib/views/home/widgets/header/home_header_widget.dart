import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';

class HomeHeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  const HomeHeaderWidget({
    super.key,
    required this.greeting,
  });

  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Text(
      greeting,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: ColorConstants.white,
            height: 0,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            fontFamily: SourceSerif,
          ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72.0);
}
