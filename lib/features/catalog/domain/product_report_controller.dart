import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/store_scope/store_type.dart';
import '../../store/domain/store_landing_controller.dart';
import 'catalog_controller.dart';

/// Sessiya ichida "hozirgina xabar qilingan" mahsulotlar holati.
///
/// Server holati (`ProductSummary.inReview`) keyingi refetch'da keladi;
/// bu controller esa tugma bosilishi bilan DARHOL tugmani yashirish va
/// "Tekshiruvda" belgisini ko'rsatish uchun optimistik to'plam saqlaydi
/// (favorites'dagi `busyProductIds` uslubi).
class ProductReportState {
  const ProductReportState({
    this.reportedIds = const {},
    this.busyIds = const {},
    this.failure,
  });

  final Set<String> reportedIds;
  final Set<String> busyIds;
  final ApiFailure? failure;

  bool isReported(String productId) => reportedIds.contains(productId);
  bool isBusy(String productId) => busyIds.contains(productId);

  ProductReportState copyWith({
    Set<String>? reportedIds,
    Set<String>? busyIds,
    ApiFailure? Function()? failure,
  }) => ProductReportState(
    reportedIds: reportedIds ?? this.reportedIds,
    busyIds: busyIds ?? this.busyIds,
    failure: failure != null ? failure() : this.failure,
  );
}

final productReportControllerProvider =
    NotifierProvider<ProductReportController, ProductReportState>(
      ProductReportController.new,
    );

class ProductReportController extends Notifier<ProductReportState> {
  @override
  ProductReportState build() => const ProductReportState();

  /// true — muvaffaqiyat (yoki allaqachon yuborilgan), false — xatolik.
  Future<bool> report(String productId) async {
    if (state.isBusy(productId) || state.isReported(productId)) return true;
    state = state.copyWith(
      busyIds: {...state.busyIds, productId},
      failure: () => null,
    );
    try {
      await ref.read(catalogApiProvider).reportProduct(productId);
      state = state.copyWith(
        reportedIds: {...state.reportedIds, productId},
        busyIds: {...state.busyIds}..remove(productId),
      );
      return true;
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        busyIds: {...state.busyIds}..remove(productId),
        failure: () => failure,
      );
      return false;
    }
  }
}

/// Report tugmasi ko'rinsinmi? Backend flag'i landing payload'ida keladi va
/// faqat household uchun true bo'ladi; boshqa do'konlarda landing'ni umuman
/// kuzatmaymiz (ortiqcha fetch bo'lmasin deb erta false qaytariladi).
final reportButtonEnabledProvider = Provider.autoDispose
    .family<bool, StoreType>((ref, storeType) {
      if (storeType != StoreType.household) return false;
      return ref
              .watch(storeLandingProvider(storeType))
              .value
              ?.reportButtonEnabled ??
          false;
    });
