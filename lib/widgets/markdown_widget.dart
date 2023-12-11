import 'package:Medito/constants/constants.dart';
import 'package:Medito/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownWidget extends StatelessWidget {
  const MarkdownWidget({
    super.key,
    required this.body,
    this.onTapLink,
    this.p,
    this.a,
    this.textAlign,
    this.pFontSize = 16,
    this.aFontSize = 13,
    this.selectable = false,
  });

  final String body;
  final void Function(String, String?, String)? onTapLink;
  final TextStyle? p, a;
  final WrapAlignment? textAlign;
  final double pFontSize;
  final double aFontSize;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    var titleMedium = Theme.of(context).textTheme.titleMedium;
    var walterWhite = ColorConstants.walterWhite.withOpacity(0.9);

    return Markdown(
      data: body,
      onTapLink: onTapLink ?? (text, href, title) => _linkTap(context, href),
      shrinkWrap: true,
      padding: const EdgeInsets.all(0),
      physics: NeverScrollableScrollPhysics(),
      selectable: selectable,
      styleSheet: buildMarkdownStyleSheet(context).copyWith(
        p: p ??
            titleMedium?.copyWith(
              fontFamily: DmMono,
              fontSize: pFontSize,
              letterSpacing: 0,
              color: walterWhite,
            ),
        textAlign: textAlign ?? WrapAlignment.center,
        a: a ??
            titleMedium?.copyWith(
              fontFamily: DmMono,
              color: walterWhite,
              fontSize: aFontSize,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  void _linkTap(BuildContext context, String? href) {
    handleNavigation(
      context: context,
      TypeConstants.url,
      [href],
    );
  }
}
