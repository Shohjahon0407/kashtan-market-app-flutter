import 'package:beshkashtan_customer/features/app_update/domain/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object> payload(int build) => {
    'enabled': true,
    'latest_build_number': build,
    'latest_version': '1.2.0',
    'store_url': androidStoreUrl,
  };
  test('only a strictly newer integer build offers an update', () {
    expect(AndroidAppRelease.parse(payload(4), 3)?.version, '1.2.0');
    for (final build in [2, 3]) {
      expect(AndroidAppRelease.parse(payload(build), 3), isNull);
    }
    for (final value in [
      null,
      <Object?>[],
      <String, Object?>{},
      {...payload(4), 'enabled': false},
      {...payload(4), 'latest_build_number': '4'},
      {...payload(4), 'latest_version': '  '},
      {...payload(4), 'store_url': 'https://evil.example/app'},
    ]) {
      expect(AndroidAppRelease.parse(value, 3), isNull);
    }
  });
  test('checks once per process/service and fails open', () async {
    var requests = 0;
    final service = AppUpdateService(
      enabled: true,
      readBuild: () async => '3',
      fetchRelease: () async {
        requests++;
        return payload(4);
      },
    );
    final results = await Future.wait([service.check(), service.check()]);
    expect(results.every((value) => value?.buildNumber == 4), isTrue);
    expect(requests, 1);
    await service.check();
    expect(requests, 1);
    final failed = AppUpdateService(
      enabled: true,
      readBuild: () async => '3',
      fetchRelease: () async => throw Exception('offline/404/timeout'),
    );
    expect(await failed.check(), isNull);
    final disabled = AppUpdateService(
      enabled: false,
      readBuild: () async => throw StateError('must not read'),
      fetchRelease: () async => throw StateError('must not fetch'),
    );
    expect(await disabled.check(), isNull);
  });
  test('only native Android release is enabled', () {
    for (final platform in TargetPlatform.values) {
      expect(
        supportsAndroidUpdate(release: true, web: false, platform: platform),
        platform == TargetPlatform.android,
      );
      expect(
        supportsAndroidUpdate(release: true, web: true, platform: platform),
        false,
      );
      expect(
        supportsAndroidUpdate(release: false, web: false, platform: platform),
        false,
      );
    }
  });
  test(
    'Play app is preferred with browser fallback and safe failures',
    () async {
      final urls = <Uri>[];
      expect(
        await openAndroidUpdate((uri) async {
          urls.add(uri);
          return uri.scheme == 'https';
        }),
        true,
      );
      expect(urls.map((url) => url.scheme), ['market', 'https']);
      urls.clear();
      expect(
        await openAndroidUpdate((uri) async {
          urls.add(uri);
          return true;
        }),
        true,
      );
      expect(urls.length, 1);
      expect(
        await openAndroidUpdate((_) async => throw Exception('no handler')),
        false,
      );
    },
  );
}
