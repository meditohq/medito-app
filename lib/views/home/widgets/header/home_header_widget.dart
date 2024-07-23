import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../providers/notification/reminder_provider.dart';
import '../../../../providers/shared_preference/shared_preference_provider.dart';
import '../bottom_sheet/debug/debug_bottom_sheet_widget.dart';
import '../bottom_sheet/menu/menu_bottom_sheet_widget.dart';

class HomeHeaderWidget extends ConsumerWidget implements PreferredSizeWidget {
  const HomeHeaderWidget({
    super.key,
    required this.homeMenuModel,
    required this.greeting,
  });

  final String greeting;
  final List<HomeMenuModel> homeMenuModel;

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
                _notificationWidget(context, ref),
                _menuWidget(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeWidget(BuildContext context) {
    return LongPressDetectorWidget(
      onLongPress: () {
        showModalBottomSheet<void>(
          context: context,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14.0),
              topRight: Radius.circular(14.0),
            ),
          ),
          useRootNavigator: true,
          builder: (BuildContext context) {
            return DebugBottomSheetWidget();
          },
        );
      },
      duration: Duration(milliseconds: 500),
      child: Text(
        greeting,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ColorConstants.walterWhite,
              height: 0,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              fontFamily: SourceSerif,
            ),
      ),
    );
  }

  Material _menuWidget(BuildContext context) {
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
          showModalBottomSheet<void>(
            context: context,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.0),
                topRight: Radius.circular(14.0),
              ),
            ),
            useRootNavigator: true,
            builder: (BuildContext context) {
              return MenuBottomSheetWidget(
                homeMenuModel: homeMenuModel,
              );
            },
          );
        },
      ),
    );
  }

  Widget _notificationWidget(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      shape: CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: IconButton(
        icon: const Icon(
          Icons.notifications,
          size: 24,
        ),
        onPressed: () {
          _selectTime(context, ref);
        },
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, WidgetRef ref) async {
    var prefs = ref.read(sharedPreferencesProvider);

    final initialTime = _getInitialTime(prefs);

    final pickedTime = await _showTimePicker(context, initialTime);

    if (pickedTime != null) {
      await _scheduleNotification(ref, pickedTime);
      await _savePickedTime(prefs, pickedTime);
      _showSnackBar(context, pickedTime);
    }
  }

  TimeOfDay _getInitialTime(SharedPreferences prefs) {
    var savedHour = prefs.getInt(SharedPreferenceConstants.savedHours) ??
        TimeOfDay.now().hour;
    var savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes) ??
        (TimeOfDay.now().minute + 1);

    return TimeOfDay(hour: savedHour, minute: savedMinute);
  }

  Future<TimeOfDay?> _showTimePicker(
    BuildContext context,
    TimeOfDay initialTime,
  ) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: StringConstants.pickTimeHelpText,
    );
  }

  Future<void> _scheduleNotification(
    WidgetRef ref,
    TimeOfDay pickedTime,
  ) async {
    await ref.read(reminderProvider).scheduleDailyNotification(pickedTime);
  }

  Future<void> _savePickedTime(
    SharedPreferences prefs,
    TimeOfDay pickedTime,
  ) async {
    await prefs.setInt(SharedPreferenceConstants.savedHours, pickedTime.hour);
    await prefs.setInt(
      SharedPreferenceConstants.savedMinutes,
      pickedTime.minute,
    );
  }

  void _showSnackBar(BuildContext context, TimeOfDay pickedTime) {
    showSnackBar(
      context,
      StringConstants.reminderNotificationScheduled +
          ' ' +
          pickedTime.format(context),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(72.0);
}
