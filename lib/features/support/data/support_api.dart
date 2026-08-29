import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paginated.dart';
import 'support_models.dart';

class SupportApi {
  const SupportApi(this._client);

  final ApiClient _client;

  Future<List<SupportTicket>> fetchTickets() async {
    final data = await _client.get(Api.supportTickets);
    return PageDecoder.bare(data, SupportTicket.fromJson).items;
  }

  Future<SupportTicket> createTicket({
    required SupportKind kind,
    required String message,
    String? storeType,
    SupportMedia? media,
    ProgressCallback? onSendProgress,
  }) async {
    final form = FormData.fromMap({
      'kind': kind.wire,
      'message': message.trim(),
      if (storeType != null && storeType.isNotEmpty) 'store_type': storeType,
      if (media != null)
        'attachment': MultipartFile.fromBytes(
          media.bytes,
          filename: media.filename,
        ),
    });
    final data = await _client.postMultipart(
      Api.supportTickets,
      body: form,
      onSendProgress: onSendProgress,
    );
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure('support ticket javobi obyekt emas');
    }
    return SupportTicket.fromJson(data);
  }
}
