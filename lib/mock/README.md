# lib/mock/ — Mock Mode

This folder is **not test code**. It is a shipped demo environment that lets
anyone run the Medito app locally without needing real backend credentials
(API keys, auth URLs, Stripe keys, Firebase config, etc.).

## How to run in mock mode

```sh
flutter run --dart-define=MOCK_MODE=true
```

Or build with the same `--dart-define` flag. When set, the app starts up
against hardcoded fake data instead of the real backend.

## How it's wired

- `isMockMode` is defined in `lib/constants/http/http_constants.dart`. It
  reads the `MOCK_MODE` compile-time env var.
- When true, the `HttpApiService` factory (in
  `lib/services/network/http_api_service.dart`) returns
  `MockHttpApiService` instead of the real implementation.
  `MockHttpApiService` extends `HttpApiService` and overrides the HTTP
  methods to return canned responses from `mock_data.dart`.
- `lib/main.dart` skips Firebase / Stripe / Meta SDK initialisation when
  `isMockMode` is true.
- Various other services (`firebase_notifications_service.dart`,
  `header_service.dart`, `firebase_analytics_service.dart`, etc.) early-out
  when `isMockMode` is true.

## Why production code imports from `lib/mock/`

Because mock mode is a real, shipped run mode — not a test fixture — the
mock implementation has to be reachable from production code paths. The
swap happens at runtime inside `HttpApiService()`. This is intentional:
do not treat the `lib/services/...` → `lib/mock/...` import as a code
smell. (If we ever want to harden this, the right fix is a build flavor or
a Riverpod override that injects the mock implementation, not deleting
the folder or its imports.)

## Files

- `mock_http_api_service.dart` — drop-in `HttpApiService` subclass that
  returns canned responses
- `mock_auth_api_service.dart` — fake auth (always succeeds, returns a
  static token)
- `mock_donation_api_service.dart` — fake donation/payment flows
- `mock_data.dart` — the hardcoded JSON blobs used by the services above
