import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/navigation_extra.dart';
import 'package:flutter/material.dart';

class CollapsibleHeaderComponent extends StatefulWidget {
  const CollapsibleHeaderComponent(
      {super.key,
      required this.children,
      required this.bgImage,
      required this.title,
      this.description});
  final List<Widget> children;
  final String bgImage;
  final String title;
  final String? description;
  @override
  State<CollapsibleHeaderComponent> createState() =>
      _CollapsibleHeaderComponentState();
}

class _CollapsibleHeaderComponentState
    extends State<CollapsibleHeaderComponent> {
  ScrollController? _scrollController;
  bool lastStatus = true;
  double height = 300;

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
        _scrollController!.offset > (height - kToolbarHeight - 50);
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
          leading: _leadingButton(),
          leadingWidth: 80,
          expandedHeight: height,
          floating: false,
          pinned: true,
          snap: false,
          elevation: 50,
          backgroundColor: ColorConstants.deepNight,
          centerTitle: false,
          flexibleSpace: FlexibleSpaceBar(
            title: _title(context),
            background: _bgImage(context),
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
      onPressed: () {
        router.pop();
      },
      isShowCircle: !_isShrink,
    );
  }

  Stack _bgImage(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          widget.bgImage,
          fit: BoxFit.fill,
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
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          description,
          style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
              color: ColorConstants.walterWhite, fontFamily: DmSans, height: 2),
        ),
      ),
    );
  }
}
