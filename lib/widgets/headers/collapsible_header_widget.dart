import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollapsibleHeaderWidget extends ConsumerStatefulWidget {
  const CollapsibleHeaderWidget({
    super.key,
    required this.children,
    this.bgImage,
    required this.title,
    this.description,
    this.headerHeight = 300,
    this.leadingIconColor = ColorConstants.black,
    this.leadingIconBgColor = ColorConstants.walterWhite,
    this.onPressedCloseBtn,
    this.selectableTitle = false,
    this.selectableDescription = false,
  });
  final List<Widget> children;
  final String? bgImage;
  final String title;
  final String? description;
  final double headerHeight;
  final Color leadingIconColor;
  final Color leadingIconBgColor;
  final bool selectableTitle;
  final bool selectableDescription;
  final void Function()? onPressedCloseBtn;
  @override
  ConsumerState<CollapsibleHeaderWidget> createState() =>
      _CollapsibleHeaderWidgetState();
}

class _CollapsibleHeaderWidgetState
    extends ConsumerState<CollapsibleHeaderWidget> {
  ScrollController? _scrollController;
  bool lastStatus = true;

  void _scrollListener() {
    if (_isShrink != lastStatus) {
      setState(() {
        lastStatus = _isShrink;
      });
    }
  }

  bool get _isShrink {
    return _scrollController != null &&
        _scrollController!.hasClients &&
        _scrollController!.offset > (widget.headerHeight - kToolbarHeight - 50);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController?.removeListener(_scrollListener);
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentlyPlayingSession = ref.watch(playerProvider);

    return CustomScrollView(
      controller: _scrollController,
      physics: AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: <Widget>[
        SliverAppBar(
          leading: Padding(
            padding: EdgeInsets.only(top: _isShrink ? 0 : 12),
            child: _leadingButton(),
          ),
          leadingWidth: 80,
          expandedHeight: widget.headerHeight,
          floating: false,
          pinned: true,
          snap: false,
          elevation: 50,
          backgroundColor: ColorConstants.onyx,
          centerTitle: false,
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: false,
            expandedTitleScale: 1.2,
            titlePadding: EdgeInsets.only(
              bottom: 16,
              left: _isShrink ? 64 : 16,
              right: 16,
            ),
            title: _title(context),
            background: widget.bgImage != null
                ? _bgImage(context, widget.bgImage!)
                : Container(
                    height: 20,
                    color: ColorConstants.ebony,
                  ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            if (widget.description != null && widget.description!.isNotEmpty)
              _description(widget.description!),
            ...widget.children,
            SizedBox(
              height: currentlyPlayingSession != null ? 0 : 48,
            ),
          ]),
        ),
      ],
    );
  }

  CloseButtonWidget _leadingButton() {
    return CloseButtonWidget(
      bgColor: widget.leadingIconBgColor,
      icColor: _isShrink ? widget.leadingIconBgColor : widget.leadingIconColor,
      onPressed: widget.onPressedCloseBtn ??
          () {
            ref.read(goRouterProvider).pop();
          },
      isShowCircle: !_isShrink,
    );
  }

  Stack _bgImage(BuildContext context, String image) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NetworkImageWidget(
          url: image,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 80,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: ColorConstants.black.withOpacity(0.6),
                  offset: Offset(0, 10),
                  blurRadius: 50,
                  spreadRadius: 50,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Transform _title(BuildContext context) {
    var maxLines = _isShrink ? 1 : 3;
    const textScaleFactor = 1.0;
    const textAlign = TextAlign.left;
    var style = Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
          fontFamily: DmSerif,
          color: ColorConstants.walterWhite,
          fontSize: _isShrink ? 20 : 24,
        );

    return Transform(
      // you can forcefully translate values left side using Transform
      transform: Matrix4.translationValues(_isShrink ? 0 : 0.0, 0.0, 0.0),
      child: widget.selectableTitle
          ? SelectableText(
              '${widget.title}',
              maxLines: maxLines,
              minLines: 1,
              textScaleFactor: textScaleFactor,
              textAlign: textAlign,
              style: style,
            )
          : Text(
              '${widget.title}',
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textScaleFactor: textScaleFactor,
              textAlign: textAlign,
              style: style,
            ),
    );
  }

  Container _description(String description) {
    var bodyLarge = Theme.of(context).primaryTextTheme.bodyLarge;

    return Container(
      color: ColorConstants.onyx,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: MarkdownWidget(
          body: description,
          selectable: widget.selectableDescription,
          textAlign: WrapAlignment.start,
          p: bodyLarge?.copyWith(
            color: ColorConstants.walterWhite,
            fontFamily: DmSans,
            height: 1.5,
          ),
          a: bodyLarge?.copyWith(
            color: ColorConstants.walterWhite,
            fontFamily: DmSans,
            decoration: TextDecoration.underline,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
