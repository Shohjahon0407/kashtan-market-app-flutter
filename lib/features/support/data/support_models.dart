import 'dart:typed_data';

import '../../../core/store_scope/store_type.dart';

enum SupportKind {
  missingProduct('missing_product'),
  suggestion('suggestion'),
  support('support');

  const SupportKind(this.wire);
  final String wire;

  static SupportKind fromWire(String? value) => values.firstWhere(
    (item) => item.wire == value,
    orElse: () => SupportKind.support,
  );
}

enum SupportStatus {
  open('open'),
  inProgress('in_progress'),
  closed('closed');

  const SupportStatus(this.wire);
  final String wire;

  static SupportStatus fromWire(String? value) => values.firstWhere(
    (item) => item.wire == value,
    orElse: () => SupportStatus.open,
  );
}

enum SupportMediaKind { image, voice }

class SupportMedia {
  const SupportMedia({
    required this.kind,
    required this.bytes,
    required this.filename,
  });

  final SupportMediaKind kind;
  final Uint8List bytes;
  final String filename;
}

class SupportAttachment {
  const SupportAttachment({
    required this.id,
    required this.kind,
    required this.mimeType,
    required this.originalName,
    required this.size,
    required this.downloadUrl,
  });

  factory SupportAttachment.fromJson(Map<String, dynamic> json) =>
      SupportAttachment(
        id: '${json['id'] ?? ''}',
        kind: '${json['kind'] ?? ''}' == 'image'
            ? SupportMediaKind.image
            : SupportMediaKind.voice,
        mimeType: '${json['mime_type'] ?? ''}',
        originalName: '${json['original_name'] ?? ''}',
        size: (json['size'] as num?)?.toInt() ?? 0,
        downloadUrl: '${json['download_url'] ?? ''}',
      );

  final String id;
  final SupportMediaKind kind;
  final String mimeType;
  final String originalName;
  final int size;
  final String downloadUrl;
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.kind,
    required this.storeType,
    required this.contactName,
    required this.contactPhone,
    required this.status,
    required this.createdAt,
    this.attachment,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final attachment = json['attachment'];
    return SupportTicket(
      id: '${json['id'] ?? ''}',
      subject: '${json['subject'] ?? ''}',
      message: '${json['message'] ?? ''}',
      kind: SupportKind.fromWire(json['kind'] as String?),
      storeType: StoreType.fromWire('${json['store_type'] ?? ''}'),
      contactName: '${json['contact_name'] ?? ''}',
      contactPhone: '${json['contact_phone'] ?? ''}',
      status: SupportStatus.fromWire(json['status'] as String?),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
      attachment: attachment is Map<String, dynamic>
          ? SupportAttachment.fromJson(attachment)
          : null,
    );
  }

  final String id;
  final String subject;
  final String message;
  final SupportKind kind;
  final StoreType? storeType;
  final String contactName;
  final String contactPhone;
  final SupportStatus status;
  final DateTime? createdAt;
  final SupportAttachment? attachment;
}
