import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/network_providers.dart';

const androidStoreUrl =
    'https://play.google.com/store/apps/details?id=uz.beshkashtan.customer';

class AndroidAppRelease {
  const AndroidAppRelease({required this.buildNumber, required this.version});
  final int buildNumber;
  final String version;

  static AndroidAppRelease? parse(Object? value, int installedBuild) {
    if (value is! Map || value['enabled'] != true) return null;
    final build = value['latest_build_number'];
    final version = value['latest_version'];
    if (build is! int ||
        build <= installedBuild ||
        build <= 0 ||
        version is! String ||
        version.trim().isEmpty ||
        value['store_url'] != androidStoreUrl) {
      return null;
    }
    return AndroidAppRelease(buildNumber: build, version: version.trim());
  }
}

bool supportsAndroidUpdate({
  required bool release,
  required bool web,
  required TargetPlatform platform,
}) => release && !web && platform == TargetPlatform.android;

/// Memoized for this process only. Resume does not repeat the check/offer.
class AppUpdateService {
  AppUpdateService({
    required this.enabled,
    required this.readBuild,
    required this.fetchRelease,
  });
  final bool enabled;
  final Future<String> Function() readBuild;
  final Future<Object?> Function() fetchRelease;
  Future<AndroidAppRelease?>? _check;

  Future<AndroidAppRelease?> check() => _check ??= _load();
  Future<AndroidAppRelease?> _load() async {
    if (!enabled) return null;
    try {
      final build = int.tryParse(await readBuild());
      if (build == null || build <= 0) return null;
      return AndroidAppRelease.parse(await fetchRelease(), build);
    } catch (_) {
      // Optional check fails open: no snackbar, logout or navigation.
      return null;
    }
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>(
  (ref) => AppUpdateService(
    enabled: supportsAndroidUpdate(
      release: kReleaseMode,
      web: kIsWeb,
      platform: defaultTargetPlatform,
    ),
    readBuild: () async => (await PackageInfo.fromPlatform()).buildNumber,
    fetchRelease: () => ref.read(apiClientProvider).get(Api.androidAppRelease),
  ),
);

typedef UpdateUrlLauncher = Future<bool> Function(Uri uri);

/// Market scheme prefers the store app. Devices without Play use HTTPS.
Future<bool> openAndroidUpdate(UpdateUrlLauncher launch) async {
  for (final uri in [
    Uri.parse('market://details?id=uz.beshkashtan.customer'),
    Uri.parse(androidStoreUrl),
  ]) {
    try {
      if (await launch(uri)) return true;
    } catch (_) {
      /* Try browser fallback. */
    }
  }
  return false;
}

final updateUrlLauncherProvider = Provider<UpdateUrlLauncher>(
  (ref) => (uri) async {
    if (uri.scheme == 'market') {
      return await const MethodChannel(
            'uz.beshkashtan.customer/app_update',
          ).invokeMethod<bool>('openGooglePlay') ??
          false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  },
);
