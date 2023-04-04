import 'package:Medito/components/components.dart';
import 'package:flutter/material.dart';

class OverlayCoverImageComponent extends StatelessWidget {
  const OverlayCoverImageComponent({super.key, required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    const divisor = 2.1;
    final coverImageHeight = MediaQuery.of(context).size.height / divisor;

    return Container(
      height: coverImageHeight,
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: NetworkImageComponent(url: imageUrl),
    );
  }
}
