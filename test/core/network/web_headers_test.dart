import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web headerlari production CORS allow-list bilan mos', () {
    final headers = apiDefaultHeaders(isWeb: true);

    expect(headers, containsPair('Accept', 'application/json'));
    expect(headers, containsPair('Content-Type', 'application/json'));
    expect(headers, isNot(contains('X-App-Client')));
  });

  test('native transport backward-compatible client headerni saqlaydi', () {
    expect(
      apiDefaultHeaders(isWeb: false),
      containsPair('X-App-Client', 'customer'),
    );
  });
}
