import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/search/search_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchAppbarWidget extends ConsumerWidget implements PreferredSizeWidget {
  const SearchAppbarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var textTheme = Theme.of(context).textTheme;
    final textEditingController =
        TextEditingController(text: ref.read(searchQueryProvider));
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
        controller: textEditingController,
        cursorColor: ColorConstants.walterWhite,
        cursorWidth: 1,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(top: 11.5),
          suffixIcon: IconButton(
            splashRadius: 20,
            onPressed: () {
              ref.read(searchQueryProvider.notifier).state = '';
              textEditingController.text = '';
            },
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
        textInputAction: TextInputAction.search,
        style: textTheme.bodyMedium?.copyWith(
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
          fontSize: 16,
        ),
        autofocus: true,
        onFieldSubmitted: (val) {
          ref.read(searchQueryProvider.notifier).state = val;
        },
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
