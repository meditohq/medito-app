import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/views/search/search_query_logger.dart';

void main() {
  late List<(String, Map<String, Object>)> logged;
  late SearchQueryLogger logger;
  const idle = Duration(milliseconds: 30);

  setUp(() {
    logged = [];
    logger = SearchQueryLogger(
      log: (name, params) => logged.add((name, params)),
      idle: idle,
    );
  });
  tearDown(() => logger.dispose());

  List<String> terms(String event) => [
    for (final (name, params) in logged)
      if (name == event)
        params[AnalyticsEventConstants.paramSearchTerm] as String,
  ];

  Future<void> waitIdle() => Future<void>.delayed(idle * 3);

  test('typing through pauses logs only the final query', () async {
    for (final q in ['germ', 'germa', 'german']) {
      logger.onQuery(q);
      logger.onResults(q, hasResults: false);
    }
    await waitIdle();

    expect(terms(AnalyticsEventConstants.searchPerformed), ['german']);
    expect(terms(AnalyticsEventConstants.searchNoResults), ['german']);
  });

  test(
    'no-results event only when the committed query found nothing',
    () async {
      logger.onQuery('sleep');
      logger.onResults('sleep', hasResults: true);
      await waitIdle();

      expect(terms(AnalyticsEventConstants.searchPerformed), ['sleep']);
      expect(terms(AnalyticsEventConstants.searchNoResults), isEmpty);
      expect(logged.single.$2[AnalyticsEventConstants.paramHasResults], 'true');
    },
  );

  test('opening a result commits immediately', () {
    logger.onQuery('anxiety');
    logger.onResults('anxiety', hasResults: true);
    logger.commit();

    expect(terms(AnalyticsEventConstants.searchPerformed), ['anxiety']);
  });

  test('clearing the field commits what was typed', () {
    logger.onQuery('breath');
    logger.onQuery('');

    expect(terms(AnalyticsEventConstants.searchPerformed), ['breath']);
  });

  test('results still loading: logged without has_results or no-results', () {
    logger.onQuery('chakras');
    logger.commit();

    expect(
      logged.single.$2.containsKey(AnalyticsEventConstants.paramHasResults),
      isFalse,
    );
    expect(terms(AnalyticsEventConstants.searchNoResults), isEmpty);
  });

  test('late results for an older query are not attributed to the new one', () {
    logger.onQuery('pre');
    logger.onQuery('pregnancy');
    logger.onResults('pre', hasResults: false);
    logger.commit();

    expect(terms(AnalyticsEventConstants.searchNoResults), isEmpty);
  });

  test('repeat commits and re-searching the same term log once', () {
    logger.onQuery('pain');
    logger.commit();
    logger.commit();
    logger.onQuery('pain');
    logger.commit();

    expect(terms(AnalyticsEventConstants.searchPerformed), ['pain']);
  });

  group('sanitizeSearchTerm', () {
    test('trims and lowercases', () {
      expect(sanitizeSearchTerm('  Sleep Story '), 'sleep story');
    });

    test('redacts emails and phone numbers', () {
      expect(sanitizeSearchTerm('test@medito.app'), redactedSearchTerm);
      expect(sanitizeSearchTerm('+44 7700 900 123'), redactedSearchTerm);
    });

    test('keeps ordinary numbers', () {
      expect(sanitizeSearchTerm('10 day course'), '10 day course');
      expect(sanitizeSearchTerm('day 1'), 'day 1');
    });

    test('caps at 100 characters', () {
      expect(sanitizeSearchTerm('a' * 150).length, 100);
    });
  });
}
