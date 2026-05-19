import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/asset_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A selectable background palette for the quote share card.
///
/// Each palette ships its own gradient and matching foreground/secondary
/// colors so we don't have to compute contrast on the fly — the curated set
/// guarantees the quote stays readable on every background.
class _Palette {
  const _Palette({
    required this.name,
    required this.gradient,
    required this.foreground,
    required this.secondary,
    required this.lineColor,
  });

  final String name;
  final List<Color> gradient;
  final Color foreground;
  final Color secondary;
  final Color lineColor;

  /// All palettes share the same three-stop curve so the visual weight of
  /// the gradient feels consistent across choices.
  static const stops = <double>[0.0, 0.55, 1.0];

  /// The swatch shown in the picker — a small preview of the top-left
  /// gradient stop, which is the most visually distinctive color.
  Color get swatch => gradient.first;
}

const _palettes = <_Palette>[
  // Original — deep violet → navy → black.
  _Palette(
    name: 'Midnight',
    gradient: [Color(0xFF1E1040), Color(0xFF0E1028), Color(0xFF080810)],
    foreground: Colors.white,
    secondary: Color(0xCCFFFFFF),
    lineColor: Colors.white,
  ),
  _Palette(
    name: 'Indigo',
    gradient: [Color(0xFF1B2A6B), Color(0xFF111A45), Color(0xFF06091F)],
    foreground: Colors.white,
    secondary: Color(0xCCFFFFFF),
    lineColor: Colors.white,
  ),
  _Palette(
    name: 'Ocean',
    gradient: [Color(0xFF0F5C6E), Color(0xFF0A3A52), Color(0xFF06192C)],
    foreground: Colors.white,
    secondary: Color(0xCCFFFFFF),
    lineColor: Colors.white,
  ),
  _Palette(
    name: 'Forest',
    gradient: [Color(0xFF1F4D3A), Color(0xFF143226), Color(0xFF07150F)],
    foreground: Colors.white,
    secondary: Color(0xCCFFFFFF),
    lineColor: Colors.white,
  ),
  _Palette(
    name: 'Sunset',
    gradient: [Color(0xFFE76A5C), Color(0xFFB04A6E), Color(0xFF5B2A57)],
    foreground: Colors.white,
    secondary: Color(0xE6FFFFFF),
    lineColor: Colors.white,
  ),
  _Palette(
    name: 'Rose',
    gradient: [Color(0xFFF6CFD8), Color(0xFFE4A9B8), Color(0xFFB87592)],
    // Deep plum reads well on the soft rose without feeling harsh.
    foreground: Color(0xFF3A1E2A),
    secondary: Color(0xCC3A1E2A),
    lineColor: Color(0xFF3A1E2A),
  ),
  _Palette(
    name: 'Cream',
    gradient: [Color(0xFFFBF3E4), Color(0xFFEFE0C4), Color(0xFFD9C29A)],
    foreground: Color(0xFF2C2418),
    secondary: Color(0xCC2C2418),
    lineColor: Color(0xFF2C2418),
  ),
  _Palette(
    name: 'Slate',
    gradient: [Color(0xFF3A3A42), Color(0xFF24242B), Color(0xFF0F0F14)],
    foreground: Colors.white,
    secondary: Color(0xCCFFFFFF),
    lineColor: Colors.white,
  ),
];

class QuoteShareScreen extends ConsumerStatefulWidget {
  const QuoteShareScreen({super.key, required this.data});

  final HomeQuoteModel data;

  @override
  ConsumerState<QuoteShareScreen> createState() => _QuoteShareScreenState();
}

class _QuoteShareScreenState extends ConsumerState<QuoteShareScreen> {
  final _repaintKey = GlobalKey();
  final _shareButtonKey = GlobalKey();
  bool _sharing = false;
  int _paletteIndex = 0;

  Future<void> _share() async {
    setState(() => _sharing = true);
    // Log the share intent before the OS sheet appears — we can't observe
    // whether the user completes the share, so this captures the moment they
    // committed to it. Fire-and-forget so analytics never blocks the share.
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.quoteShared,
        parameters: {
          AnalyticsEventConstants.paramQuoteId: widget.data.id,
          AnalyticsEventConstants.paramQuoteAuthor: widget.data.author,
          AnalyticsEventConstants.paramQuoteSharePalette:
              _palettes[_paletteIndex].name,
        },
      ),
    );
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      // Target ~1080px output regardless of how large the card is rendered,
      // so iPads don't produce huge multi-MB PNGs.
      final logicalWidth = boundary.size.width;
      final pixelRatio = logicalWidth > 0
          ? (1080 / logicalWidth).clamp(1.0, 3.0)
          : 3.0;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/medito_quote.png');
      await file.writeAsBytes(bytes);

      // iPad requires a popover anchor — without it the share sheet
      // silently no-ops.
      final buttonBox =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = buttonBox != null
          ? buttonBox.localToGlobal(Offset.zero) & buttonBox.size
          : null;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[_paletteIndex];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      // Use the theme surface so light mode no longer renders on a near-black
      // scaffold (the old hardcoded #0E0E16).
      backgroundColor: scheme.surface,
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: _ShareCard(
                        data: widget.data,
                        palette: palette,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _PalettePicker(
                palettes: _palettes,
                selectedIndex: _paletteIndex,
                onSelected: (i) => setState(() => _paletteIndex = i),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: _shareButtonKey,
                  onPressed: _sharing ? null : _share,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.brandPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: padding16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _sharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Share',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalettePicker extends StatelessWidget {
  const _PalettePicker({
    required this.palettes,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Palette> palettes;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: palettes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final palette = palettes[i];
          final isSelected = i == selectedIndex;
          return _PaletteSwatch(
            palette: palette,
            selected: isSelected,
            ringColor: onSurface,
            onTap: () => onSelected(i),
          );
        },
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.palette,
    required this.selected,
    required this.ringColor,
    required this.onTap,
  });

  final _Palette palette;
  final bool selected;
  final Color ringColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.name} background',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.gradient,
              stops: _Palette.stops,
            ),
            border: Border.all(
              color: selected ? ringColor : ringColor.withValues(alpha: 0.15),
              width: selected ? 2.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: ringColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.data, required this.palette});

  final HomeQuoteModel data;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final seed = data.id.hashCode;
    return AspectRatio(
      aspectRatio: 1.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.gradient,
              stops: _Palette.stops,
            ),
          ),
          child: CustomPaint(
            painter: _FlowLinesPainter(seed: seed, color: palette.lineColor),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        AssetConstants.icLogo,
                        height: 36,
                        colorFilter: ColorFilter.mode(
                          palette.foreground,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'medito.app',
                        style: TextStyle(
                          fontSize: 14,
                          color: palette.secondary,
                          letterSpacing: 0.5,
                          fontFamily: dmSans,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    data.quote,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.55,
                      color: palette.foreground,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      fontFamily: sourceSerif,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '— ${data.author}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.secondary,
                      fontWeight: FontWeight.w400,
                      fontFamily: dmSans,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowLinesPainter extends CustomPainter {
  const _FlowLinesPainter({required this.seed, required this.color});

  final int seed;
  final Color color;

  double _fieldAngle(double x, double y, double freq, double baseAngle) {
    return baseAngle +
        math.sin(x * freq) * 1.2 +
        math.cos(y * freq * 0.7) * 0.8 +
        math.sin((x + y) * freq * 0.5) * 0.5;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);

    // Each card gets a different base flow direction and curvature frequency
    final baseAngle = rng.nextDouble() * math.pi * 2;
    final freq = 0.004 + rng.nextDouble() * 0.004;
    final stepLen = 3.5 + rng.nextDouble() * 2.0;
    const lineCount = 140;
    const stepsPerLine = 180;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (int i = 0; i < lineCount; i++) {
      // Spawn lines spread wider than the canvas so edges feel natural
      double x = rng.nextDouble() * size.width * 1.6 - size.width * 0.3;
      double y = rng.nextDouble() * size.height * 1.6 - size.height * 0.3;

      // Vary stroke width and opacity per line for depth
      final opacity = 0.04 + rng.nextDouble() * 0.07;
      final strokeWidth = 0.4 + rng.nextDouble() * 0.9;

      paint
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = strokeWidth;

      final path = Path()..moveTo(x, y);

      for (int s = 0; s < stepsPerLine; s++) {
        final angle = _fieldAngle(x, y, freq, baseAngle);
        x += math.cos(angle) * stepLen;
        y += math.sin(angle) * stepLen;
        path.lineTo(x, y);

        if (x < -40 || x > size.width + 40 ||
            y < -40 || y > size.height + 40) {
          break;
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowLinesPainter old) =>
      old.seed != seed || old.color != color;
}
