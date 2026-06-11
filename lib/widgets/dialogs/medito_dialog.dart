import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/utils/utils.dart';

/// Consistent dialog shell used across the app.
///
/// Renders a [Dialog] with the standard Medito container: surface background,
/// 16px rounded corners, 24px padding, capped at 400px wide.
///
/// Use [title] / [content] / [actions] for the common AlertDialog-like layout,
/// or pass [child] for a fully custom body. A custom [child] is wrapped in a
/// scroll view, so it must not contain vertically flexed widgets (Expanded/
/// Flexible in a Column) and scrolls instead of overflowing when the keyboard
/// shrinks the available height — overflowing buttons paint outside the
/// dialog's bounds where taps land on the dismiss barrier.
class MeditoDialog extends StatelessWidget {
  final String? title;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? child;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;

  const MeditoDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.child,
    this.maxWidth = 400,
    this.maxHeight,
    this.padding = const EdgeInsets.all(24),
  }) : assert(
          child != null || title != null || content != null,
          'Provide either child or title/content',
        );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? double.infinity,
        ),
        padding: padding,
        child: child != null
            ? SingleChildScrollView(child: child)
            : _buildStructured(context),
      ),
    );
  }

  Widget _buildStructured(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          MeditoDialogTitle(title!),
          const SizedBox(height: 12),
        ],
        if (content != null) ...[
          Flexible(child: content!),
          const SizedBox(height: 24),
        ],
        if (actions != null && actions!.isNotEmpty)
          _MeditoDialogActions(actions: actions!),
      ],
    );
  }
}

/// Arranges dialog actions. Stacks vertically when there are 3+ actions or
/// when combined button labels would overflow a single row; otherwise lays
/// them out horizontally with the primary action on the right.
class _MeditoDialogActions extends StatelessWidget {
  final List<Widget> actions;

  const _MeditoDialogActions({required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.length >= 3) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            actions[i],
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

/// Standard dialog title typography.
class MeditoDialogTitle extends StatelessWidget {
  final String text;

  const MeditoDialogTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: dmSans,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}

/// Standard dialog body text.
class MeditoDialogBody extends StatelessWidget {
  final String text;

  const MeditoDialogBody(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: dmSans,
            height: 1.5,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacityValue(0.75),
          ),
    );
  }
}
