// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/views/settings/widgets/add_widget_sheet.dart';
import 'package:medito/views/settings/widgets/app_icon_tile.dart';
import 'package:medito/views/settings/widgets/theme_tile.dart';
import 'package:medito/views/settings/widgets/widget_option_tile.dart';
import 'package:medito/widgets/adaptive/adaptive_page_body.dart';
import 'package:medito/widgets/medito_icon.dart';

/// "Appearance" settings: how the app looks, as opposed to how a session
/// behaves. Theme, app icon, the home layout and the home screen widget, which
/// used to be four rows on the main Settings page.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  // `kIsWeb` guard lets the screen render in the web-based widget previewer,
  // where dart:io Platform throws.
  static final _canAddWidget =
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _addWidget(BuildContext context, WidgetRef ref) async {
    final analytics = ref.read(analyticsServiceProvider);
    if (Platform.isIOS) {
      unawaited(
        analytics.logEvent(
          name: AnalyticsEventConstants.homeWidgetInstructionsShown,
        ),
      );
      await showAddWidgetSheet(context);
      return;
    }
    try {
      final dialogShown = await MeditoWidgetManager().pinWidget('consistency');
      unawaited(
        analytics.logEvent(
          name: AnalyticsEventConstants.homeWidgetPinRequested,
          parameters: {
            AnalyticsEventConstants.paramWidgetType: 'consistency',
            'dialog_shown': dialogShown ? 'true' : 'false',
          },
        ),
      );
    } catch (e) {
      // Silently fail - Android system dialog handles user interaction
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final rows = <Widget>[
      ThemeTile(
        icon: Icon(Icons.contrast_rounded, color: onSurface),
        title: l10n.themeTitle,
      ),
      AppIconTile(
        icon: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: onSurface, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(3),
          child: SvgPicture.asset(
            AssetConstants.icLogo,
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(onSurface, BlendMode.srcIn),
          ),
        ),
        title: l10n.appIconTitle,
      ),
      RowItemWidget(
        icon: MeditoIcon(assetName: MeditoIcons.pencil, color: onSurface),
        title: l10n.customiseHomeLayout,
        hasUnderline: _canAddWidget,
        onTap: () => handleNavigation(
          TypeConstants.route,
          [
            TypeConstants.customiseHomeLayout.getIdFromPath(),
            TypeConstants.customiseHomeLayout,
          ],
          context,
          ref: ref,
        ),
      ),
      if (_canAddWidget)
        WidgetOptionTile(
          icon: MeditoIcon(assetName: MeditoIcons.home, color: onSurface),
          title: l10n.addHomeScreenWidget,
          hasUnderline: false,
          onTap: () => _addWidget(context, ref),
        ),
    ];

    return Scaffold(
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: AdaptivePageBody(
        maxWidth: 760,
        child: SafeArea(
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
                title: HomeHeaderWidget(greeting: l10n.appearance),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(padding16),
                sliver: SliverToBoxAdapter(
                  child: HomeGradientBorder(
                    backgroundColor: Theme.of(context).cardColor,
                    borderRadius: 14,
                    borderWidth: 0.5,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(children: rows),
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
}
