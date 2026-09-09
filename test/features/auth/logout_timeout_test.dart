import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthApi extends Mock implements AuthApi {}

/// Chiqish tarmoq qadamlari (push tokenini bekor qilish, server logout)
/// osilib qolsa ham cheklangan vaqtda lokal tugaydi; qayta bosishlar
/// parallel logout ochmaydi; busy flag jarayon davomida true.
void main() {
  late _MockAuthApi api;
  late ProviderContainer container;
  late InMemoryTokenStore tokens;

  setUp(() async {
    AuthController.logoutStepTimeout = const Duration(milliseconds: 50);
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    api = _MockAuthApi();
    tokens = InMemoryTokenStore(access: 'acc', refresh: 'ref');
    container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        authApiProvider.overrideWithValue(api),
        // Push unregister hech qachon tugamaydi (sekin server).
        onBeforeLogoutProvider.overrideWithValue(
          () => Completer<void>().future,
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    AuthController.logoutStepTimeout = const Duration(seconds: 5);
  });

  test('osilgan qadamlar timeout bilan o\'tkazib yuboriladi', () async {
    final serverLogout = Completer<void>();
    when(() => api.logout(any())).thenAnswer((_) => serverLogout.future);
    final notifier = container.read(authControllerProvider.notifier);

    final done = notifier.logout();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(logoutBusyProvider), isTrue);

    await done.timeout(const Duration(seconds: 2));

    expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    expect(container.read(logoutBusyProvider), isFalse);
    expect(await tokens.readRefresh(), isNull);
    verify(() => api.logout('ref')).called(1);
  });

  test('parallel chaqiruvlar bitta logout', () async {
    var calls = 0;
    when(() => api.logout(any())).thenAnswer((_) async => calls++);
    final notifier = container.read(authControllerProvider.notifier);
    await Future.wait([
      notifier.logout(),
      notifier.logout(),
      notifier.logout(),
    ]);
    expect(calls, 1);
  });
}
