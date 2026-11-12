import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';

class ImpactCard extends StatelessWidget {
  const ImpactCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorConstants.greyIsTheNewGrey.withAlpha(77),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.impactCardHelpMessage,
            style: context.text.on(Colors.white).subtitle,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.impactCardTestimonial,
            style: context.text.on(Colors.white70).bodySmall,
          ),
        ],
      ),
    );
  }
}
