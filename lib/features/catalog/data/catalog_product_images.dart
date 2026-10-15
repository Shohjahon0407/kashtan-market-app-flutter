import '../../../core/localization/uzbek_transliterator.dart';
import 'product_models.dart';

enum MeatProductKind { lamb, beef, horse, qazi, beefLiver, lambLiver, other }

MeatProductKind meatProductKind(ProductSummary product) {
  final name = UzbekTransliterator.toLatin(product.name)
      .toLowerCase()
      .replaceAll(RegExp("['‘’`ʻʼ]"), '')
      .replaceAll(RegExp(r'[^a-zа-яё0-9]+'), ' ')
      .trim();
  final liver = name.contains('jigar') || name.contains('pechen');
  final lamb = name.contains('qoy') || name.contains('baran');
  final beef =
      name.contains('mol') || name.contains('govyad') || name.contains('korov');
  final horse =
      name.contains('ot go') || name.contains('konin') || name == 'ot';
  if (liver && lamb) return MeatProductKind.lambLiver;
  if (liver && beef) return MeatProductKind.beefLiver;
  if (name.contains('qazi') || name.contains('kazi') || name.contains('kazy')) {
    return MeatProductKind.qazi;
  }
  if (lamb) return MeatProductKind.lamb;
  if (beef) return MeatProductKind.beef;
  if (horse) return MeatProductKind.horse;
  return MeatProductKind.other;
}

/// Image existence, not download state: a timeout must not reorder cards.
bool catalogProductHasImage(ProductSummary product) =>
    (product.imageUrl?.trim().isNotEmpty ?? false) ||
    (product.storeTypeWire == 'meat' &&
        meatProductKind(product) != MeatProductKind.other);
