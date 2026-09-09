import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/ui/lifecycle/visible_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock>
    with WidgetsBindingObserver, RouteAware, VisibleClock {
  int ticks = 0;

  @override
  void onVisibleTick() => setState(() => ticks++);

  @override
  Widget build(BuildContext context) => Text('$ticks');
}

/// 1 Hz soat faqat ekran ko'rinib turganda yuradi: fon rejimida va ustiga
/// route push qilinganda to'xtaydi, qaytganda davom etadi.
void main() {
  _ClockState state(WidgetTester tester) =>
      // Ustiga route push qilinganda widget offstage bo'ladi — baribir topilsin.
      tester.state<_ClockState>(find.byType(_Clock, skipOffstage: false));

  testWidgets('fon rejimida to\'xtaydi, resume\'da davom etadi', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _Clock()));
    expect(state(tester).isVisibleClockRunning, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(state(tester).ticks, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(state(tester).isVisibleClockRunning, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(state(tester).ticks, 2, reason: 'fonda tik bo\'lmasligi kerak');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(state(tester).isVisibleClockRunning, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(state(tester).ticks, 3);
  });

  testWidgets('ustiga route push qilinganda to\'xtaydi, pop\'da yuradi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [appRouteObserver],
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const _Clock(),
                TextButton(
                  key: const ValueKey('push'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('top')),
                    ),
                  ),
                  child: const Text('push'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(state(tester).isVisibleClockRunning, isTrue);

    await tester.tap(find.byKey(const ValueKey('push')));
    await tester.pumpAndSettle();
    expect(state(tester).isVisibleClockRunning, isFalse);

    Navigator.of(tester.element(find.text('top'))).pop();
    await tester.pumpAndSettle();
    expect(state(tester).isVisibleClockRunning, isTrue);
  });

  testWidgets('dispose taymerni tozalaydi', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Clock()));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    // Kutilayotgan taymer qolsa flutter_test o'zi xato beradi.
    expect(find.byType(_Clock), findsNothing);
  });
}
