import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/timer/timer_format.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  group('spokenDuration', () {
    test('leaves out zero parts', () {
      expect(
        spokenDuration(const Duration(minutes: 3, seconds: 12), en),
        '3 minutes 12 seconds',
      );
      expect(spokenDuration(const Duration(minutes: 10), en), '10 minutes');
      expect(
        spokenDuration(const Duration(hours: 1, seconds: 5), en),
        '1 hour 5 seconds',
      );
    });

    test('uses singular forms', () {
      expect(
        spokenDuration(const Duration(hours: 1, minutes: 1, seconds: 1), en),
        '1 hour 1 minute 1 second',
      );
      expect(
        spokenDuration(const Duration(minutes: 1, seconds: 1), de),
        '1 Minute 1 Sekunde',
      );
    });

    test('a zero or negative duration is 0 seconds', () {
      expect(spokenDuration(Duration.zero, en), '0 seconds');
      expect(spokenDuration(const Duration(seconds: -4), en), '0 seconds');
      expect(
        spokenDuration(const Duration(milliseconds: 900), en),
        '0 seconds',
      );
    });
  });
}
