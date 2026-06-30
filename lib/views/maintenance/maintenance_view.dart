import 'package:medito/models/maintenance/maintenance_model.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/markdown_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/colors/color_constants.dart';
import 'package:medito/l10n/app_localizations.dart';

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
    var markDownTheme = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: ColorConstants.white,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    );

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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        AppLocalizations.of(context)!.hey,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      MarkdownWidget(
                        body: widget.maintenanceModel.message ?? '',
                        textAlign: WrapAlignment.start,
                        a: markDownTheme?.copyWith(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w700,
                        ),
                        p: markDownTheme?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (widget.maintenanceModel.ctaLabel != null &&
                          widget.maintenanceModel.ctaLabel!.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: onPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorConstants.lightPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(widget.maintenanceModel.ctaLabel ?? ''),
                          ),
                        ),
                    ],
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
