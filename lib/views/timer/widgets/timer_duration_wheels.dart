import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';

/// Hours and minutes as two scroll wheels on cards, the Timer's main control.
/// Minutes loop, so 59 → 0 is one flick. Reports the total in minutes.
class TimerDurationWheels extends StatefulWidget {
  const TimerDurationWheels({
    super.key,
    required this.minutes,
    required this.onChanged,
  });

  static const height = 168.0;
  static const radius = 28.0;
  static const _itemExtent = 80.0;

  final int minutes;
  final ValueChanged<int> onChanged;

  static TextStyle digitStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.displayLarge!.copyWith(
      fontSize: 64,
      height: 1,
      fontWeight: FontWeight.w400,
      letterSpacing: -2,
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  @override
  State<TimerDurationWheels> createState() => TimerDurationWheelsState();
}

class TimerDurationWheelsState extends State<TimerDurationWheels> {
  late final FixedExtentScrollController _hours;
  late final FixedExtentScrollController _minutes;

  /// Set while a preset animates the wheels, so the ticks it passes through
  /// don't buzz or report intermediate lengths.
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _hours = FixedExtentScrollController(initialItem: widget.minutes ~/ 60);
    // Start the looping wheel mid-range so it can spin either way.
    _minutes = FixedExtentScrollController(
      initialItem: 60 * 100 + widget.minutes % 60,
    );
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  int get _selectedMinutes =>
      _hours.selectedItem * 60 + _minutes.selectedItem % 60;

  /// Spins both wheels to [minutes] (a preset chip was tapped).
  Future<void> animateTo(int minutes) async {
    if (!_hours.hasClients || !_minutes.hasClients) return;
    const duration = Duration(milliseconds: 450);
    const curve = Curves.easeOutCubic;
    final current = _minutes.selectedItem;
    var delta = (minutes % 60 - current % 60) % 60;
    if (delta > 30) delta -= 60;
    _animating = true;
    try {
      await Future.wait([
        _hours.animateToItem(minutes ~/ 60, duration: duration, curve: curve),
        _minutes.animateToItem(
          current + delta,
          duration: duration,
          curve: curve,
        ),
      ]);
    } finally {
      _animating = false;
    }
  }

  void _onWheelChanged() {
    if (_animating) return;
    unawaited(HapticFeedback.selectionClick());
    widget.onChanged(_selectedMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _Wheel(
            controller: _hours,
            label: l10n.timerHoursLabel,
            maxValue: kMaxTimerHours,
            onSelectedItemChanged: (_) => _onWheelChanged(),
            delegate: ListWheelChildBuilderDelegate(
              childCount: kMaxTimerHours + 1,
              builder: (context, index) => _Digits(index),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Wheel(
            controller: _minutes,
            label: l10n.timerMinutesLabel,
            loopLength: 60,
            onSelectedItemChanged: (_) => _onWheelChanged(),
            delegate: ListWheelChildLoopingListDelegate(
              children: [for (var i = 0; i < 60; i++) _Digits(i)],
            ),
          ),
        ),
      ],
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.label,
    required this.onSelectedItemChanged,
    required this.delegate,
    this.maxValue,
    this.loopLength,
  });

  final FixedExtentScrollController controller;
  final String label;
  final ValueChanged<int> onSelectedItemChanged;
  final ListWheelChildDelegate delegate;

  /// Highest item of a non-looping wheel.
  final int? maxValue;

  /// Items per turn of a looping wheel (its item index runs on past this).
  final int? loopLength;

  int get _item =>
      controller.hasClients ? controller.selectedItem : controller.initialItem;

  int _display(int item) => loopLength == null ? item : item % loopLength!;

  bool get _canIncrease => maxValue == null || _item < maxValue!;
  bool get _canDecrease => loopLength != null || _item > 0;

  void _step(int by) {
    if (!controller.hasClients) return;
    controller.animateToItem(
      _item + by,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The wheel's own semantics are a run of loose numbers ("04", "05",
    // "06") with nothing saying which is chosen or what they count. Expose it
    // as one adjustable control instead: "Minutes, 10", swipe up/down to step.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => Semantics(
        label: label,
        value: '${_display(_item)}',
        increasedValue: _canIncrease ? '${_display(_item + 1)}' : null,
        decreasedValue: _canDecrease ? '${_display(_item - 1)}' : null,
        onIncrease: _canIncrease ? () => _step(1) : null,
        onDecrease: _canDecrease ? () => _step(-1) : null,
        child: ExcludeSemantics(child: child),
      ),
      child: _buildWheel(context),
    );
  }

  Widget _buildWheel(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        HomeGradientBorder(
          backgroundColor: theme.cardColor,
          borderRadius: TimerDurationWheels.radius,
          borderWidth: 0.5,
          child: SizedBox(
            height: TimerDurationWheels.height,
            // Fade the neighbouring numbers out towards the card's edges.
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0, 0.3, 0.7, 1],
              ).createShader(rect),
              child: ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: TimerDurationWheels._itemExtent,
                physics: const FixedExtentScrollPhysics(),
                diameterRatio: 1.8,
                overAndUnderCenterOpacity: 0.35,
                onSelectedItemChanged: onSelectedItemChanged,
                childDelegate: delegate,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _Digits extends StatelessWidget {
  const _Digits(this.value);

  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        value.toString().padLeft(2, '0'),
        style: TimerDurationWheels.digitStyle(context),
      ),
    );
  }
}
