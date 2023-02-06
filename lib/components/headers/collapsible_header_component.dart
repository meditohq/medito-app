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
          leading: leadingButton(),
          leadingWidth: 80,
          expandedHeight: height,
          floating: true,
          pinned: true,
          snap: true,
          elevation: 50,
          backgroundColor: MeditoColors.deepNight,
          centerTitle: false,
          flexibleSpace: FlexibleSpaceBar(
            title: title(context),
            background: bgImage(context),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            if (widget.description != null) description(widget.description!),
            ...widget.children
          ]),
        ),
      ],
    );
  }

  MaterialButton leadingButton() {
    return MaterialButton(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () {
        router.pop();
      },
      color: _isShrink ? null : Colors.black38,
      padding: EdgeInsets.all(16),
      shape: _isShrink ? null : CircleBorder(),
      child: Icon(
        Icons.close,
        color: Colors.white,
      ),
    );
  }

  Stack bgImage(BuildContext context) {
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
                  color: MeditoColors.almostBlack.withOpacity(0.6),
                  offset: Offset(0, 10),
                  blurRadius: 50,
                  spreadRadius: 50)
            ]),
          ),
        ),
      ],
    );
  }

  Row title(BuildContext context) {
    return Row(
      mainAxisAlignment:
          _isShrink ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _isShrink ? 50 : 15),
            child: Text(
              "${widget.title} title this is some random test",
              maxLines: _isShrink ? 1 : 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).primaryTextTheme.headline4?.copyWith(
                  fontFamily: ClashDisplay,
                  color: MeditoColors.walterWhite,
                  fontSize: _isShrink ? 20 : 24),
            ),
          ),
        ),
      ],
    );
  }

  Container description(String description) {
    return Container(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          description,
          style: Theme.of(context).primaryTextTheme.bodyText1?.copyWith(
              color: MeditoColors.walterWhite, fontFamily: DmSans, height: 2),
        ),
      ),
    );
  }
}
