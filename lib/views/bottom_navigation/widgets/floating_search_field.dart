import 'package:flutter/material.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/medito_icon.dart';

/// The text field shown inside the expanded nav capsule: search glyph, the
/// input, and a clear (x) glyph that only appears once there is text.
/// Leaving search is the separate Cancel capsule beside the field.
class FloatingSearchField extends StatelessWidget {
  const FloatingSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final onSurface = theme.colorScheme.onSurface;

    return Row(
      children: [
        const SizedBox(width: 18),
        MeditoIcon(assetName: MeditoIcons.search, color: onSurface, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              color: onSurface,
            ),
            decoration: InputDecoration.collapsed(
              hintText: l10n.searchMeditations,
              hintStyle: TextStyle(color: onSurface.withOpacityValue(0.55)),
            ),
            onChanged: onChanged,
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox(width: 18);
            return IconButton(
              tooltip: l10n.clearSearch,
              onPressed: onClear,
              iconSize: 20,
              icon: Icon(Icons.cancel, color: onSurface.withOpacityValue(0.5)),
            );
          },
        ),
      ],
    );
  }
}
