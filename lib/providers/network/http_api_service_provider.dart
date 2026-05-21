import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/services/network/http_api_service.dart';

/// Provider for the app's [HttpApiService] singleton.
///
/// In production this just returns `HttpApiService()` — the singleton factory
/// behaviour the rest of the app already relies on. The provider exists so
/// that tests (and future refactors) can override the http layer with a
/// fake/mock without touching every consumer call site.
///
/// New code wiring up to the HTTP layer should prefer reading this provider
/// over calling `HttpApiService()` directly, so the override seam works for
/// it too.
final httpApiServiceProvider = Provider<HttpApiService>((ref) {
  return HttpApiService();
});
