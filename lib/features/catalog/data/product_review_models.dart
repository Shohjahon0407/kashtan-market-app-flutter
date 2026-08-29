import '../../../core/network/json_read.dart';

class ProductReview {
  const ProductReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
    id: JsonRead.string(json['id']),
    userId: JsonRead.string(json['user_id']),
    userName: JsonRead.string(
      json['user_display_name'] ?? json['user_name'],
      'Foydalanuvchi',
    ),
    rating: JsonRead.integer(json['rating']),
    comment: JsonRead.string(json['comment']),
    createdAt: DateTime.tryParse(JsonRead.string(json['created_at'])),
  );

  final String id;
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime? createdAt;
}
