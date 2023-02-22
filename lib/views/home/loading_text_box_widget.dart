import 'package:Medito/constants/constants.dart';
import 'package:flutter/cupertino.dart';

class LoadingTextBoxWidget extends StatelessWidget {
  final double? height;

  LoadingTextBoxWidget({this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: Container(
            child: Container(
          color: ColorConstants.moonlight,
          height: height,
        )));
  }
}
