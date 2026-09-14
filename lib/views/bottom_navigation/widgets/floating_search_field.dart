import 'package:flutter/material.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/medito_icon.dart';

/// The text field shown inside the expanded nav capsule: search glyph, the
/// input, and a close button that collapses search.
class FloatingSearchField extends StatelessWidget {
  const FloatingSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

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
        IconButton(
          tooltip: l10n.close,
          onPressed: onClose,
          icon: Icon(Icons.close_rounded, color: onSurface),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
