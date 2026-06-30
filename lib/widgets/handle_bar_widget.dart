import 'package:flutter/material.dart';

class HandleBarWidget extends StatelessWidget {
  const HandleBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
