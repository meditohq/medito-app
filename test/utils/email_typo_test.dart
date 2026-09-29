import 'package:flutter_test/flutter_test.dart';
import 'package:medito/utils/email_typo.dart';

void main() {
  group('suggestEmailCorrection', () {
    const fixes = {
      'mike@gmil.com': 'mike@gmail.com',
      'mike@gmail.con': 'mike@gmail.com',
      'mike@gmial.com': 'mike@gmail.com',
      'mike@gmail.co': 'mike@gmail.com',
      'mike@hotmial.con': 'mike@hotmail.com',
      'mike@yaho.com': 'mike@yahoo.com',
      'mike@outlok.com': 'mike@outlook.com',
      'mike@icloud.cmo': 'mike@icloud.com',
      'Mike.Speed@GMAIL.CON': 'Mike.Speed@gmail.com',
      ' mike@gmil.com ': 'mike@gmail.com',
      'mike@company.con': 'mike@company.com',
    };
    fixes.forEach((input, expected) {
      test('$input -> $expected', () {
        expect(suggestEmailCorrection(input), expected);
      });
    });

    const leaveAlone = [
      'mike@gmail.com',
      'mike@mail.com',
      'mike@ymail.com',
      'mike@me.com',
      'mike@hotmail.ca',
      'mike@yahoo.com.au',
      'mike@meditofoundation.org',
      'mike@company.co',
      'mike@gm',
      'mike@gmail.',
      'mike@',
      'mike',
      '',
    ];
    for (final input in leaveAlone) {
      test('no suggestion for "$input"', () {
        expect(suggestEmailCorrection(input), isNull);
      });
    }
  });

  group('emailCorrectionSegments', () {
    List<String> bold(String typed, String suggestion) => [
      for (final s in emailCorrectionSegments(typed, suggestion))
        if (s.changed) s.text,
    ];

    test('flags the misspelled provider label', () {
      expect(bold('mike@gmil.com', 'mike@gmail.com'), ['gmail']);
    });

    test('flags only the TLD when that is the typo', () {
      expect(bold('mike@GMAIL.CON', 'mike@gmail.com'), ['com']);
    });

    test('flags each wrong label separately', () {
      expect(bold('mike@gmial.cmo', 'mike@gmail.com'), ['gmail', 'com']);
    });

    test('flags the whole domain when labels were added or lost', () {
      expect(bold('mike@g.mail.com', 'mike@gmail.com'), ['gmail.com']);
    });

    test('segments rebuild the full suggestion', () {
      final text = emailCorrectionSegments(
        'mike@gmial.cmo',
        'mike@gmail.com',
      ).map((s) => s.text).join();
      expect(text, 'mike@gmail.com');
    });
  });
}
