import 'package:flutter/material.dart';

class CustomMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double velocity; 
  final double blankSpace;

  CustomMarquee({
    required this.text,
    required this.style,
    this.velocity = 50.0,
    this.blankSpace = 40.0,
  });

  @override
  _CustomMarqueeState createState() => _CustomMarqueeState();
}

class _CustomMarqueeState extends State<CustomMarquee> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _startScrolling();
  }

  void _startScrolling() {
    _controller.animateTo(
      _controller.position.maxScrollExtent,
      duration: Duration(milliseconds: (widget.velocity / 0.1).toInt()),
      curve: Curves.linear,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(width: widget.blankSpace),
          Text(
            widget.text,
            style: widget.style,
          ),
          SizedBox(width: widget.blankSpace),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}