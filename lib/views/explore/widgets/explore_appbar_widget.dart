import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExploreAppbarWidget extends ConsumerStatefulWidget {
  const ExploreAppbarWidget({super.key});

  @override
  ConsumerState<ExploreAppbarWidget> createState() =>
      _ExploreAppbarWidgetState();
}

class _ExploreAppbarWidgetState extends ConsumerState<ExploreAppbarWidget> {
  bool showCancelIcon = false;
  FocusNode exploreInputFocusNode = FocusNode();
  var textEditingController = TextEditingController();

  @override
  void initState() {
    textEditingController.text =
        ref.read(exploreQueryProvider.notifier).state.query;
    showCancelIcon = textEditingController.text != '';
    super.initState();
  }

  void openKeyboard() {
    FocusScope.of(context).requestFocus(exploreInputFocusNode);
    setState(() {
      showCancelIcon = false;
    });
  }

  void handleCancelIconVisibility(String val) {
    ref.read(exploreQueryProvider.notifier).state = ExploreQueryModel(val);
    if (val.isNotEmpty && !showCancelIcon) {
      setState(() {
        showCancelIcon = true;
      });
    } else if (val.isEmpty && showCancelIcon) {
      setState(() {
        showCancelIcon = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    var outlineInputBorder = _outlineInputBorder();

    return AppBar(
      shadowColor: ColorConstants.ebony,
      surfaceTintColor: Colors.transparent,
      backgroundColor: ColorConstants.onyx,
      title: TextFormField(
        focusNode: exploreInputFocusNode,
        controller: textEditingController,
        cursorColor: ColorConstants.walterWhite,
        cursorWidth: 1,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(top: 11.5, left: padding12),
          suffixIcon: Visibility(
            visible: showCancelIcon,
            child: IconButton(
              splashRadius: 20,
              onPressed: () {
                ref.read(exploreQueryProvider.notifier).state =
                    ExploreQueryModel('');
                textEditingController.text = '';
                openKeyboard();
              },
              icon: Icon(
                Icons.close,
                color: ColorConstants.walterWhite,
              ),
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
        onFieldSubmitted: (val) {
          ref.read(exploreQueryProvider.notifier).state =
              ExploreQueryModel(val, hasExploreStarted: true);
          ref.invalidate(exploreProvider);
        },
        onChanged: (val) => handleCancelIconVisibility(val),
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
