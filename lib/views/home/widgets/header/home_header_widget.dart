import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class HomeHeaderWidget extends ConsumerWidget implements PreferredSizeWidget {
  const HomeHeaderWidget({
    Key? key,
    required this.greeting,
  }) : super(key: key);

  final String greeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _welcomeWidget(context),
        ],
      ),
    );
  }

  Widget _welcomeWidget(BuildContext context) {
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
