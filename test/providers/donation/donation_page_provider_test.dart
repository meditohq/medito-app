import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:medito/providers/donation/donation_page_provider.dart';
import 'package:medito/repositories/donation/donation_page_repository.dart';

/// Repository stub whose outcome can be flipped between calls, so a test can
/// simulate "first request fails on resume, second one succeeds".
class _FlippableRepository implements DonationPageRepository {
  int calls = 0;
  Object? failWith;

  @override
  Future<DonationPageModel> fetchDonationPage() async {
    calls++;
    final err = failWith;
    if (err != null) throw err;
    return const DonationPageModel(id: 'ask-1', title: 'Support Medito');
  }
}

void main() {
  late _FlippableRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FlippableRepository();
    container = ProviderContainer(
      overrides: [donationPageRepositoryProvider.overrideWithValue(repo)],
      // The app relies on Riverpod's default retry; here it would only make
      // the error cases wait ~40s, so turn it off for the test.
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  });

  test(
    'a successful ask is kept alive after its last listener goes away',
    () async {
      final sub = container.listen(fetchDonationPageProvider, (_, _) {});
      await container.read(fetchDonationPageProvider.future);
      expect(repo.calls, 1);

      sub.close();
      await Future<void>.delayed(Duration.zero); // let auto-dispose run

      final sub2 = container.listen(fetchDonationPageProvider, (_, _) {});
      addTearDown(sub2.close);
      await container.read(fetchDonationPageProvider.future);
      expect(repo.calls, 1, reason: 'success must be served from cache');
    },
  );

  test('a failed ask is NOT pinned: the next listener refetches', () async {
    // Regression for the Android resume-time failure (Sep 2026): keepAlive()
    // used to be called before the fetch resolved, so one transient error
    // became the answer for every later end screen in the process.
    repo.failWith = const NetworkConnectionError(
      kind: NetworkFailureKind.offline,
    );
    final sub = container.listen(fetchDonationPageProvider, (_, _) {});
    await expectLater(
      container.read(fetchDonationPageProvider.future),
      throwsA(isA<NetworkConnectionError>()),
    );
    expect(repo.calls, 1);

    sub.close();
    await Future<void>.delayed(Duration.zero); // let auto-dispose run

    repo.failWith = null; // radio is back
    final sub2 = container.listen(fetchDonationPageProvider, (_, _) {});
    addTearDown(sub2.close);
    final page = await container.read(fetchDonationPageProvider.future);
    expect(repo.calls, 2, reason: 'error must not be served from cache');
    expect(page.id, 'ask-1');
  });

  test('invalidating a failed ask while still watched refetches', () async {
    repo.failWith = const TimeoutError();
    final sub = container.listen(fetchDonationPageProvider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      container.read(fetchDonationPageProvider.future),
      throwsA(isA<TimeoutError>()),
    );

    repo.failWith = null;
    container.invalidate(fetchDonationPageProvider);
    final page = await container.read(fetchDonationPageProvider.future);
    expect(repo.calls, 2);
    expect(page.title, 'Support Medito');
  });
}
