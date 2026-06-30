import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class PackItemWidget extends StatelessWidget {
  const PackItemWidget({super.key, required this.item, this.onSetComplete});

  final PackItemsModel item;

  /// Persists a track row's completion to an absolute value, returning whether
  /// the write succeeded (so the control can revert an optimistic flip).
  /// When null (e.g. pack rows) no completion control is shown.
  final Future<bool> Function(bool complete)? onSetComplete;

  @override
  Widget build(BuildContext context) {
    var hasSubtitle = item.subtitle.isNotNullAndNotEmpty();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            padding: EdgeInsets.only(top: hasSubtitle ? 24 : 20, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.title.isNotNullAndNotEmpty())
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontFamily: dmSans, fontSize: 16),
                        ),
                      if (hasSubtitle)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.subtitle ?? '',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontFamily: dmMono,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _getTrailing(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getTrailing(BuildContext context) {
    if (item.type == TypeConstants.link) {
      return SvgPicture.asset(AssetConstants.icLink);
    }

    if (item.type == TypeConstants.track && onSetComplete != null) {
      return _CompletionToggle(
        isCompleted: item.isCompleted ?? false,
        onSetComplete: onSetComplete!,
      );
    }

    return const SizedBox();
  }
}

/// Tappable completion indicator that replaces the old swipe-to-complete
/// gesture (which fought the Android system back gesture on the right edge).
/// The generous left/vertical padding both keeps a comfortable gap from the
/// title and gives the control a ~48px touch target.
///
/// The flip is optimistic — the icon changes the instant you tap, well ahead
/// of the network write behind it. Because a user can tap repeatedly, a single
/// converger loop runs at a time: extra taps just update the desired state,
/// and when the in-flight write finishes the loop persists again if the user
/// has since changed their mind. A failed write reverts to the real state.
class _CompletionToggle extends StatefulWidget {
  const _CompletionToggle({
    required this.isCompleted,
    required this.onSetComplete,
  });

  final bool isCompleted;
  final Future<bool> Function(bool complete) onSetComplete;

  @override
  State<_CompletionToggle> createState() => _CompletionToggleState();
}

class _CompletionToggleState extends State<_CompletionToggle> {
  /// What the checkbox currently shows. Seeded from the provider and then
  /// driven optimistically; resynced from the provider only while idle.
  late bool _shown;

  /// True while the converger loop owns persistence. Guards against starting a
  /// second loop and against stale provider rebuilds clobbering the optimism.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _shown = widget.isCompleted;
  }

  @override
  void didUpdateWidget(_CompletionToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt provider-driven changes only when we're not mid-write, so an
    // in-flight optimistic flip isn't overwritten by a stale rebuild.
    if (!_busy && widget.isCompleted != _shown) {
      _shown = widget.isCompleted;
    }
  }

  Future<void> _handleTap() async {
    setState(() => _shown = !_shown); // optimistic flip, instant
    if (_busy) return; // a converger is already running; it will pick this up
    _busy = true;
    try {
      while (true) {
        final target = _shown;
        final ok = await widget.onSetComplete(target);
        if (!ok) {
          // Persist failed — fall back to the real (provider) state.
          if (mounted) setState(() => _shown = widget.isCompleted);
          break;
        }
        // No further taps during the write → settled. Otherwise loop to
        // converge on the user's newest choice.
        if (!mounted || _shown == target) break;
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      checked: _shown,
      label: _shown ? l10n.markTrackIncomplete : l10n.markTrackComplete,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        // 48x48 hit area (platform minimum) with a left gap from the title.
        // The circle is right-aligned within it so it stays visually where it
        // was while the touch target extends left and vertically.
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 24,
                height: 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _shown ? context.brandPurple : Colors.transparent,
                    border: Border.all(
                      color: _shown
                          ? context.brandPurple
                          : ColorConstants.graphite,
                      width: 2,
                    ),
                  ),
                  child: _shown
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: ColorConstants.white,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
