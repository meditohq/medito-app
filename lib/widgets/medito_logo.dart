import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// @params [onDoubleTap] function that will be executed
/// when the Medito logo is double tapped
class MeditoLogo extends StatelessWidget {
  final Function onDoubleTap;

  const MeditoLogo({
    Key key,
    @required this.onDoubleTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => onDoubleTap,
      child: Padding(
        padding: const EdgeInsets.all(19.0),
        child: SvgPicture.asset(
          'assets/images/icon_ic_logo.svg',
        ),
      ),
    );
  }
}
