import 'package:beshkashtan_customer/features/app_update/presentation/update_navigation_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('nested modal blocks the offer; disposed branch releases it', (
    tester,
  ) async {
    final gate = UpdateNavigationGate();
    addTearDown(gate.dispose);
    var visible = true;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [gate.observer()],
        home: StatefulBuilder(
          builder: (_, setState) {
            change = setState;
            if (!visible) return const SizedBox.shrink();
            return Navigator(
              observers: [gate.observer()],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      useRootNavigator: false,
                      builder: (_) =>
                          const AlertDialog(title: Text('Nested modal')),
                    ),
                    child: const Text('Open nested modal'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open nested modal'));
    await tester.pumpAndSettle();
    expect(gate.hasPopup, true);
    change(() => visible = false);
    await tester.pumpAndSettle();
    expect(gate.hasPopup, false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
