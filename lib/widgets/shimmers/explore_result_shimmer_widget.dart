import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';

class ExploreResultShimmerWidget extends StatelessWidget {
  const ExploreResultShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(ColorConstants.white),
      ),
    );
  }
}
