import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/settings_screen.dart';

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
          Padding(
            padding: EdgeInsets.only(top: 34),
            child: Row(
              children: [
                _settingsWidget(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeWidget(BuildContext context) {
    return Text(
      greeting,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: ColorConstants.walterWhite,
            height: 0,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            fontFamily: SourceSerif,
          ),
    );
  }

  Widget _settingsWidget(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      shape: CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: IconButton(
        icon: const Icon(
          Icons.more_vert,
          size: 24,
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SettingsScreen(),
            ),
          );
        },
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(72.0);
}
