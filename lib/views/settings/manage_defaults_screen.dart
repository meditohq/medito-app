import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/snackbar_widget.dart' show showSnackBar;

class ManageDefaultsScreen extends ConsumerWidget {
  const ManageDefaultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(child: _buildMain(context, ref)),
    );
  }

  Widget _buildMain(BuildContext context, WidgetRef ref) {
    final guideName = ref.watch(guideNamePreferenceProvider);
    final duration = ref.watch(durationPreferenceProvider);
    final l10n = AppLocalizations.of(context)!;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          centerTitle: false,
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          toolbarHeight: 56.0,
          pinned: true,
          floating: true,
          elevation: 0.0,
          title: HomeHeaderWidget(
            greeting: l10n.manageDefaults,
          ),
        ),
        _buildContent(context, ref, guideName, duration, l10n),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    String? guideName,
    int? duration,
    AppLocalizations l10n,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: padding16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 0.7,
                            color: ColorConstants.onyx,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.face_outlined,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 24,
                          ),
                          width16,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.defaultGuideName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  guideName ?? l10n.notSet,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                        letterSpacing: 0,
                                        height: 1.7,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (guideName != null)
                            IconButton(
                              tooltip: l10n.clearDefault,
                              icon: const Icon(Icons.delete_outline),
                              color: Theme.of(context).colorScheme.onSurface,
                              onPressed: () {
                                ref
                                    .read(guideNamePreferenceProvider.notifier)
                                    .clearGuideName();
                                showSnackBar(
                                  context,
                                  l10n.defaultGuideNameCleared,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 0.7,
                            color: ColorConstants.onyx,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 24,
                              ),
                              width16,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.defaultDuration,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      duration != null
                                          ? '${duration ~/ 60000} ${l10n.min}'
                                          : l10n.notSet,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                            letterSpacing: 0,
                                            height: 1.7,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (duration != null) ...[
                            const SizedBox(height: 16.0),
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8.0,
                                ),
                              ),
                              child: Slider(
                                value: (duration / 60000).clamp(1, 60).toDouble(),
                                min: 1,
                                max: 60,
                                divisions: 59,
                                activeColor: context.brandPurple,
                                inactiveColor: ColorConstants.greyIsTheNewGrey,
                                onChanged: (double newValue) {
                                  ref
                                      .read(durationPreferenceProvider.notifier)
                                      .setDuration((newValue * 60000).round());
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '1 ${l10n.min}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                  ),
                                  Text(
                                    '60 ${l10n.min}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16.0,
                    ),
                    child: Text(
                      l10n.defaultsNote,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                            height: 1.5,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                ]),
      ),
    );
  }
}
