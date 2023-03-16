import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class LabelsComponent extends StatelessWidget {
  const LabelsComponent({
    super.key,
    required this.label,
    this.onTap,
  });
  final String label;
  final void Function()? onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: ColorConstants.greyIsTheNewGrey,
            borderRadius: BorderRadius.all(
              Radius.circular(3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColorConstants.walterWhite,
                fontFamily: DmMono,
                fontSize: 14),
          ),
        ),
      ),
    );
  }
}
