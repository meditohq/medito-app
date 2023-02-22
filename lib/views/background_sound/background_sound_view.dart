import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/view_model/background_sounds/background_sounds_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class BackgroundSoundView extends ConsumerWidget {
  const BackgroundSoundView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var backgroundSounds = ref.watch(backgroundSoundsProvider);
    return Scaffold(
      body: backgroundSounds.when(
        skipLoadingOnRefresh: false,
        data: (data) => _mainContent(context, data, ref),
        error: (err, stack) => ErrorComponent(
          message: err.toString(),
          onTap: () async => await ref.refresh(backgroundSoundsProvider),
        ),
        loading: () => BackgroundSoundsShimmerComponent(),
      ),
    );
  }

  CollapsibleHeaderComponent _mainContent(
      BuildContext context, List<BackgroundSoundsModel> data, WidgetRef ref) {
    return CollapsibleHeaderComponent(
      title: StringConstants.BACKGROUND_SOUNDS,
      leadingIconBgColor: ColorConstants.walterWhite,
      leadingIconColor: ColorConstants.almostBlack,
      headerHeight: 130,
      children: [
        // _volumeSlider(),
        TestClassForSlider(),
        for (int i = 0; i < data.length; i++)
          _buildSoundsListTile(context, data[i])
      ],
    );
  }

  SliderTheme _volumeSlider() {
    return SliderTheme(
      data: SliderThemeData(
          trackShape: CustomTrackShape(currentValue: '', addTopPadding: false),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 0.0),
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0.0),
          trackHeight: 72),
      child: Slider(
        value: 20,
        min: 0,
        max: 100,
        divisions: 10,
        activeColor: ColorConstants.purple,
        inactiveColor: ColorConstants.greyIsTheNewGrey,
        label: 'Set volume value',
        onChanged: (double newValue) {},
        semanticFormatterCallback: (double newValue) {
          return '${newValue.round()} ';
        },
      ),
    );
  }

  Container _buildSoundsListTile(
      BuildContext context, BackgroundSoundsModel sounds) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(width: 0.9, color: ColorConstants.softGrey),
        ),
      ),
      constraints: BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            sounds.name,
            style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                  color: ColorConstants.walterWhite,
                  fontFamily: DmSans,
                  fontSize: 16,
                ),
          ),
        ],
      ),
    );
  }
}

class TestClassForSlider extends StatefulWidget {
  const TestClassForSlider({super.key});

  @override
  State<TestClassForSlider> createState() => _TestClassForSliderState();
}

class _TestClassForSliderState extends State<TestClassForSlider> {
  double currentValue = 0;
  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
          trackShape: CustomTrackShape(
              currentValue: currentValue.toString(), addTopPadding: false),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 0.0),
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0.0),
          trackHeight: 72),
      child: Slider(
        value: currentValue,
        min: 0,
        max: 100,
        divisions: 100,

        activeColor: ColorConstants.purple,
        inactiveColor: ColorConstants.greyIsTheNewGrey,
        onChanged: (double newValue) {
          setState(() {
            currentValue = newValue;
          });
        },
        semanticFormatterCallback: (double newValue) {
          return '${newValue.round()} ';
        },
      ),
    );
  }
}

class CustomTrackShape extends RectangularSliderTrackShape {
  CustomTrackShape({required this.currentValue, this.addTopPadding = true});
  final String currentValue;
  final addTopPadding;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final trackLeft = offset.dx;
    var trackTop;
    if (addTopPadding) {
      trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2 + 12;
    } else {
      trackTop = parentBox.size.height - trackHeight;
    }
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset,
      {required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required Animation<double> enableAnimation,
      required TextDirection textDirection,
      required Offset thumbCenter,
      Offset? secondaryOffset,
      bool isDiscrete = false,
      bool isEnabled = false,
      double additionalActiveTrackHeight = 0}) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
    );
    final canvas = context.canvas;
    var span = TextSpan(
      style: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: ColorConstants.walterWhite, //Text Color of Value on Thumb
      ),
      text: 'Volume',
    );
    var tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    tp.layout();
    final xCenter = tp.width - 50;
    final yCenter = tp.height + 2;
    final offset1 = Offset(xCenter, yCenter);
    tp.paint(canvas, offset1);
    var span2 = TextSpan(
      style: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: ColorConstants.walterWhite, //Text Color of Value on Thumb
      ),
      text: currentValue.split('.').first+'%',
    );
    var tp2 = TextPainter(
        text: span2,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    tp2.layout();
    final offset2 = Offset(parentBox.size.width * 0.85, yCenter);
    tp2.paint(canvas, offset2);
  }
}
