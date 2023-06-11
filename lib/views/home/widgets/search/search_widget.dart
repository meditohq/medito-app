import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SearchWidget extends StatelessWidget {
  const SearchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    var outlineInputBorder = _outlineInputBorder();

    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 20),
      child: TextFormField(
        textAlign: TextAlign.center,
        cursorColor: ColorConstants.walterWhite,
        cursorWidth: 1,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(0),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 15.0),
            child: SvgPicture.asset(
              AssetConstants.icSearch,
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 0),
          suffixIcon: SvgPicture.asset(
            AssetConstants.icSearch,
            color: ColorConstants.onyx,
          ),
          hintText: StringConstants.search,
          hintStyle: textTheme.titleSmall,
          enabledBorder: outlineInputBorder,
          focusedBorder: outlineInputBorder,
          border: outlineInputBorder,
        ),
        style: textTheme.bodyMedium?.copyWith(
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
          fontSize: 16,
        ),
        onChanged: (val) => {},
      ),
    );
  }

  OutlineInputBorder _outlineInputBorder({
    Color color = ColorConstants.onyx,
  }) =>
      OutlineInputBorder(
        borderSide: BorderSide(color: color, width: 0),
        borderRadius: BorderRadius.circular(15),
      );
}
