import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class BottomActionComponent extends StatelessWidget {
  const BottomActionComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final _speedList = ['X1', 'X1.25', 'X1.5', 'X2', 'X0.6'];
    var _currentSpeed = 'X1';
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomActionLabel(
            context,
            _currentSpeed,
            () => {},
          ),
          width8,
          _bottomActionLabel(
            context,
            'DONWLOAD',
            () => {},
          ),
          width8,
          // if (_hasBGSound())
          _bottomActionLabel(
            context,
            'SOUND',
            () => {},
          ),
          // if (_hasBGSound()) width8,
        ],
      ),
    );
  }

  Expanded _bottomActionLabel(
      BuildContext context, String label, void Function()? onTap) {
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
