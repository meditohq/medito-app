import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class LabelsComponent extends StatelessWidget {
  const LabelsComponent({
    super.key,
    required this.label,
    this.onTap,
    this.bgColor = ColorConstants.greyIsTheNewGrey,
    this.textColor = ColorConstants.walterWhite,
  });
  final String label;
  final void Function()? onTap;
  final Color? bgColor;
  final Color? textColor;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.all(
              Radius.circular(3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: textColor, fontFamily: DmMono, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
