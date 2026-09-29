import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/pack_sequence.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/scaffold_messenger_key.dart';
import 'package:medito/views/player/start_session.dart';
import 'package:medito/widgets/snackbar_widget.dart';

/// The pack's header surface with its play button sitting on the lower edge,
/// half over the header and half over the track list (Spotify-style). The
/// edge doubles as the pack's progress bar. On scroll, the pack screen docks
/// a second [PackPlayButton] under the app bar and hides this one via
/// [hideButton].
///
/// Packs that contain sub-packs and the favourites pseudo-pack get the plain
/// surface: Home walks a flat list of tracks.
class PackPathButton extends StatelessWidget {
  const PackPathButton({
    super.key,
    required this.pack,
    required this.child,
    this.buttonKey,
    this.hideButton = false,
    @visibleForTesting this.onStartSession = startSession,
  });

  final PackModel pack;

  /// The header content (description, tags) drawn on the card surface.
  final Widget child;

  /// Lets the pack screen find the inline button to know when to dock it.
  final GlobalKey? buttonKey;
  final bool hideButton;
  final StartSessionFn onStartSession;

  static const buttonSize = 56.0;
  static const rightInset = 16.0;
  static const _progressHeight = 3.0;

  /// How much of the header's bottom-right corner the button covers, measured
  /// from the content's usual 20px right padding: text there must make room.
  static const endReserve = rightInset + buttonSize + 8 - 20;

  /// Whether [pack] gets a play button at all.
  static bool isPlayable(PackModel pack) {
    final tracks = pack.items.where((i) => i.type == TypeConstants.track);
    return tracks.isNotEmpty &&
        tracks.length == pack.items.length &&
        pack.id != PackPlayButton._favoritesPackId;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    if (!isPlayable(pack)) {
      return ColoredBox(color: cardColor, child: child);
    }

    final completed = pack.items
        .where((item) => item.isCompleted == true)
        .length;
    const half = buttonSize / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The button's top half overlaps the last line of the header;
            // the header content keeps [endReserve] clear there.
            ColoredBox(color: cardColor, child: child),
            _progressEdge(context, completed, pack.items.length),
            // The button's lower half hangs over the list background; this
            // keeps it inside the Stack so the whole circle takes taps.
            const SizedBox(height: half - _progressHeight),
          ],
        ),
        Positioned(
          right: rightInset,
          bottom: 0,
          child: Visibility.maintain(
            visible: !hideButton,
            child: PackPlayButton(
              key: buttonKey,
              pack: pack,
              onStartSession: onStartSession,
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressEdge(BuildContext context, int completed, int total) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: _progressHeight,
      child: LinearProgressIndicator(
        value: total == 0 ? 0 : completed / total,
        backgroundColor: onSurface.withValues(alpha: 0.08),
        color: context.brandPurple,
      ),
    );
  }
}

typedef StartSessionFn =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref, {
      required String trackId,
      required String path,
    });

/// Plays the pack's next unfinished session and makes the pack the one Home
/// continues. Tapping a single track in the list only plays that track —
/// exploring never changes Home. Only this button does, so the snackbar says
/// so (with Undo) the first time a pack takes over Home. Removing lives on the
/// Home hero, where it shows.
class PackPlayButton extends ConsumerStatefulWidget {
  const PackPlayButton({
    super.key,
    required this.pack,
    this.onStartSession = startSession,
  });

  final PackModel pack;
  final StartSessionFn onStartSession;

  static const _favoritesPackId = 'favorites';

  @override
  ConsumerState<PackPlayButton> createState() => _PackPlayButtonState();
}

class _PackPlayButtonState extends ConsumerState<PackPlayButton> {
  bool _starting = false;

  PackModel get pack => widget.pack;

  @override
  Widget build(BuildContext context) {
    final completed = pack.items
        .where((item) => item.isCompleted == true)
        .length;
    // Same rule as upNextProvider, so this plays what Home would.
    final next = pack.items
        .where((item) => item.isCompleted != true)
        .firstOrNull;
    return _playButton(context, next, completed, pack.items.length);
  }

  Widget _playButton(
    BuildContext context,
    PackItemsModel? next,
    int completed,
    int total,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final done = next == null;
    final action = done
        ? l10n.yourPathAllDone
        : completed == 0
        ? l10n.packStart
        : l10n.packContinue;
    final label = done
        ? action
        : '$action: ${next.title}. ${l10n.upNextProgress(completed, total)}';

    return Semantics(
      button: !done,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: done ? action : '$action: ${next.title}',
        excludeFromSemantics: true,
        child: Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: done ? 0 : 3,
          color: done
              ? Color.alphaBlend(
                  onSurface.withValues(alpha: 0.08),
                  Theme.of(context).cardColor,
                )
              : context.brandPurple,
          child: InkWell(
            onTap: done ? null : () => _start(context, next),
            child: SizedBox.square(
              dimension: PackPathButton.buttonSize,
              child: Center(
                child: _starting
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: context.onBrandPurple,
                        ),
                      )
                    : Icon(
                        done ? Icons.check_rounded : Icons.play_arrow_rounded,
                        size: done ? 26 : 32,
                        color: done ? onSurface : context.onBrandPurple,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, PackItemsModel next) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await _putOnHome(context);
      if (!context.mounted) return;
      await widget.onStartSession(
        context,
        ref,
        trackId: next.id,
        path: next.path,
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Makes this pack the one Home continues. A no-op (and no snackbar) when it
  /// already is. Progress lives in stats, so replacing loses nothing.
  Future<void> _putOnHome(BuildContext context) async {
    final previousId = ref.read(upNextPackIdProvider);
    if (previousId == pack.id) return;

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.packPinned,
            parameters: {
              AnalyticsEventConstants.paramPackId: pack.id,
              AnalyticsEventConstants.paramPreviousPackId: previousId,
            },
          ),
    );

    final prefs = ref.read(sharedPreferencesProvider);
    // Null when Home was on the default pack without an explicit choice; Undo
    // restores exactly that.
    final previousRaw = prefs.getString(SharedPreferenceConstants.upNextPackId);
    // Container, not ref: Undo is usually tapped from the player.
    final container = ProviderScope.containerOf(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    // Remember where the user was in the series so removing this pack from
    // Home later returns there. Hopping between hand-picked packs keeps the
    // original series position.
    if (previousRaw == null) {
      await prefs.remove(SharedPreferenceConstants.upNextReturnPackId);
    } else if (PackSequence.contains(previousRaw)) {
      await prefs.setString(
        SharedPreferenceConstants.upNextReturnPackId,
        previousRaw,
      );
    }
    await prefs.setString(SharedPreferenceConstants.upNextPackId, pack.id);
    ref.invalidate(upNextPackIdProvider);

    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    showSnackBar(
      context.mounted ? context : null,
      l10n.packAddedToHome,
      actionLabel: l10n.undo,
      onActionPressed: () async {
        if (previousRaw == null) {
          await prefs.remove(SharedPreferenceConstants.upNextPackId);
        } else {
          await prefs.setString(
            SharedPreferenceConstants.upNextPackId,
            previousRaw,
          );
        }
        container.invalidate(upNextPackIdProvider);
      },
    );
  }
}
