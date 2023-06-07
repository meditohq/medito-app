import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class HandleBarWidget extends StatelessWidget {
  const HandleBarWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: 44,
      decoration: BoxDecoration(
        color: ColorConstants.walterWhite,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
