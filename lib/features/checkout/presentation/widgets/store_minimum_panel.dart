import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/store_navigation.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../cart/domain/cart_controller.dart';
import '../../domain/addresses_controller.dart';
import '../../domain/order_draft_controller.dart';
import 'delivery_minimum_progress.dart';

/// Read-only catalogue/detail footer: never prepares a draft or requests an
/// estimate. Only an existing, matching, confirmed quote may contribute a fee.
class StoreMinimumPanel extends ConsumerWidget {
  const StoreMinimumPanel({
    required this.storeType,
    required this.child,
    super.key,
  });

  final StoreType storeType;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(cartControllerProvider(storeType));
    final state = value.value;
    if (state == null || state.cart.items.isEmpty) return child;
    final draft = ref.watch(orderDraftProvider(storeType));
    if (draft.selection == null || draft.preparing) return child;
    final addresses = ref.watch(addressesControllerProvider);
    final quote = addresses.isLoading || addresses.hasError
        ? null
        : draft.quoteFor(state.cart, addresses.value ?? const []);
    if (quote == null ||
        value.isLoading ||
        value.hasError ||
        state.hasPendingMutation ||
        state.unconfirmedKeys.isNotEmpty ||
        state.mutationFailure != null ||
        state.cart.meetsDeliveryMinimumIncluding(quote.deliveryPrice)) {
      return child;
    }
    return Material(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            // In landscape with large text, keep the existing cart/product
            // action visible; the explanatory row may scroll independently.
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .25,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DeliveryMinimumProgress(
                  cart: state.cart,
                  deliveryFee: quote.deliveryPrice,
                  onAddProducts: () =>
                      goToStoreTab(context, storeType, StoreTab.cart),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
