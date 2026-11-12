import 'package:medito/constants/constants.dart';
import 'package:medito/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:medito/utils/utils.dart';

class MarkdownWidget extends StatelessWidget {
  const MarkdownWidget({
    super.key,
    required this.body,
    this.onTapLink,
    this.p,
    this.a,
    this.textAlign,
    this.selectable = false,
  });

  final String body;
  final void Function(String, String?, String)? onTapLink;
  final TextStyle? p, a;
  final WrapAlignment? textAlign;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    var walterWhite = ColorConstants.white.withOpacityValue(0.9);

    return Markdown(
      data: body,
      onTapLink: onTapLink ?? (text, href, title) => _linkTap(context, href),
      shrinkWrap: true,
      padding: const EdgeInsets.all(0),
      physics: const NeverScrollableScrollPhysics(),
      selectable: selectable,
      sizedImageBuilder: _image,
      styleSheet: buildMarkdownStyleSheet(context).copyWith(
        p: p ?? text.on(walterWhite).body,
        textAlign: textAlign ?? WrapAlignment.center,
        a:
            a ??
            text
                .on(walterWhite)
                .body
                .copyWith(decoration: TextDecoration.underline),
      ),
    );
  }

  /// Like the package's default for web images, but reads the alt text: the
  /// default left images nameless to screen readers. Only http(s) images are
  /// rendered; markdown here comes from the API, not local assets.
  Widget _image(MarkdownImageConfig config) {
    final uri = config.uri;
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return const SizedBox.shrink();
    }
    final alt = config.alt?.trim() ?? '';
    return Image.network(
      uri.toString(),
      width: config.width,
      height: config.height,
      semanticLabel: alt.isEmpty ? null : alt,
      // No alt text means decorative.
      excludeFromSemantics: alt.isEmpty,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  void _linkTap(BuildContext context, String? href) {
    handleNavigation(TypeConstants.url, [href], context);
  }
}
