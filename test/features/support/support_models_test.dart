import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/support/data/support_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'murojaat turi, contact snapshot va private attachment parse bo‘ladi',
    () {
      final ticket = SupportTicket.fromJson(const {
        'id': 'f2d40860-d85d-4595-9773-13ca39db16ec',
        'subject': '',
        'message': 'Bolalar uchun shampun kerak',
        'kind': 'missing_product',
        'store_type': 'household',
        'contact_name': 'Ali Valiyev',
        'contact_phone': '+998901234567',
        'status': 'in_progress',
        'created_at': '2026-08-01T10:00:00Z',
        'attachment': {
          'id': 'attachment-1',
          'kind': 'image',
          'mime_type': 'image/webp',
          'original_name': 'tovar.webp',
          'size': 12500,
          'download_url': '/support/tickets/x/attachment/',
        },
      });

      expect(ticket.kind, SupportKind.missingProduct);
      expect(ticket.storeType, StoreType.household);
      expect(ticket.contactName, 'Ali Valiyev');
      expect(ticket.contactPhone, '+998901234567');
      expect(ticket.status, SupportStatus.inProgress);
      expect(ticket.attachment?.kind, SupportMediaKind.image);
      expect(ticket.attachment?.mimeType, 'image/webp');
      expect(ticket.createdAt, isNotNull);
    },
  );

  test('noma’lum qiymatlar xavfsiz defaultga tushadi', () {
    final ticket = SupportTicket.fromJson(const {
      'id': 'ticket-1',
      'kind': 'future_kind',
      'store_type': 'future_store',
      'status': 'future_status',
    });

    expect(ticket.kind, SupportKind.support);
    expect(ticket.storeType, isNull);
    expect(ticket.status, SupportStatus.open);
    expect(ticket.contactName, isEmpty);
    expect(ticket.attachment, isNull);
  });
}
