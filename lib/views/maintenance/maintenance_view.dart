import 'package:medito/models/maintenance/maintenance_model.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/markdown_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/colors/color_constants.dart';
import '../../constants/strings/string_constants.dart';
import '../../constants/styles/widget_styles.dart';

class MaintenanceView extends ConsumerStatefulWidget {
  const MaintenanceView({super.key, required this.maintenanceModel});

  final MaintenanceModel maintenanceModel;

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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
            ),
            Text(
              StringConstants.hey,
              style: TextStyle(
                fontFamily: SourceSerif,
                fontSize: 28,
                color: ColorConstants.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              height: 12,
            ),
            MarkdownWidget(
              body: widget.maintenanceModel.message ?? '',
              textAlign: WrapAlignment.start,
              a: markDownTheme?.copyWith(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w700,
              ),
              p: markDownTheme?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(
              height: 24,
            ),
            SizedBox(
              width: double.infinity,
              child: MaterialButton(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: onPressed,
                color: ColorConstants.white,
                splashColor: ColorConstants.transparent,
                padding: EdgeInsets.symmetric(
                  vertical: padding14,
                  horizontal: padding16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      widget.maintenanceModel.ctaLabel ?? '',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontFamily: SourceSerif,
                            fontSize: 20,
                            color: ColorConstants.ebony,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onPressed() {
    var url = widget.maintenanceModel.ctaUrl;
    if (url.isNotNullAndNotEmpty()) {
      launchURLInBrowser(url!);
    }
  }
}
