import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Product photos are signed imgproxy URLs at up to 2048px tall; the size is
/// part of the signature, so we can't ask for a smaller one. Decode at the
/// rendered size instead to keep a grid of them light in memory.
///
/// Decorative to screen readers, like NetworkImageWidget: a nameless
/// "image" stop told them nothing. Callers carry the product name.
class ShopPhoto extends StatelessWidget {
  const ShopPhoto({super.key, required this.url, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: _photo(context));

  Widget _photo(BuildContext context) {
    final placeholderColor = Theme.of(context).colorScheme.surface;
    final url = this.url;
    if (url == null || url.isEmpty) return _fallback(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).round()
            : null;
        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
          memCacheWidth: width,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, _) => ColoredBox(color: placeholderColor),
          errorWidget: (context, _, _) => _fallback(context),
        );
      },
    );
  }

  Widget _fallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    ),
  );
}
