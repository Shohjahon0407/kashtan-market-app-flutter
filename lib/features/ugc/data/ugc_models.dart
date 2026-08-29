import '../../../core/network/json_read.dart';

class UgcPolicy {
  const UgcPolicy({
    required this.version,
    required this.accepted,
    required this.title,
    required this.summary,
    required this.termsUrl,
    required this.communityGuidelinesUrl,
  });

  factory UgcPolicy.fromJson(Map<String, dynamic> json) => UgcPolicy(
    version: JsonRead.string(json['version']),
    accepted: JsonRead.boolean(json['accepted']),
    title: JsonRead.string(json['title']),
    summary: JsonRead.string(json['summary']),
    termsUrl: JsonRead.string(json['terms_url']),
    communityGuidelinesUrl: JsonRead.string(json['community_guidelines_url']),
  );

  final String version;
  final bool accepted;
  final String title;
  final String summary;
  final String termsUrl;
  final String communityGuidelinesUrl;
}

class UgcBlockedUser {
  const UgcBlockedUser({
    required this.id,
    required this.displayName,
    this.blockedAt,
  });

  factory UgcBlockedUser.fromJson(Map<String, dynamic> json) {
    final nested = JsonRead.map(json['blocked_user']);
    final source = nested ?? json;
    return UgcBlockedUser(
      id: JsonRead.string(source['id'] ?? json['user_id']),
      displayName: JsonRead.string(
        source['display_name'] ??
            source['full_name'] ??
            source['name'] ??
            json['display_name'],
        'Foydalanuvchi',
      ),
      blockedAt: DateTime.tryParse(JsonRead.string(json['blocked_at'])),
    );
  }

  final String id;
  final String displayName;
  final DateTime? blockedAt;
}

enum UgcReportReason {
  spam('spam'),
  abuse('abuse'),
  inappropriate('inappropriate'),
  other('other');

  const UgcReportReason(this.wire);
  final String wire;
}
