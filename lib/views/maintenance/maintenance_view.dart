import 'package:medito/models/maintenance/maintenance_model.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/markdown_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/colors/color_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/constants/theme/medito_text.dart';

class MaintenanceView extends ConsumerStatefulWidget {
  const MaintenanceView({
    super.key,
    required this.maintenanceModel,
    this.onClose,
  });

  final MaintenanceModel maintenanceModel;
  final VoidCallback? onClose;

  @override
  ConsumerState createState() => _MaintenanceViewState();
}

class _MaintenanceViewState extends ConsumerState<MaintenanceView> {
  @override
  Widget build(BuildContext context) {
    var markDownTheme = context.text.on(ColorConstants.white).body;

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        // Heading without the 👋, which screen readers read
                        // out as "waving hand".
                        Semantics(
                          header: true,
                          label: AppLocalizations.of(context)!.heyLabel,
                          excludeSemantics: true,
                          child: Text(
                            AppLocalizations.of(context)!.hey,
                            style: context.text.on(Colors.white).headline,
                          ),
                        ),
                        const SizedBox(height: 12),
                        MarkdownWidget(
                          body: widget.maintenanceModel.message ?? '',
                          textAlign: WrapAlignment.start,
                          a: markDownTheme.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                          p: context.text.on(Colors.white70).body,
                        ),
                        const SizedBox(height: 24),
                        if (widget.maintenanceModel.ctaLabel != null &&
                            widget.maintenanceModel.ctaLabel!.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: onPressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorConstants.accentDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                widget.maintenanceModel.ctaLabel ?? '',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                tooltip: AppLocalizations.of(context)!.close,
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () {
                  if (widget.onClose != null) {
                    widget.onClose!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onPressed() {
    var url = widget.maintenanceModel.ctaUrl;
    if (url != null && url.isNotEmpty) {
      launchURLInBrowser(url);
    }
  }
}
