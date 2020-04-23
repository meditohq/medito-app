import 'dart:io';

import 'package:Medito/utils/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

String blankIfNull(String s) {
  if (s == null)
    return "";
  else
    return s;
}

formatDuration(Duration d) {
  var s = d.toString().split('.').first;
  if (s.startsWith('0:0')) {
    s = s.replaceFirst('0:0', '');
  }
  return s;
}

TextTheme buildDMSansTextTheme(BuildContext context) {
  return GoogleFonts.interTextTheme(Theme.of(context).textTheme.copyWith(
        title: TextStyle(
            fontSize: 20.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w500),
        headline: TextStyle(
            //h2
            height: 1.4,
            fontSize: 20.0,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w600),
        subhead: TextStyle(
            fontSize: 16.0,
            height: 1.4,
            color: MeditoColors.lightTextColor,
            fontWeight: FontWeight.normal),
        display1: TextStyle(
            //pill big
            height: 1.4,
            fontSize: 18.0,
            color: MeditoColors.darkBGColor,
            fontWeight: FontWeight.normal),
        display2: TextStyle(
            //pill small
            fontSize: 14.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.normal),
        display3: TextStyle(
            //this is for bottom sheet text
            fontSize: 16.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.normal),
        body1: TextStyle(
            //this is for 'text'
            fontSize: 16.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.normal),
        subtitle: TextStyle(
            //this is for 'h3' markdown
            fontSize: 18.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.normal),
        display4: TextStyle(
            //bottom sheet filter chip
            //horizontal announcement
            fontSize: 14.0,
            height: 1.25,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w400),
        caption: TextStyle(
            //attr widget
            fontSize: 14.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w400),
        body2: TextStyle(
            //for 'MORE DETAILS'
            fontSize: 14.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w600),
      ));
}

Widget getNetworkImageWidget(String url,
    {Color svgColor, double startHeight = 0.0}) {
  if (url.endsWith('png')) {
    return CachedNetworkImage(
      placeholder: (context, url) => Container(
        height: startHeight,
      ),
      imageUrl: url,
    );
  } else {
    return SvgPicture.network(
      url,
      color: svgColor != null ? svgColor : MeditoColors.darkBGColor,
    );
  }
}

Future<bool> checkConnectivity() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return true;
    }
  } on SocketException catch (_) {
    return false;
  }
  return false;
}

Color parseColor(String color) =>
    Color(int.parse(color?.replaceFirst('#', ''), radix: 16));

void createSnackBar(String message, BuildContext context) {
  final snackBar =
      new SnackBar(content: new Text(message), backgroundColor: Colors.red);

  // Find the Scaffold in the Widget tree and use it to show a SnackBar!
  Scaffold.of(context).showSnackBar(snackBar);
}

void updateStreak(SharedPreferences prefs, {String streak = ''}) async {
  assert(prefs != null);

  if (streak.isNotEmpty) {
    prefs.setInt('streakCount', int.parse(streak));
    return;
  }

  List<String> streakList = prefs.getStringList('streakList');
  int streakCount = prefs.getInt('streakCount');

  if (streakList == null) {
    streakList = [];
  }
  if (streakCount == null) {
    streakCount = 0;
  }

  if (streakList.length > 0) {
    //if you have meditated before, was it on today? if not, increase counter
    final lastDayInStreak =
        DateTime.fromMillisecondsSinceEpoch(int.parse(streakList.last));
    final now = DateTime.now();

    if (!isSameDay(lastDayInStreak, now)) {
      incrementStreakCounter(streakCount, prefs);
    }
  } else {
    //if you've never done one before
    incrementStreakCounter(streakCount, prefs);
  }

  streakList.add(DateTime.now().millisecondsSinceEpoch.toString());
  prefs.setStringList('streakList', streakList);
}

void incrementStreakCounter(int streakCount, SharedPreferences prefs) {
  streakCount++;
  prefs.setInt('streakCount', streakCount);
}

Future<String> getStreak(SharedPreferences prefs) async {
  var streak = prefs.getInt('streakCount');
  if (streak == null)
    return '0';
  else
    return streak.toString();
}

bool isDayBefore(DateTime day1, DateTime day2) {
  return day1.year == day2.year &&
      day1.month == day2.month &&
      day1.day == day2.day - 1;
}

bool isSameDay(DateTime day1, DateTime day2) {
  return day1.year == day2.year &&
      day1.month == day2.month &&
      day1.day == day2.day;
}
