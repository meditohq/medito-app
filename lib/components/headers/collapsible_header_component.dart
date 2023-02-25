import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/routes/routes.dart';
import 'package:flutter/material.dart';

class CollapsibleHeaderComponent extends StatefulWidget {
  const CollapsibleHeaderComponent(
      {super.key,
      required this.children,
      this.bgImage,
      required this.title,
      this.description,
      this.headerHeight = 300,
      this.leadingIconColor = Colors.white,
      this.leadingIconBgColor = Colors.black38});
  final List<Widget> children;
  final String? bgImage;
  final String title;
  final String? description;
  final double headerHeight;
  final Color leadingIconColor;
  final Color leadingIconBgColor;
  @override
  State<CollapsibleHeaderComponent> createState() =>
      _CollapsibleHeaderComponentState();
}

class _CollapsibleHeaderComponentState
    extends State<CollapsibleHeaderComponent> {
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
    return CustomScrollView(
      controller: _scrollController,
      physics: AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverAppBar(
          leading: Padding(
            padding: const EdgeInsets.all(2.0),
            child: _leadingButton(),
          ),
          leadingWidth: 80,
          expandedHeight: widget.headerHeight,
          floating: false,
          pinned: true,
          snap: false,
          elevation: 50,
          backgroundColor: ColorConstants.deepNight,
          centerTitle: false,
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.2,
            title: _title(context),
            background: widget.bgImage != null
                ? _bgImage(context, widget.bgImage!)
                : Container(
                    height: 20,
                    color: ColorConstants.darkMoon,
                  ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            if (widget.description != null) _description(widget.description!),
            ...widget.children
          ]),
        ),
      ],
    );
  }

  CloseButtonComponent _leadingButton() {
    return CloseButtonComponent(
      bgColor: widget.leadingIconBgColor,
      icColor: widget.leadingIconColor,
      onPressed: () {
        router.pop();
      },
      isShowCircle: !_isShrink,
    );
  }

  Stack _bgImage(BuildContext context, String image) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image.asset(
        //   image,
        //   fit: BoxFit.fill,
        // ),
        NetworkImageComponent(
          url: image,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 80,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(boxShadow: [
              BoxShadow(
                  color: ColorConstants.almostBlack.withOpacity(0.6),
                  offset: Offset(0, 10),
                  blurRadius: 50,
                  spreadRadius: 50)
            ]),
          ),
        ),
      ],
    );
  }

  Transform _title(BuildContext context) {
    return Transform(
      // you can forcefully translate values left side using Transform
      transform: Matrix4.translationValues(_isShrink ? 0 : -40.0, 0.0, 0.0),
      child: Text(
        '${widget.title}',
        maxLines: _isShrink ? 1 : 3,
        overflow: TextOverflow.ellipsis,
        textScaleFactor: 1,
        textAlign: TextAlign.left,
        style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
            fontFamily: ClashDisplay,
            color: ColorConstants.walterWhite,
            fontSize: _isShrink ? 20 : 24),
      ),
    );
  }

  Container _description(String description) {
    return Container(
      color: ColorConstants.greyIsTheNewGrey,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: MarkdownComponent(
          body: description,
          textAlign: WrapAlignment.start,
          p: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
              color: ColorConstants.walterWhite,
              fontFamily: DmSans,
              height: 1.5),
          a: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
              color: ColorConstants.walterWhite,
              fontFamily: DmSans,
              decoration: TextDecoration.underline,
              height: 1.5),
        ),
      ),
    );
  }
}
