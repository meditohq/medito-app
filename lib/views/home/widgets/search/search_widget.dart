import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SearchWidget extends StatelessWidget {
  const SearchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 20),
      child: TextFormField(
        // textAlign: TextAlign.center,
        cursorColor: ColorConstants.walterWhite,
        cursorWidth: 1,
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10.0),
            child: SvgPicture.asset(
              AssetConstants.icSearch,
            ),
          ),
          hintText: StringConstants.search,
          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: ColorConstants.walterWhite,
                fontFamily: DmSans,
                fontSize: 16,
              ),
        ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ColorConstants.walterWhite,
              fontFamily: DmSans,
              fontSize: 16,
            ),
        onChanged: (val) => {},
      ),
    );
  }
}
