import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/utils/receipt_email.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves a trimmed address and reads it back', () async {
    final prefs = await SharedPreferences.getInstance();
    await ReceiptEmail.save(prefs, '  donor@example.com ');
    expect(ReceiptEmail.read(prefs), 'donor@example.com');
    expect(
      prefs.getString(SharedPreferenceConstants.emailAddressForReceipt),
      'donor@example.com',
    );
  });

  test('ignores blank input and never overwrites with it', () async {
    final prefs = await SharedPreferences.getInstance();
    await ReceiptEmail.save(prefs, 'donor@example.com');
    await ReceiptEmail.save(prefs, '   ');
    expect(ReceiptEmail.read(prefs), 'donor@example.com');
  });

  test('reads null when nothing stored', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(ReceiptEmail.read(prefs), isNull);
  });
}
