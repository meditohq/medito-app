import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Marks a page the onboarding pager moved to (as opposed to the first page,
/// which opens with the route) so its [OnboardingStepTitle] announces itself.
class OnboardingStepAnnouncement extends InheritedWidget {
  const OnboardingStepAnnouncement({
    super.key,
    this.position,
    required super.child,
  });

  /// Read after the title, e.g. "Step 2 of 3"; null for unnumbered pages.
  final String? position;

  static OnboardingStepAnnouncement? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingStepAnnouncement>();

  @override
  bool updateShouldNotify(OnboardingStepAnnouncement oldWidget) =>
      position != oldWidget.position;
}

/// An onboarding page's title: a heading for screen readers, announced once
/// when the pager slides its page in. Paging isn't a route change, so without
/// this the button the user tapped just vanished and nothing was read.
class OnboardingStepTitle extends StatefulWidget {
  const OnboardingStepTitle(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<OnboardingStepTitle> createState() => _OnboardingStepTitleState();
}

class _OnboardingStepTitleState extends State<OnboardingStepTitle> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    final scope = OnboardingStepAnnouncement.maybeOf(context);
    if (scope == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = scope.position;
      SemanticsService.sendAnnouncement(
        View.of(context),
        position == null ? widget.text : '${widget.text}. $position',
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    );
  }
}
