import 'package:freezed_annotation/freezed_annotation.dart';

import 'payment_config_model.dart';

part 'paywall_config_model.freezed.dart';
part 'paywall_config_model.g.dart';

/// Fully-resolved, localized paywall configuration returned by the donate-api
/// `GET /paywall` endpoint — the same JSON the paywall webview's inline JS
/// consumes. The native donation page is just another renderer of it.
///
/// `experiment.config` / `defaults.config` are free-form (admin-authored)
/// maps; the typed helpers below replicate the webview's resolution logic so
/// both renderers stay in sync. Unknown fields are ignored by parsing.
@freezed
abstract class PaywallConfigModel with _$PaywallConfigModel {
  const PaywallConfigModel._();

  const factory PaywallConfigModel({
    @Default('') String publishableKey,
    @Default('') String merchantIdentifier,
    @Default('Medito') String merchantName,
    @Default('US') String countryCode,
    @Default('usd') String currencyCode,
    @Default(<String>[]) List<String> supportedNetworks,
    required PaymentPricing pricing,
    String? email,
    PaywallExperiment? experiment,
    PaywallDefaults? defaults,
  }) = _PaywallConfigModel;

  factory PaywallConfigModel.fromJson(Map<String, Object?> json) =>
      _$PaywallConfigModelFromJson(json);

  /// Mirrors the webview JS: experiment config wins, else the server-saved
  /// default config, else null.
  Map<String, dynamic>? get effectiveConfig =>
      experiment?.config ?? defaults?.config;

  /// Server-driven flag gating the native (Dart) donation page.
  bool get nativePaywallEnabled => effectiveConfig?['nativePaywall'] == true;

  /// Per-source ladder override from the effective config's `sources` map
  /// (e.g. `sources.onboarding`), or null when absent.
  Map<String, dynamic>? sourceOverride(String? source) {
    if (source == null || source.isEmpty) return null;
    final sources = effectiveConfig?['sources'];
    if (sources is! Map) return null;
    final override = sources[source];
    return override is Map ? Map<String, dynamic>.from(override) : null;
  }

  /// Effective ladder for a frequency key ('oneTime' | 'monthly' | 'yearly'):
  /// source override, else resolved pricing.
  ///
  /// The top-level ladders in `experiment.config` / `defaults.config` are
  /// deliberately NOT read for amounts: the API returns them as raw base USD
  /// cents (only `config.sources[*]` and the `pricing` block are localized —
  /// the top-level override is folded into `pricing` server-side). The webview
  /// uses them only to gate which frequencies are offered; reading them here
  /// as amounts showed/charged raw cents in the local currency (e.g. ₹25
  /// instead of ₹2500) — below Stripe's minimum, so subscriptions activated
  /// with no PaymentIntent and no money collected.
  List<int> effectiveLadder(String freqKey, {String? source}) {
    return _intList(sourceOverride(source)?[freqKey]) ??
        _pricingLadder(freqKey);
  }

  /// Effective suggested ("Most popular") amount for a frequency key, with
  /// the same precedence as [effectiveLadder] (source override is localized
  /// server-side; the top-level config suggested is raw USD cents, so it is
  /// skipped — its value reaches us via the localized `pricing` block).
  int? effectiveSuggested(String freqKey, {String? source}) {
    final fromOverride = _suggestedIn(sourceOverride(source), freqKey);
    if (fromOverride != null) return fromOverride;
    return _pricingSuggested(freqKey);
  }

  /// Mirrors the webview's syncFrequencyTabs(): when the effective config (or
  /// its source override) declares any ladder, it is authoritative for which
  /// frequencies are offered — one it doesn't list is hidden even though the
  /// API fills in default pricing. A frequency with an empty effective ladder
  /// is always hidden.
  bool isFrequencyOffered(String freqKey, {String? source}) {
    const keys = ['oneTime', 'monthly', 'yearly'];
    final config = effectiveConfig;
    final override = sourceOverride(source);
    bool declared(String key) =>
        _intList(override?[key]) != null || _intList(config?[key]) != null;
    if (keys.any(declared) && !declared(freqKey)) return false;
    return effectiveLadder(freqKey, source: source).isNotEmpty;
  }

  /// Experiment-driven hero copy (A/B copy tests live in
  /// `experiment.config.heroCopy`, matching the webview which never reads
  /// hero copy from defaults). Values arrive as trusted HTML snippets; tags
  /// are stripped for native rendering (`<br>` becomes a newline).
  String? get heroEyebrow => _heroCopyValue('eyebrow');

  String? get heroHeading => _heroCopyValue('heading');

  String? get heroSubcopy => _heroCopyValue('subcopy');

  String? _heroCopyValue(String key) {
    final heroCopy = experiment?.config?['heroCopy'];
    if (heroCopy is! Map) return null;
    final value = heroCopy[key];
    return value is String ? _stripHtml(value) : null;
  }

  List<int> _pricingLadder(String freqKey) {
    switch (freqKey) {
      case 'oneTime':
        return pricing.oneTime;
      case 'monthly':
        return pricing.monthly;
      case 'yearly':
        return pricing.yearly;
      default:
        return const [];
    }
  }

  int? _pricingSuggested(String freqKey) {
    switch (freqKey) {
      case 'oneTime':
        return pricing.suggested.oneTime;
      case 'monthly':
        return pricing.suggested.monthly;
      case 'yearly':
        return pricing.suggested.yearly;
      default:
        return null;
    }
  }

  static int? _suggestedIn(Map<String, dynamic>? config, String freqKey) {
    final suggested = config?['suggested'];
    if (suggested is! Map) return null;
    final value = suggested[freqKey];
    return value is num ? value.toInt() : null;
  }

  static List<int>? _intList(dynamic value) {
    if (value is! List) return null;
    return value.whereType<num>().map((e) => e.toInt()).toList();
  }

  static String? _stripHtml(String value) {
    final text = value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .trim();
    return text.isEmpty ? null : text;
  }
}

@freezed
abstract class PaywallExperiment with _$PaywallExperiment {
  const factory PaywallExperiment({
    @Default('') String id,
    @Default('') String variant,
    Map<String, dynamic>? config,
  }) = _PaywallExperiment;

  factory PaywallExperiment.fromJson(Map<String, Object?> json) =>
      _$PaywallExperimentFromJson(json);
}

@freezed
abstract class PaywallDefaults with _$PaywallDefaults {
  const factory PaywallDefaults({Map<String, dynamic>? config}) =
      _PaywallDefaults;

  factory PaywallDefaults.fromJson(Map<String, Object?> json) =>
      _$PaywallDefaultsFromJson(json);
}
