import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
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
    final availableCount = stats.streakFreezes ?? 0;
    final maxCount = stats.maxStreakFreezes ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            StringConstants.streakAtRisk,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: ColorConstants.white,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            StringConstants.streakFreezesAvailableMessage
                .replaceAll('{count}', availableCount.toString()),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: ColorConstants.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < maxCount; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      i < availableCount
                          ? HugeIcons.solidRoundedSnow
                          : HugeIcons.solidSharpCircle,
                      size: 50,
                      color: i < availableCount
                          ? ColorConstants.lightPurple
                          : theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: availableCount > 0
                      ? () {
                          onUseFreeze();
                          Navigator.of(context).pop();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorConstants.lightPurple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        theme.colorScheme.onSurface.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: Text(StringConstants.useStreakFreeze),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
