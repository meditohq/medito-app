import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class SearchInitialPageWidget extends StatelessWidget {
  const SearchInitialPageWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PackCardWidget(
          title: 'UCLA',
          subTitle:
              'Guided meditations provided by UCLA Mindful Awareness Research Center.',
          coverUrlPath: 'https://images.medito.space/uGFBuXJ4ohNTzUy1.png',
        ),
        PackCardWidget(
          title: 'UCLA',
        ),
        PackCardWidget(
          title: 'UCLA',
          subTitle:
              'Guided meditations provided by UCLA Mindful Awareness Research Center.',
        ),
        PackCardWidget(
          title: 'UCLA',
          coverUrlPath: 'https://images.medito.space/uGFBuXJ4ohNTzUy1.png',
        ),
      ],
    );
  }
}
