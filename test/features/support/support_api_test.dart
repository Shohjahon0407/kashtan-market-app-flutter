import 'dart:convert';
import 'dart:typed_data';

import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/support/data/support_api.dart';
import 'package:beshkashtan_customer/features/support/data/support_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MultipartAdapter implements HttpClientAdapter {
  String requestBody = '';
  Headers? requestHeaders;
  String? path;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    requestBody = latin1.decode(bytes);
    requestHeaders = Headers.fromMap(
      options.headers.map((key, value) => MapEntry(key, ['$value'])),
    );
    path = options.path;
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'ticket-1',
        'message': 'Oq shampun kerak',
        'kind': 'missing_product',
        'store_type': 'household',
        'contact_name': 'Ali Valiyev',
        'contact_phone': '+998901234567',
        'status': 'open',
        'created_at': '2026-08-01T10:00:00Z',
        'attachment': null,
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'multipart boundary, store context va attachment serverga yuboriladi',
    () async {
      final adapter = _MultipartAdapter();
      final client = ApiClient.create(
        tokenStore: InMemoryTokenStore(access: 'access', refresh: 'refresh'),
        apiLang: () => 'uz',
        script: () => UzScript.none,
        refresh: (_) async => null,
        onSessionExpired: () async {},
        adapter: adapter,
      );
      final api = SupportApi(client);

      final ticket = await api.createTicket(
        kind: SupportKind.missingProduct,
        message: '  Oq shampun kerak  ',
        storeType: 'household',
        media: SupportMedia(
          kind: SupportMediaKind.image,
          bytes: Uint8List.fromList(const [65, 66, 67]),
          filename: 'request.webp',
        ),
      );

      expect(adapter.path, '/support/tickets/');
      expect(
        adapter.requestHeaders?.value(Headers.contentTypeHeader),
        startsWith('multipart/form-data; boundary='),
      );
      expect(adapter.requestBody, contains('name="kind"'));
      expect(adapter.requestBody, contains('missing_product'));
      expect(adapter.requestBody, contains('name="store_type"'));
      expect(adapter.requestBody, contains('household'));
      expect(adapter.requestBody, contains('filename="request.webp"'));
      expect(adapter.requestBody, contains('ABC'));
      expect(ticket.kind, SupportKind.missingProduct);
      expect(ticket.contactPhone, '+998901234567');
    },
  );
}
