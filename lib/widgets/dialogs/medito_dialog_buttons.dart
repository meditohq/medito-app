import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/utils/utils.dart';

const double _buttonHeight = 48;
const double _buttonRadius = 12;
const TextStyle _buttonTextStyle = TextStyle(
  fontFamily: dmSans,
  fontSize: 15,
  fontWeight: FontWeight.w600,
);

/// Filled primary action used in a Medito dialog. Defaults to the brand purple
/// but can be overridden (e.g. for destructive flows). Use
/// [MeditoDialogDestructiveButton] for the standard destructive styling.
class MeditoDialogPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const MeditoDialogPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.brandPurple;
    final fg = foregroundColor ?? Colors.white;

    return SizedBox(
      height: _buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withOpacityValue(0.5),
          disabledForegroundColor: fg.withOpacityValue(0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
          textStyle: _buttonTextStyle,
        ),
        child: isLoading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(fg),
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}

/// Outlined secondary action (e.g. Cancel) used in a Medito dialog.
class MeditoDialogSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const MeditoDialogSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      height: _buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: onSurface.withOpacityValue(0.3), width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
          textStyle: _buttonTextStyle,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Destructive primary action (e.g. Delete). Uses the theme error color.
class MeditoDialogDestructiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const MeditoDialogDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MeditoDialogPrimaryButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      backgroundColor: theme.colorScheme.error,
      foregroundColor: theme.colorScheme.onError,
    );
  }
}
