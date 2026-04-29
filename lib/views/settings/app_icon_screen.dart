import 'dart:io';

import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/views/settings/widgets/app_icon_selection_dialog.dart';
import 'package:medito/widgets/snackbar_widget.dart';

class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  String? _currentIconName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentIcon();
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
        setState(() {
          _currentIconName = name;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      AppLogger.e('AppIcon', 'Failed to load current icon', e, st);
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      AppLogger.e('AppIcon', 'Failed to set icon: ${option.effectiveIconName}', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: CustomScrollView(
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
              title: HomeHeaderWidget(greeting: l10n.appIconTitle),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final option = AppIconOption.availableOptions[index];
                          final isSelected = _currentIconName == option.effectiveIconName;

                          return _AppIconGridItem(
                            option: option,
                            isSelected: isSelected,
                            onTap: () => _setIcon(option),
                          );
                        },
                        childCount: AppIconOption.availableOptions.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIconGridItem extends StatelessWidget {
  const _AppIconGridItem({
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppIconPreview(option: option, size: 72),
                  if (isSelected)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 14,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                option.displayName(context),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
