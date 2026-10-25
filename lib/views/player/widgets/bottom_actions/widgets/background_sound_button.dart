import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/background_sounds/background_sounds_notifier.dart';
import 'package:medito/providers/providers.dart';

import 'bg_sound_widget.dart';

/// Offers one quiet reminder on the second player visit with a sound or bells.
/// Owns the whole 48pt button so tapping the hint's target still opens the picker.
class BackgroundSoundButton extends ConsumerStatefulWidget {
  const BackgroundSoundButton({
    super.key,
    required this.isBackgroundSoundSelected,
    required this.onPressed,
  });

  final bool isBackgroundSoundSelected;
  final VoidCallback onPressed;

  @override
  ConsumerState<BackgroundSoundButton> createState() =>
      _BackgroundSoundButtonState();
}

class _BackgroundSoundButtonState extends ConsumerState<BackgroundSoundButton> {
  final _tooltipKey = GlobalKey<RawTooltipState>();
  final _arrowX = ValueNotifier<double>(0);
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _visitCounted = false;
  bool _openedPicker = false;
  bool _showHint = false;

  bool get _hasSound => ref.read(backgroundSoundsNotifierProvider).hasAnySound;

  @override
  void initState() {
    super.initState();
    // Listening also catches enabling a sound or bells during the first visit,
    // and restoring a saved choice after the native player has initialized.
    ref.listenManual(
      backgroundSoundsNotifierProvider.select((s) => s.hasAnySound),
      (_, _) => _recordVisit(),
      fireImmediately: true,
    );
  }

  void _recordVisit() {
    if (_visitCounted || !_hasSound) return;
    _visitCounted = true;
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(SharedPreferenceConstants.bgSoundChangeHintShown) ??
        false) {
      return;
    }
    final visits =
        ((prefs.getInt(SharedPreferenceConstants.bgSoundPlayerVisits) ?? 0) + 1)
            .clamp(0, 2);
    unawaited(
      prefs.setInt(SharedPreferenceConstants.bgSoundPlayerVisits, visits),
    );
    if (visits < 2) return;

    _showTimer = Timer(const Duration(milliseconds: 800), _tryShowHint);
  }

  void _tryShowHint() {
    if (!mounted || _openedPicker || !_hasSound) return;
    // Do not show over a sheet, another route, or while the app is backgrounded.
    // Leave it eligible for a later visit if this opportunity was interrupted.
    if (ModalRoute.of(context)?.isCurrent == false ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    setState(() => _showHint = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showHint) return;
      if (_tooltipKey.currentState?.ensureTooltipVisible() ?? false) {
        unawaited(
          ref
              .read(sharedPreferencesProvider)
              .setBool(SharedPreferenceConstants.bgSoundChangeHintShown, true),
        );
        // RawTooltip announces itself through SemanticsService.tooltip,
        // which only Android honours.
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          unawaited(
            SemanticsService.sendAnnouncement(
              View.of(context),
              AppLocalizations.of(context)!.changeBackgroundSoundsHint,
              Directionality.of(context),
            ),
          );
        }
        // Manually shown Flutter tooltips need an explicit timeout. Not with
        // a screen reader, which may still be finding its way to the bubble:
        // it stays until closed or tapped outside.
        if (!MediaQuery.accessibleNavigationOf(context)) {
          _hideTimer = Timer(const Duration(seconds: 6), _dismissHint);
        }
      }
    });
  }

  void _dismissHint() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _showHint = false);
  }

  void _onPressed() {
    _openedPicker = true;
    _showTimer?.cancel();
    _hideTimer?.cancel();
    setState(() => _showHint = false);
    widget.onPressed();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _arrowX.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final button = IconButton(
      tooltip: _showHint ? null : l10n.backgroundSounds,
      onPressed: _onPressed,
      icon: BgSoundWidget(
        isBackgroundSoundSelected: widget.isBackgroundSoundSelected,
      ),
    );
    if (!_showHint) return button;

    // The button's own tooltip is off while the hint shows, and a label
    // around an IconButton doesn't name it: merge the name, the hint
    // (RawTooltip's semantics tooltip) and the button into one node. The
    // bubble itself lives in the overlay, outside this merge.
    return MergeSemantics(
      child: RawTooltip(
        key: _tooltipKey,
        semanticsTooltip: l10n.changeBackgroundSoundsHint,
        triggerMode: TooltipTriggerMode.manual,
        // Keep the close button alive until the tap finishes. Outside taps
        // dismiss through TapRegion without interrupting the player's controls.
        enableTapToDismiss: false,
        positionDelegate: (position) {
          final offset = positionDependentBox(
            size: position.overlaySize,
            childSize: position.tooltipSize,
            target: position.target,
            verticalOffset: 32,
            preferBelow: false,
          );
          // Keep the bubble on screen, but let the arrow follow the button
          // when the bubble has to move away from a screen edge.
          final left = (position.target.dx - position.tooltipSize.width / 2)
              .clamp(
                0.0,
                position.overlaySize.width - position.tooltipSize.width,
              );
          _arrowX.value = position.target.dx - left - 12;
          return Offset(left, offset.dy);
        },
        tooltipBuilder: (context, animation) => FadeTransition(
          opacity: animation,
          child: TapRegion(
            onTapOutside: (_) => RawTooltip.dismissAllToolTips(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 252),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DecoratedBox(
                  decoration: _SoundHintDecoration(_arrowX),
                  child: Padding(
                    // Five extra pixels below the bubble reserve its arrow.
                    padding: const EdgeInsets.fromLTRB(12, 2, 0, 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.changeBackgroundSoundsHint,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFFF0F0F0),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: _dismissHint,
                          // Not "Close": the player's own Close is nearby.
                          tooltip: l10n.dismissTip,
                          icon: const Icon(Icons.close, size: 16),
                          color: ColorConstants.graphite,
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: Semantics(label: l10n.backgroundSounds, child: button),
      ),
    );
  }
}

class _SoundHintDecoration extends Decoration {
  const _SoundHintDecoration(this.arrowX);

  final ValueNotifier<double> arrowX;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _SoundHintPainter(arrowX, onChanged);
}

class _SoundHintPainter extends BoxPainter {
  _SoundHintPainter(this.arrowX, VoidCallback? onChanged) : super(onChanged) {
    if (onChanged != null) arrowX.addListener(onChanged);
  }

  final ValueNotifier<double> arrowX;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    final body = offset & Size(size.width, size.height - 5);
    final tipX = offset.dx + arrowX.value.clamp(20.0, size.width - 20);
    final arrow = Path()
      ..moveTo(tipX - 5, body.bottom)
      ..lineTo(tipX, body.bottom + 5)
      ..lineTo(tipX + 5, body.bottom)
      ..close();
    final outline = Path.combine(
      PathOperation.union,
      Path()
        ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(10))),
      arrow,
    );
    canvas.drawShadow(outline, Colors.black26, 2, true);
    canvas.drawPath(outline, Paint()..color = const Color(0xF5262626));
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0x24FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  @override
  void dispose() {
    if (onChanged != null) arrowX.removeListener(onChanged!);
    super.dispose();
  }
}
