// Widget previews for [MeditoTextField] — the single app text input.
//
// Run from the project root:
//
//   flutter widget-preview start --web-server
//
// and open the printed URL. (Adding a new preview file needs a restart of the
// widget-preview server; edits after that hot-reload.)
//
// Reference: https://flutter.dev/to/widget-previews

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:medito/views/previews/preview_support.dart';
import 'package:medito/widgets/inputs/medito_text_field.dart';

const previewSize = Size(390, 940);

Widget wrapDark(Widget child) => PreviewShell(prefs: prefsDark, child: child);

Widget wrapLight(Widget child) =>
    PreviewShell(prefs: prefsLight, themeMode: ThemeMode.light, child: child);

/// A caption above each field so the state it demonstrates is labelled.
Widget _labelled(String label, Widget field) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: Color(0xFF9E9E9E),
          ),
        ),
        const SizedBox(height: 6),
        field,
      ],
    ),
  );
}

/// Every visual state of the field, top to bottom.
Widget _states() {
  return Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _labelled(
            'EMPTY (HINT)',
            const MeditoTextField(hintText: 'Search meditations'),
          ),
          _labelled(
            'WITH LABEL',
            const MeditoTextField(labelText: 'Email address'),
          ),
          _labelled(
            'FILLED',
            MeditoTextField(
              controller: TextEditingController(text: 'Morning meditation'),
            ),
          ),
          _labelled(
            'HELPER TEXT',
            const MeditoTextField(
              hintText: 'you@example.com',
              helperText: "We'll email you a login code",
            ),
          ),
          _labelled(
            'ERROR',
            MeditoTextField(
              controller: TextEditingController(text: 'not-an-email'),
              errorText: 'Enter a valid email address',
            ),
          ),
          _labelled(
            'PREFIX + CLEAR SUFFIX',
            MeditoTextField(
              controller: TextEditingController(text: 'sleep'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: const Icon(Icons.cancel),
            ),
          ),
          _labelled(
            'PASSWORD (OBSCURED)',
            MeditoTextField(
              controller: TextEditingController(text: 'secret123'),
              obscureText: true,
              suffixIcon: const Icon(Icons.visibility_off),
            ),
          ),
          _labelled(
            'CHARACTER COUNTER',
            MeditoTextField(
              controller: TextEditingController(text: 'A few words'),
              maxLength: 80,
            ),
          ),
          _labelled(
            'MULTI-LINE',
            MeditoTextField(
              controller: TextEditingController(
                text: 'Line one\nLine two\nLine three',
              ),
              maxLines: 3,
            ),
          ),
          _labelled(
            'DISABLED',
            MeditoTextField(
              controller: TextEditingController(text: 'Locked field'),
              enabled: false,
            ),
          ),
        ],
      ),
    ),
  );
}

@Preview(
  group: 'MeditoTextField',
  name: 'All states · dark',
  size: previewSize,
  wrapper: wrapDark,
)
Widget meditoTextFieldStatesDark() => _states();

@Preview(
  group: 'MeditoTextField',
  name: 'All states · light',
  size: previewSize,
  wrapper: wrapLight,
)
Widget meditoTextFieldStatesLight() => _states();

@Preview(
  group: 'MeditoTextField',
  name: 'Focused',
  size: Size(390, 150),
  wrapper: wrapDark,
)
Widget meditoTextFieldFocused() => Scaffold(
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: const MeditoTextField(
        hintText: 'Focused field',
        autofocus: true,
      ),
    ),
  ),
);
