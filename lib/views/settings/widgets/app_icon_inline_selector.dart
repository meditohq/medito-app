import 'dart:io';

import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/views/settings/widgets/app_icon_selection_dialog.dart';
import 'package:medito/widgets/snackbar_widget.dart';

class AppIconInlineSelector extends StatefulWidget {
  const AppIconInlineSelector({super.key});

  @override
  State<AppIconInlineSelector> createState() => AppIconInlineSelectorState();
}

class AppIconInlineSelectorState extends State<AppIconInlineSelector> {
  String? _currentIconName;
  late final ScrollController _scrollController;
  bool _showFade = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadCurrentIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atEnd =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 8;
    if (!atEnd != _showFade) {
      setState(() => _showFade = !atEnd);
    }
  }

  Future<void> _loadCurrentIcon() async {
    try {
      String? name;
      if (Platform.isAndroid) {
        name = await MeditoAppIconManager().getAlternateIconName();
      } else {
        name = await DynamicAppIconFlutterPlus.getAlternateIconName();
      }
      if (mounted) {
        setState(() => _currentIconName = name);
      }
    } catch (e, st) {
      AppLogger.e('AppIcon', 'Failed to load current icon', e, st);
    }
  }

  Future<void> _setIcon(AppIconOption option) async {
    try {
      final name = option.effectiveIconName;
      if (Platform.isAndroid) {
        await MeditoAppIconManager().setAlternateIconName(name);
        if (mounted) {
          setState(() => _currentIconName = name);
          showSnackBar(context, AppLocalizations.of(context)!.appIconChanged);
        }
        await Future.delayed(const Duration(seconds: 1));
        await SystemNavigator.pop();
      } else {
        await DynamicAppIconFlutterPlus.setAlternateIconName(name);
        if (mounted) {
          setState(() => _currentIconName = name);
        }
      }
    } catch (e, st) {
      AppLogger.e(
        'AppIcon',
        'Failed to set icon: ${option.effectiveIconName}',
        e,
        st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: HomeGradientBorder(
        backgroundColor: Theme.of(context).cardColor,
        borderRadius: 14,
        borderWidth: 0.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: SvgPicture.asset(
                      AssetConstants.icLogo,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  width16,
                  Text(
                    l10n.appIconTitle,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 92,
                child: Stack(
                  children: [
                    ListView.separated(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: AppIconOption.availableOptions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final option = AppIconOption.availableOptions[index];
                        final isSelected =
                            _currentIconName == option.effectiveIconName;

                        return _AppIconItem(
                          option: option,
                          isSelected: isSelected,
                          onTap: () => _setIcon(option),
                        );
                      },
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: -2,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _showFade ? 1.0 : 0.0,
                        child: IgnorePointer(
                          child: Container(
                            width: 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Theme.of(
                                    context,
                                  ).cardColor.withValues(alpha: 0),
                                  Theme.of(context).cardColor,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIconItem extends StatelessWidget {
  const _AppIconItem({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final AppIconOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: option.displayName(context),
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: ExcludeSemantics(
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppIconPreview(option: option, size: 56),
                    if (isSelected)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).cardColor,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  option.displayName(context),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
