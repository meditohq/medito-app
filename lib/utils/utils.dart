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


launchUrl(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  }
  else {
    throw 'Could not launch $url';
  }
}


//todo can this be done a better way?
TextTheme buildDMSansTextTheme(BuildContext context) {
  return GoogleFonts.interTextTheme(Theme.of(context).textTheme.copyWith(
    //todo change to nondeprecated ones
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
            height: 1.25,
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
    styleSheet: MarkdownStyleSheet.fromTheme(
        Theme.of(context))
        .copyWith(
        a: Theme.of(context).textTheme.body1.copyWith(
            decoration: TextDecoration.underline),
        h1: Theme.of(context).textTheme.title,
        h2: Theme.of(context).textTheme.headline,
        h3: Theme.of(context).textTheme.subtitle,
        listBullet: Theme.of(context).textTheme.subhead,
        p: Theme.of(context).textTheme.body1),
    data: content == null ? '' : content,
    imageDirectory: 'https://raw.githubusercontent.com',
  );
}