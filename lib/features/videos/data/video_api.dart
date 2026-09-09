import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_read.dart';
import '../../../core/network/paginated.dart';
import 'video_models.dart';

class VideoApi {
  const VideoApi(this._client);

  final ApiClient _client;

  Future<CursorPage<StoreVideo>> fetchFeed({String? nextUrl}) async {
    final data = nextUrl == null
        ? await _client.get(Api.videos, query: {'page_size': 10})
        : await _client.getUrl(nextUrl);
    return PageDecoder.cursor(data, StoreVideo.fromJson);
  }

  Future<({bool isLiked, int count})> setLike(String id, bool liked) async {
    final body = liked
        ? await _client.put(Api.videoLike(id))
        : await _client.delete(Api.videoLike(id));
    if (body is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed('video like javobi obyekt emas');
    }
    return (
      isLiked: JsonRead.boolean(body['is_liked']),
      count: JsonRead.integer(body['likes_count']),
    );
  }

  Future<VideoProductRail> fetchProducts(String videoId) async {
    final data = await _client.get(Api.videoProducts(videoId));
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed(
        'video mahsulotlari javobi obyekt emas',
      );
    }
    return VideoProductRail.fromJson(data);
  }

  Future<OffsetPage<VideoComment>> fetchComments(
    String videoId, {
    String? nextUrl,
  }) async {
    final data = nextUrl == null
        ? await _client.get(
            Api.videoComments(videoId),
            query: {'page_size': 20},
          )
        : await _client.getUrl(nextUrl);
    return PageDecoder.offset(data, VideoComment.fromJson);
  }

  Future<VideoComment> createComment(String videoId, String text) async {
    final data = await _client.post(
      Api.videoComments(videoId),
      body: {'text': text},
    );
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed('video comment javobi obyekt emas');
    }
    return VideoComment.fromJson(data);
  }

  Future<void> deleteComment(String videoId, String commentId) async {
    await _client.delete(Api.videoComment(videoId, commentId));
  }
}
