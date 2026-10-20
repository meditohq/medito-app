import 'package:flutter/material.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/background_sounds/session_bell_pattern.dart';

/// The same three controls in timer setup and the player's sound sheet.
class SessionBellCheckboxes extends StatelessWidget {
  const SessionBellCheckboxes({
    super.key,
    required this.pattern,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final SessionBellPattern pattern;
  final void Function(SessionBellCue cue, bool selected) onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final cue in SessionBellCue.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              visualDensity: VisualDensity.compact,
              title: Text(switch (cue) {
                SessionBellCue.beginning => l10n.sessionBellBeginning,
                SessionBellCue.middle => l10n.sessionBellMiddle,
                SessionBellCue.end => l10n.sessionBellEnd,
              }),
              value: pattern.includes(cue),
              onChanged: (selected) {
                if (selected != null) onChanged(cue, selected);
              },
            ),
        ],
      ),
    );
  }
}
