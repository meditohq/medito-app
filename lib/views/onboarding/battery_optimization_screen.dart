import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/material.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/onboarding/onboarding_header_image.dart';

class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({super.key, this.headerImage, this.onNext});

  /// Hero image rendered at the top of the page, scrolling with the content.
  final String? headerImage;

  final VoidCallback? onNext;

  @override
  State<BatteryOptimizationScreen> createState() =>
      _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen>
    with WidgetsBindingObserver {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // When the user returns from system settings, advance automatically.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onNext?.call();
    }
  }

  Future<void> _handleOptimize() async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      // This opens the system dialog; the observer above will fire on return.
      await DisableBatteryOptimization.showDisableAllOptimizationsSettings(
        'Enable Auto Start',
        'Follow the steps and enable the auto start of this app',
        'Your device has additional battery optimization',
        'Follow the steps and disable the optimizations to allow smooth functioning of this app',
      );
    } catch (_) {
      // If the system dialog isn't available, just move on.
      if (mounted) widget.onNext?.call();
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerHeight = widget.headerImage != null
                ? OnboardingHeaderImage.heightFor(context)
                : 0.0;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.headerImage != null)
                    OnboardingHeaderImage(imagePath: widget.headerImage!),
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 64 - headerHeight)
                            .clamp(0.0, double.infinity),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              MeditoIcon(
                                assetName: MeditoIcons.alert,
                                size: 48,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                l10n.onboardingBatteryTitle,
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.onboardingBatteryBody,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontSize: 16, height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isProcessing
                                      ? null
                                      : _handleOptimize,
                                  child: Text(
                                    l10n.onboardingBatteryOptimize,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () => widget.onNext?.call(),
                                  child: Text(l10n.skipForNow),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// OEMs known for aggressive battery optimization.
const _affectedManufacturers = {
  'huawei',
  'xiaomi',
  'oneplus',
  'samsung',
  'meizu',
  'asus',
  'wiko',
  'lenovo',
  'oppo',
  'vivo',
  'realme',
  'motorola',
  'blackview',
  'tecno',
  'sony',
  'unihertz',
};

// Specific models to exclude even when their manufacturer is in the list above.
const _excludedModels = {
  'nexus 6p', // Huawei-built but stock Android
};

/// Returns true on devices from OEMs known for aggressive battery optimization
/// where optimization is NOT already disabled. Excludes known stock-Android
/// models (e.g. Nexus 6P) and Xiaomi Android One devices.
Future<bool> shouldShowBatteryOptimizationScreen() async {
  if (!Platform.isAndroid) return false;

  final info = await DeviceInfoPlugin().androidInfo;
  final manufacturer = info.manufacturer.toLowerCase();

  if (!_affectedManufacturers.any((m) => manufacturer.contains(m))) {
    return false;
  }

  // Xiaomi Android One devices run stock Android — skip them.
  if (manufacturer.contains('xiaomi') &&
      info.brand.toLowerCase().contains('android one')) {
    return false;
  }

  final model = info.model.toLowerCase();
  if (_excludedModels.any((m) => model.contains(m))) {
    return false;
  }

  final alreadyDisabled =
      await DisableBatteryOptimization.isAllBatteryOptimizationDisabled;
  return alreadyDisabled != true;
}
