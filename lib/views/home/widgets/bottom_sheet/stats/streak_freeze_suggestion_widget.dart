import 'package:flutter/material.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/models/local_all_stats.dart';

class StreakFreezeSuggestionWidget extends StatelessWidget {
  final LocalAllStats stats;
  final VoidCallback onUseFreeze;

  const StreakFreezeSuggestionWidget({
    super.key,
    required this.stats,
    required this.onUseFreeze,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            StringConstants.streakAtRisk,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            (stats.streakFreezes ?? 0) > 1
                ? StringConstants.streakFreezesAvailable.replaceFirst('%d', stats.streakFreezes.toString())
                : StringConstants.streakFreezeAvailable,
            style: theme.textTheme.bodyLarge,
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(StringConstants.notNow),
              ),
              ElevatedButton(
                onPressed: () {
                  onUseFreeze();
                  Navigator.of(context).pop();
                },
                child: Text(StringConstants.useStreakFreeze),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 