import 'package:beshkashtan_customer/features/catalog/data/product_review_models.dart';
import 'package:beshkashtan_customer/features/ugc/data/ugc_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UGC policy payloadini to‘liq parse qiladi', () {
    final policy = UgcPolicy.fromJson({
      'version': '2026-08-29-v1',
      'accepted': true,
      'title': 'Hamjamiyat qoidalari',
      'summary': 'Hurmatli bo‘ling',
      'terms_url': 'https://api.beshkashtan.uz/terms/',
      'community_guidelines_url':
          'https://api.beshkashtan.uz/community-guidelines/',
    });

    expect(policy.version, '2026-08-29-v1');
    expect(policy.accepted, isTrue);
    expect(policy.termsUrl, endsWith('/terms/'));
    expect(policy.communityGuidelinesUrl, endsWith('/community-guidelines/'));
  });

  test('blocked user backend shakli bilan mos', () {
    final user = UgcBlockedUser.fromJson({
      'user_id': 'f8553fb4-99c7-4ea0-b1d4-cf2820cb0a7b',
      'name': 'Ali Valiyev',
      'created_at': '2026-08-29T10:00:00+05:00',
    });

    expect(user.id, 'f8553fb4-99c7-4ea0-b1d4-cf2820cb0a7b');
    expect(user.displayName, 'Ali Valiyev');
  });

  test('product review additive user_id ni parse qiladi', () {
    final review = ProductReview.fromJson({
      'id': 'f18fc2a2-99d8-4dab-b235-a06a29aeec36',
      'user_id': '9286605c-2968-437b-99e7-01ece43d9540',
      'user_display_name': 'Malika',
      'rating': 5,
      'comment': 'Yaxshi mahsulot',
      'created_at': '2026-08-29T10:00:00+05:00',
    });

    expect(review.userId, '9286605c-2968-437b-99e7-01ece43d9540');
    expect(review.userName, 'Malika');
  });
}
