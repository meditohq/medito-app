import 'package:flutter_test/flutter_test.dart';
import 'package:medito/utils/health_kit_manager.dart';

void main() {
  group('healthConnectTitle', () {
    test('uses the track name', () {
      expect(healthConnectTitle('Body Scan'), 'Body Scan');
    });

    test('trims surrounding whitespace', () {
      expect(healthConnectTitle('  Body Scan '), 'Body Scan');
    });

    test('falls back to Medito when missing or blank', () {
      expect(healthConnectTitle(null), kHealthConnectDefaultTitle);
      expect(healthConnectTitle(''), kHealthConnectDefaultTitle);
      expect(healthConnectTitle('   '), kHealthConnectDefaultTitle);
    });
  });

  group('healthConnectNotes', () {
    test('includes both ids', () {
      expect(
        healthConnectNotes(trackId: 'track-1', fileId: 'file-9'),
        'trackId=track-1;fileId=file-9',
      );
    });

    test('omits missing or empty ids', () {
      expect(healthConnectNotes(trackId: 'track-1'), 'trackId=track-1');
      expect(
        healthConnectNotes(trackId: 'track-1', fileId: ''),
        'trackId=track-1',
      );
      expect(healthConnectNotes(fileId: 'file-9'), 'fileId=file-9');
    });

    test('returns null when there are no ids', () {
      expect(healthConnectNotes(), isNull);
      expect(healthConnectNotes(trackId: '', fileId: ''), isNull);
    });
  });

  group('healthConnectClientRecordId', () {
    test('is stable for the same completion timestamp', () {
      final end = DateTime.fromMillisecondsSinceEpoch(1762258800000);
      expect(healthConnectClientRecordId(end), 'medito-1762258800000');
      expect(
        healthConnectClientRecordId(end),
        healthConnectClientRecordId(
          DateTime.fromMillisecondsSinceEpoch(1762258800000),
        ),
      );
    });
  });
}
