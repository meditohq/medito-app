import 'package:flutter/material.dart';
import 'package:medito/utils/utils.dart';

class BottomActions extends StatelessWidget {
  final String title;
  final String coverUrl;
  final List<Widget> actions;

  const BottomActions({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacityValue(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              coverUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
