import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/strings/asset_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class QuoteShareScreen extends StatefulWidget {
  const QuoteShareScreen({super.key, required this.data});

  final HomeQuoteModel data;

  @override
  State<QuoteShareScreen> createState() => _QuoteShareScreenState();
}

class _QuoteShareScreenState extends State<QuoteShareScreen> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/medito_quote.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'image/png')]),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E16),
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
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: _ShareCard(data: widget.data),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
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

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.data});

  final HomeQuoteModel data;

  @override
  Widget build(BuildContext context) {
    final seed = data.id.hashCode;
    return AspectRatio(
      aspectRatio: 1.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E1040),
                Color(0xFF0E1028),
                Color(0xFF080810),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: _FlowLinesPainter(seed),
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
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'medito.app',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0x99FFFFFF),
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
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.55,
                      color: Colors.white,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      fontFamily: sourceSerif,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '\u2014 ${data.author}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xCCFFFFFF),
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
  final int seed;

  const _FlowLinesPainter(this.seed);

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
        ..color = Colors.white.withValues(alpha: opacity)
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
  bool shouldRepaint(covariant _FlowLinesPainter old) => old.seed != seed;
}
