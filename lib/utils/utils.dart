/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'dart:io';

import 'package:Medito/utils/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

TextTheme buildDMSansTextTheme(BuildContext context) {
  return GoogleFonts.dmSansTextTheme(Theme.of(context).textTheme.copyWith(
        headline6: TextStyle(
            fontSize: 20.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w500),
        headline5: TextStyle(
            //h2
            height: 1.4,
            fontSize: 20.0,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w600),
        subtitle1: TextStyle(
            fontSize: 16.0,
            height: 1.4,
            color: MeditoColors.lightTextColor,
            fontWeight: FontWeight.normal),
        headline4: TextStyle(
            //pill big
            height: 1.4,
            fontSize: 18.0,
            color: MeditoColors.darkBGColor,
            fontWeight: FontWeight.normal),
        headline3: TextStyle(
            //pill small
            fontSize: 14.0,
            height: 1.25,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.normal),
        headline2: TextStyle(
            //this is for bottom sheet text
            fontSize: 16.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.normal),
        bodyText2: TextStyle(
            //this is for 'text'
            fontSize: 16.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.normal),
        subtitle2: TextStyle(
            //this is for 'h3' markdown
            fontSize: 18.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.normal),
        headline1: TextStyle(
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
            color: MeditoColors.walterWhite,
            fontWeight: FontWeight.w400),
        bodyText1: TextStyle(
            //for 'MORE DETAILS'
            fontSize: 14.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w600),
      ));
}

Widget getNetworkImageWidget(String url,
    {Color svgColor, double startHeight = 0.0}) {
  if (url == null) return null;
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

int getColorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF" + hexColor;
  }
  return int.parse(hexColor, radix: 16);
}

Color parseColor(String color) {
  if (color == null || color.length == 0) return MeditoColors.midnight;

  return Color(int.parse(color?.replaceFirst('#', ''), radix: 16));
}

void createSnackBar(String message, BuildContext context) {
  final snackBar =
      new SnackBar(content: new Text(message), backgroundColor: Colors.red);

  // Find the Scaffold in the Widget tree and use it to show a SnackBar!
  Scaffold.of(context).showSnackBar(snackBar);
}

void createSnackBarWithColor(String message, BuildContext context, Color color) {
  final snackBar =
  new SnackBar(content: new Text(message), backgroundColor: color);

  // Find the Scaffold in the Widget tree and use it to show a SnackBar!
  Scaffold.of(context).showSnackBar(snackBar);
}

bool isDayBefore(DateTime day1, DateTime day2) {
  return day1.year == day2.year &&
      day1.month == day2.month &&
      day1.day == day2.day - 1;
}

MarkdownBody getMarkdownBody(String content, BuildContext context) {
  return MarkdownBody(
    onTapLink: ((url) {
      launch(url);
    }),
    selectable: false,
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        a: Theme.of(context)
            .textTheme
            .bodyText2
            .copyWith(decoration: TextDecoration.underline),
        h1: Theme.of(context).textTheme.headline6,
        h2: Theme.of(context).textTheme.headline5,
        h3: Theme.of(context).textTheme.subtitle2,
        listBullet: Theme.of(context).textTheme.subtitle1,
        p: Theme.of(context).textTheme.bodyText2.copyWith(height: 1.5)),
    data: content == null ? '' : content,
    imageDirectory: 'https://raw.githubusercontent.com',
  );
}

MarkdownBody getDescriptionMarkdownBody(String content, BuildContext context) {
  return MarkdownBody(
    onTapLink: ((url) {
      launch(url);
    }),
    selectable: false,
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        a: Theme.of(context)
            .textTheme
            .bodyText2
            .copyWith(decoration: TextDecoration.underline),
        h1: Theme.of(context).textTheme.headline6,
        h2: Theme.of(context).textTheme.headline5,
        h3: Theme.of(context).textTheme.subtitle2,
        listBullet: Theme.of(context).textTheme.subtitle1,
        p: Theme.of(context).textTheme.headline1.copyWith(
            fontSize: 16.0,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w500,
            color: MeditoColors.walterWhite.withOpacity(0.7),
            height: 1.5)),
    data: content == null ? '' : content,
    imageDirectory: 'https://raw.githubusercontent.com',
  );
}

launchUrl(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  }
}

Duration clockTimeToDuration(String lengthText) {
  var tempList = lengthText.split(":");
  var tempListInts = tempList.map(int.parse).toList();
  return Duration(
      hours: tempListInts[0],
      minutes: tempListInts[1],
      seconds: tempListInts[2]);
}