import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectOrderSocket(Uri uri, Map<String, dynamic> headers) =>
    WebSocketChannel.connect(webSocketUriWithBearer(uri, headers));

/// Browser WebSocket API custom `Authorization` header yubora olmaydi.
/// Backend JWT middleware shu holat uchun `token` query fallbackini qo'llaydi.
Uri webSocketUriWithBearer(Uri uri, Map<String, dynamic> headers) {
  final authorization = headers['Authorization']?.toString().trim() ?? '';
  const prefix = 'Bearer ';
  final token = authorization.startsWith(prefix)
      ? authorization.substring(prefix.length).trim()
      : '';
  if (token.isEmpty) return uri;
  return uri.replace(queryParameters: {...uri.queryParameters, 'token': token});
}
