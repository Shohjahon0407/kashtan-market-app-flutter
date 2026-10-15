import 'package:beshkashtan_customer/features/catalog/presentation/widgets/catalog_loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('catalog first load uses static placeholders without spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(slivers: [CatalogGridSkeletonSliver()]),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SliverGrid), findsOneWidget);
  });

  testWidgets('row loading placeholder is scrollable and not animated', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CatalogRowsSkeleton())),
    );

    expect(find.byKey(const ValueKey('catalog-rows-skeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
  });
}
