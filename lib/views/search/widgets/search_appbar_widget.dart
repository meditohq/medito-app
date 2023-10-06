import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchAppbarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  const SearchAppbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    var outlineInputBorder = _outlineInputBorder();

    return AppBar(
      backgroundColor: ColorConstants.onyx,
      elevation: 0.0,
      titleSpacing: 0,
      leading: IconButton(
        splashRadius: 20,
        onPressed: () => context.pop(),
        icon: Icon(Icons.arrow_back),
      ),
      title: TextFormField(
        cursorColor: ColorConstants.walterWhite,
        cursorWidth: 1,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(top: 11.5),
          suffixIcon: IconButton(
            splashRadius: 20,
            onPressed: () => {},
            icon: Icon(
              Icons.close,
              color: ColorConstants.walterWhite,
            ),
          ),
          hintText: StringConstants.whatAreYouLookingFor,
          hintStyle: textTheme.titleSmall
              ?.copyWith(color: ColorConstants.walterWhite.withOpacity(0.6)),
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          border: outlineInputBorder,
        ),
        style: textTheme.bodyMedium?.copyWith(
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
          fontSize: 16,
        ),
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

  @override
  Size get preferredSize => Size.fromHeight(56.0);
}
