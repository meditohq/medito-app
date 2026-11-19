import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/widgets/adaptive/adaptive_content.dart';
import 'package:medito/widgets/adaptive/adaptive_cover_split.dart';
import 'package:medito/widgets/shimmers/widgets/box_shimmer_widget.dart';
import 'package:flutter/material.dart';

/// Loading placeholder for the pack screen. [wide] mirrors its two-pane
/// layout: the cover fills the left pane and the rows fill the right.
class FolderShimmerWidget extends StatelessWidget {
  const FolderShimmerWidget({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (wide) return _buildWide(context);
    final size = MediaQuery.of(context).size;

    // One "Loading" stop instead of silence while the pack loads.
    return Semantics(
      container: true,
      label: AppLocalizations.of(context)!.loading,
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const BoxShimmerWidget(height: 380),
              height8,
              Column(
                children: List.generate(
                  5,
                  (index) => _shimmerList(context, size),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWide(BuildContext context) {
    return Semantics(
      container: true,
      label: AppLocalizations.of(context)!.loading,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BoxShimmerWidget(
                width: AdaptiveCoverSplit.coverWidth(constraints.maxWidth),
                height: double.infinity,
              ),
              Expanded(
                child: SafeArea(
                  left: false,
                  child: AdaptiveContent(
                    child: Builder(
                      builder: (context) => SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          children: List.generate(
                            8,
                            (index) => _shimmerList(
                              context,
                              MediaQuery.sizeOf(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Padding _shimmerList(BuildContext context, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        height: 100,
        width: size.width,
        color: Theme.of(context).colorScheme.surface,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: BoxShimmerWidget(height: 10, width: 300),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: BoxShimmerWidget(height: 10, width: 200),
            ),
          ],
        ),
      ),
    );
  }
}
