import 'package:Medito/components/components.dart';
import 'package:flutter/material.dart';

class OverlayCoverImageComponent extends StatelessWidget {
  const OverlayCoverImageComponent({super.key, required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height / 2.1,
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: NetworkImageComponent(url: imageUrl),
    );
  }
}
