import 'package:flutter/material.dart';

import '../colors/color_constants.dart';
import '../styles/widget_styles.dart';

/// Medito's type scale. Every piece of text in the app uses one of these nine
/// styles, read from the context:
///
/// ```dart
/// Text('Sleep', style: context.text.title)
/// Text('10 min · Sarah', style: context.text.muted.caption)
/// ```
///
/// Pick a style by the job the text does, not by how big you want it:
///
/// | Style       | Size / weight | Use for                                         |
/// |-------------|---------------|-------------------------------------------------|
/// | `hero`      | 48 / 700      | One big number or word that owns the screen     |
/// | `display`   | 32 / 700      | Key figures, splash and celebration headlines   |
/// | `headline`  | 24 / 700      | The title of a screen, or the question it asks  |
/// | `title`     | 20 / 600      | Section headers, sheet and dialog titles        |
/// | `subtitle`  | 16 / 600      | Card and row titles, buttons, emphasised body   |
/// | `body`      | 16 / 400      | Anything meant to be read: descriptions, copy   |
/// | `bodySmall` | 14 / 400      | Supporting text under a title, helper text      |
/// | `label`     | 14 / 500      | Short UI labels: chips, tabs, compact buttons   |
/// | `caption`   | 12 / 500      | Metadata: durations, dates, tags, fine print    |
///
/// Weight follows the role: reading text is 400, small UI labels 500,
/// headings 600, display sizes 700. Don't override `fontSize` or `fontWeight`
/// at the call site; if nothing fits, the design is asking for a tenth style
/// and that belongs here.
///
/// Styles come in the theme's primary text colour. `muted` gives the same
/// scale in the secondary colour for less important text, `on(color)` gives it
/// in any colour (on an image, an error), and `inherited` leaves the colour to
/// the parent widget (a button's label takes the button's foreground).
@immutable
class MeditoText {
  const MeditoText._(this.color, this._mutedColor);

  /// Reads the two text colours from the ambient theme, so a subtree that
  /// re-themes itself (the home hero over its artwork) is respected.
  factory MeditoText.of(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.textTheme.bodyLarge?.color;
    return MeditoText._(
      primary ?? theme.colorScheme.onSurface,
      theme.textTheme.bodySmall?.color ?? primary,
    );
  }

  factory MeditoText.forBrightness(Brightness brightness) =>
      brightness == Brightness.dark
      ? const MeditoText._(ColorConstants.white, ColorConstants.graphite)
      : const MeditoText._(
          ColorConstants.lightOnSurface,
          ColorConstants.lightGraphite,
        );

  /// The colour every style in this set is drawn in. Null for [inherited].
  final Color? color;
  final Color? _mutedColor;

  /// The same scale in the secondary text colour.
  MeditoText get muted => MeditoText._(_mutedColor, _mutedColor);

  /// The same scale in [color].
  MeditoText on(Color color) => MeditoText._(color, _mutedColor);

  /// The same scale with no colour of its own, so the text takes whatever its
  /// parent sets: a button's foreground, a list tile's text colour.
  MeditoText get inherited => MeditoText._(null, _mutedColor);

  TextStyle _style(
    double size,
    FontWeight weight,
    double height,
    double letterSpacing,
  ) => TextStyle(
    fontFamily: googleSans,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );

  /// 48 / 700. One big number or word that owns the screen.
  TextStyle get hero => _style(48, FontWeight.w700, 1.1, -1);

  /// 32 / 700. Key figures, splash and celebration headlines.
  TextStyle get display => _style(32, FontWeight.w700, 1.15, -0.5);

  /// 24 / 700. The title of a screen, or the question it asks.
  TextStyle get headline => _style(24, FontWeight.w700, 1.25, -0.25);

  /// 20 / 600. Section headers, sheet and dialog titles.
  TextStyle get title => _style(20, FontWeight.w600, 1.3, 0);

  /// 16 / 600. Card and row titles, buttons, emphasised body text.
  TextStyle get subtitle => _style(16, FontWeight.w600, 1.35, 0);

  /// 16 / 400. Anything meant to be read.
  TextStyle get body => _style(16, FontWeight.w400, 1.5, 0);

  /// 14 / 400. Supporting text under a title, helper text.
  TextStyle get bodySmall => _style(14, FontWeight.w400, 1.45, 0.1);

  /// 14 / 500. Short UI labels: chips, tabs, compact buttons.
  TextStyle get label => _style(14, FontWeight.w500, 1.3, 0.1);

  /// 12 / 500. Metadata: durations, dates, tags, fine print.
  TextStyle get caption => _style(12, FontWeight.w500, 1.35, 0.2);

  /// Maps the scale onto Material's slots so stock widgets (list tiles, text
  /// fields, date pickers, tooltips…) match the rest of the app. App code
  /// should use `context.text`, not `Theme.of(context).textTheme`.
  TextTheme toTextTheme() => TextTheme(
    displayLarge: hero,
    displayMedium: display,
    displaySmall: display,
    headlineLarge: headline,
    headlineMedium: headline,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: subtitle,
    titleSmall: label,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: muted.bodySmall,
    labelLarge: label,
    labelMedium: caption,
    labelSmall: muted.caption,
  );
}

extension MeditoTextContext on BuildContext {
  /// The app's type scale in the current theme's colours. See [MeditoText].
  MeditoText get text => MeditoText.of(this);
}
