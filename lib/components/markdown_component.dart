import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/navigation_extra.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

class MarkdownComponent extends StatelessWidget {
  const MarkdownComponent(
      {super.key,
      required this.body,
      this.onTapLink,
      this.p,
      this.a,
      this.textAlign});
  final String body;
  final void Function(String, String?, String)? onTapLink;
  final TextStyle? p, a;
  final WrapAlignment? textAlign;
  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: body,
      onTapLink: (text, href, title) => _linkTap(context, href),
      shrinkWrap: true,
      padding: const EdgeInsets.all(0),
      styleSheet: buildMarkdownStyleSheet(context).copyWith(
        p: p ??
            Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: DmMono,
                  letterSpacing: 1,
                  color: ColorConstants.walterWhite.withOpacity(0.9),
                ),
        textAlign: textAlign ?? WrapAlignment.center,
        a: a ??
            Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: DmMono,
                color: ColorConstants.walterWhite.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600),
      ),
    );
  }

  void _linkTap(BuildContext context, String? href) {
    var location = GoRouter.of(context).location;
    context.go(location + webviewPath, extra: {'url': href});
  }
}
