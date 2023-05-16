import 'package:Medito/models/models.dart';
import 'package:Medito/providers/auth/auth_token_provider.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

//ignore:prefer-match-file-name
class MockAuthRepository extends Mock implements AuthRepositoryImpl {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  setUpAll(() {
    registerFallbackValue(const AsyncLoading<UserTokenModel?>());
  });
  ProviderContainer makeProviderContainer(MockAuthRepository repository) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  test('initialize token provider', () {
    final authRepository = MockAuthRepository();
    // create the ProviderContainer with the mock auth repository
    final container = makeProviderContainer(MockAuthRepository());
    // create a listener
    final listener = Listener<AsyncValue<UserTokenModel?>>();
    // listen to the provider and call [listener] whenever its value changes
    container.listen(
      authTokenProvider,
      listener,
      fireImmediately: true,
    );

    // verify
    verify(
      // the build method returns a value immediately, so we expect AsyncData
      () => listener(null, const AsyncData<UserTokenModel?>(null)),
    );

    // verify that the listener is no longer called
    verifyNoMoreInteractions(listener);
    // verify that [generateUserToken] was not called during initialization
    verifyNever(authRepository.generateUserToken);
  });

  test('generate token success', () async {
    final authRepository = MockAuthRepository();
    //ARRANGE

    // stub method to return success
    when(() => authRepository.generateUserToken()).thenAnswer(
      (_) => Future.value(),
    );
    // create the ProviderContainer with the mock auth repository
    final container = makeProviderContainer(MockAuthRepository());
    final listener = Listener<AsyncValue<UserTokenModel?>>();

    container.listen(
      authTokenProvider,
      listener,
      fireImmediately: true,
    );
    // store this into a variable since we'll need it multiple times
    var data = AsyncData<UserTokenModel?>(null);
    // verify initial value from the build method
    verify(() => listener(null, data));

    // get the controller via container.read
    final controller = container.read(authTokenProvider.notifier);

    // run
    await controller.generateUserToken();

    // verify
    verifyInOrder([
      // set loading state
      // * use a matcher since AsyncLoading != AsyncLoading with data
      () => listener(data, any(that: isA<AsyncLoading>())),
      // data when complete
      () => listener(any(that: isA<AsyncLoading>()), data),
    ]);
    // verifyNoMoreInteractions(listener);
    // verifyNever(() => authRepository.generateUserToken()).called(0);
  });
}


    // verifyInOrder([
    //   // set loading state
    //   // * use a matcher since AsyncLoading != AsyncLoading with data
    //   () => listener(
    //         data,
    //         any(that: isA<AsyncData<UserTokenModel?>>()),
    //       ),
    //   () => listener(
    //         any(that: isA<AsyncLoading>()),
    //         data,
    //       ),
    //   // data when complete
    //   // () => listener(any(that: isA<AsyncLoading>()), data),
    // ]);
