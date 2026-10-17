import 'package:beshkashtan_customer/features/checkout/domain/order_draft_controller.dart';

/// Layout/payment tests start after cart has confirmed its order draft.
/// Real reconciliation, quote races and route guards have separate tests.
class ReviewDraft extends OrderDraftController {
  ReviewDraft(super.storeType, this.initial);

  final OrderDraftState initial;

  @override
  OrderDraftState build() => initial;

  @override
  Future<bool> prepare({bool revalidateQuote = true}) async => true;
}
