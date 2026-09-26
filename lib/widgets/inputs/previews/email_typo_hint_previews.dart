// Widget previews for [EmailTypoHint] — the "Did you mean …?" fix under
// email fields. The top field is live: type a typo like gmil.con to see it.
//
// Run from the project root:
//
//   flutter widget-preview start --web-server
//
// Reference: https://flutter.dev/to/widget-previews

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:medito/views/previews/preview_support.dart';
import 'package:medito/widgets/inputs/email_typo_hint.dart';
import 'package:medito/widgets/inputs/medito_text_field.dart';

const emailHintPreviewSize = Size(390, 720);

Widget emailHintWrapDark(Widget child) =>
    PreviewShell(prefs: prefsDark, child: child);

Widget emailHintWrapLight(Widget child) =>
    PreviewShell(prefs: prefsLight, themeMode: ThemeMode.light, child: child);

Widget emailHintWrapSpanish(Widget child) =>
    PreviewShell(prefs: prefsDark, locale: const Locale('es'), child: child);

/// Field + hint the way the sign-up and donation screens compose them.
Widget _emailField(String caption, String text) {
  final controller = TextEditingController(text: text);
  return Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          caption,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: Color(0xFF9E9E9E),
          ),
        ),
        const SizedBox(height: 6),
        MeditoTextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          hintText: 'you@example.com',
        ),
        EmailTypoHint(controller: controller),
      ],
    ),
  );
}

Widget _states() {
  return Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _emailField('LIVE — TYPE A TYPO', ''),
          _emailField('MISSPELLED PROVIDER', 'mike@gmil.com'),
          _emailField('WRONG TLD', 'mike@hotmail.con'),
          _emailField('SWAPPED LETTERS + TLD', 'mike@gmial.cmo'),
          _emailField('UNKNOWN DOMAIN, TLD TYPO', 'mike@medito.con'),
          _emailField('CORRECT — NO HINT', 'mike@gmail.com'),
          _emailField('LEGIT NEAR-MISS — NO HINT', 'mike@ymail.com'),
        ],
      ),
    ),
  );
}

@Preview(
  group: 'EmailTypoHint',
  name: 'States · dark',
  size: emailHintPreviewSize,
  wrapper: emailHintWrapDark,
)
Widget emailTypoHintDark() => _states();

@Preview(
  group: 'EmailTypoHint',
  name: 'States · light',
  size: emailHintPreviewSize,
  wrapper: emailHintWrapLight,
)
Widget emailTypoHintLight() => _states();

@Preview(
  group: 'EmailTypoHint',
  name: 'States · es',
  size: emailHintPreviewSize,
  wrapper: emailHintWrapSpanish,
)
Widget emailTypoHintSpanish() => _states();

/// Tap Continue to see the confirm dialog every email form shows on submit.
class _ConfirmDemo extends StatefulWidget {
  const _ConfirmDemo();

  @override
  State<_ConfirmDemo> createState() => _ConfirmDemoState();
}

class _ConfirmDemoState extends State<_ConfirmDemo> {
  final _controller = TextEditingController(text: 'mike@gmial.con');
  final _confirmation = EmailTypoConfirmation();
  String _status = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final proceed = await _confirmation.confirm(context, _controller);
    setState(
      () => _status = proceed
          ? 'Submitted: ${_controller.text}'
          : 'Dismissed, still on the form',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MeditoTextField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              hintText: 'you@example.com',
            ),
            EmailTypoHint(controller: _controller),
            const SizedBox(height: 16),
            FilledButton(onPressed: _continue, child: const Text('Continue')),
            const SizedBox(height: 12),
            Text(_status),
          ],
        ),
      ),
    );
  }
}

@Preview(
  group: 'EmailTypoHint',
  name: 'Confirm on Continue',
  size: Size(390, 520),
  wrapper: emailHintWrapDark,
)
Widget emailTypoConfirmDark() => const _ConfirmDemo();
