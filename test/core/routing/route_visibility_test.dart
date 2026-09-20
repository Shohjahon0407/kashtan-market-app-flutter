import 'dart:async';

import 'package:beshkashtan_customer/core/routing/route_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ichki navigator ichidagi ekran root route'ni ham ko'radi va zanjir
/// chekli (Navigator o'z context'ida o'zini qaytarib sikl qilmasin).
void main() {
  testWidgets('ichki navigator → 2 ta route, root push qilinganda joriy emas', (
    tester,
  ) async {
    late BuildContext inner;
    final rootNavigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigator,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              inner = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(enclosingRoutesOf(inner), hasLength(2));
    expect(isRouteStackCurrent(inner), isTrue);

    unawaited(
      rootNavigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    expect(isRouteStackCurrent(inner), isFalse);
  });

  testWidgets('navigator yo\'q — bitta route', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(enclosingRoutesOf(ctx), hasLength(1));
  });
}
