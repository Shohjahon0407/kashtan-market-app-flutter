import 'package:beshkashtan_customer/features/cart/presentation/cart_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    for (final scale in [1.0, 2.0]) {
      for (final label in ['2 dona', '999 999 kilogram']) {
        testWidgets(
          'quantity is centered and actions stay accessible: $locale $scale $label',
          (tester) async {
            var increment = 0, decrement = 0, edit = 0;
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 180,
                      child: CartQuantityStepper(
                        quantity: 2,
                        quantityText: label,
                        semanticLabel: 'Quantity',
                        onDecrement: () => decrement++,
                        onIncrement: () => increment++,
                        onEdit: () => edit++,
                      ),
                    ),
                  ),
                ),
              ),
            );
            final minus = find.byIcon(Icons.remove);
            final plus = find.byIcon(Icons.add);
            final text = find.text(label);
            expect(
              tester.getCenter(text).dy,
              closeTo(tester.getCenter(minus).dy, .01),
            );
            expect(
              tester.getCenter(text).dy,
              closeTo(tester.getCenter(plus).dy, .01),
            );
            for (final button in find.byType(IconButton).evaluate()) {
              final size = tester.getSize(find.byWidget(button.widget));
              expect(size.width, greaterThanOrEqualTo(48));
              expect(size.height, greaterThanOrEqualTo(48));
            }
            final editor = find
                .ancestor(of: text, matching: find.byType(InkWell))
                .first;
            expect(tester.getSize(editor).height, greaterThanOrEqualTo(48));
            await tester.tap(minus);
            await tester.tap(plus);
            await tester.tap(text);
            expect([decrement, increment, edit], [1, 1, 1]);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
