// Opt-in, read-only production probe. Not part of the offline unit-test suite.
// flutter test --no-pub --platform chrome --dart-define=LIVE_HEALTH_SMOKE=true
//   test/core/network/connectivity_health_smoke_test.dart
@TestOn('browser')
library;

import 'package:beshkashtan_customer/core/network/connectivity_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Chrome reaches public health without auth or CORS-only headers',
    () async {
      final probe = ConnectivityProbe();
      addTearDown(probe.dispose);
      expect(await probe.check(), ProbeResult.healthy);
    },
    skip: !const bool.fromEnvironment('LIVE_HEALTH_SMOKE'),
  );
}
