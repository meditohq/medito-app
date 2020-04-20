import 'dart:io';

import 'package:Medito/utils/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

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
  return GoogleFonts.dmSansTextTheme(Theme.of(context).textTheme.copyWith(
        title: TextStyle(
            fontSize: 22.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w600),
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
            fontSize: 14.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w400),
        body2: TextStyle(
            //for 'MORE DETAILS'
            fontSize: 14.0,
            height: 1.4,
            color: MeditoColors.lightColor,
            fontWeight: FontWeight.w800),
      ));
}

Widget getNetworkImageWidget(String url, {Color svgColor, double startHeight = 0.0}) {
  if (url.endsWith('png')) {
    return CachedNetworkImage(
      placeholder: (context, url) => Container(height: startHeight,),
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
