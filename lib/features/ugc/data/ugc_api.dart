import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_providers.dart';
import 'ugc_models.dart';

final ugcApiProvider = Provider<UgcApi>(
  (ref) => UgcApi(ref.watch(apiClientProvider)),
);

final ugcPolicyProvider = FutureProvider.autoDispose<UgcPolicy>(
  (ref) => ref.watch(ugcApiProvider).fetchPolicy(),
);

final blockedUsersProvider = FutureProvider.autoDispose<List<UgcBlockedUser>>(
  (ref) => ref.watch(ugcApiProvider).fetchBlockedUsers(),
);

class UgcApi {
  const UgcApi(this._client);

  final ApiClient _client;

  Future<UgcPolicy> fetchPolicy() async {
    final data = await _client.get(Api.ugcPolicy);
    return UgcPolicy.fromJson(_map(data));
  }

  Future<void> acceptPolicy(String version) async {
    await _client.post(Api.ugcPolicyAccept, body: {'version': version});
  }

  Future<void> report({
    required String targetType,
    required String targetId,
    required UgcReportReason reason,
    String details = '',
  }) async {
    await _client.post(
      Api.ugcReports,
      body: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason.wire,
        if (details.trim().isNotEmpty) 'details': details.trim(),
      },
    );
  }

  Future<void> blockUser(String userId) =>
      _client.put(Api.ugcUserBlock(userId));

  Future<void> unblockUser(String userId) =>
      _client.delete(Api.ugcUserBlock(userId));

  Future<List<UgcBlockedUser>> fetchBlockedUsers() async {
    final data = await _client.get(Api.ugcBlockedUsers);
    final map = data is Map<String, dynamic> ? data : null;
    final raw = switch (map?['results'] ?? map?['blocked_users'] ?? data) {
      final List<dynamic> values => values,
      _ => const <dynamic>[],
    };
    return raw
        .whereType<Map<String, dynamic>>()
        .map(UgcBlockedUser.fromJson)
        .where((user) => user.id.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _map(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('UGC API javobi obyekt emas');
  }
}
