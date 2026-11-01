import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medito/l10n/app_localizations.dart';

enum SessionAction { open, edit, delete }

Future<SessionAction?> showSessionActionsSheet(
  BuildContext context, {
  required String title,
  required DateTime date,
  required bool canOpen,
}) => showModalBottomSheet<SessionAction>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: Theme.of(context).cardColor,
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(
              '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date)} · ${TimeOfDay.fromDateTime(date).format(context)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (canOpen)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline),
                title: Text(l10n.openSession),
                onTap: () => Navigator.pop(context, SessionAction.open),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.editSessionDateTime),
              onTap: () => Navigator.pop(context, SessionAction.edit),
            ),
            Divider(
              height: 24,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.deleteSessionTitle,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, SessionAction.delete),
            ),
          ],
        ),
      ),
    );
  },
);
