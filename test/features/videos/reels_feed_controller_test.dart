import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/features/videos/data/video_api.dart';
import 'package:beshkashtan_customer/features/videos/data/video_models.dart';
import 'package:beshkashtan_customer/features/videos/domain/reels_feed_controller.dart';
import 'package:beshkashtan_customer/features/videos/domain/video_feed_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Videolar tabi: seed sessiyada barqaror, refresh yangi seed, keyingi
/// sahifa faqat `next` URL (seed URL ichida).
void main() {
  late _RecordingVideoApi api;
  late ProviderContainer container;
  late List<int> seeds;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    api = _RecordingVideoApi();
    seeds = [11, 22, 33];
    var cursor = 0;
    container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        videoApiProvider.overrideWithValue(api),
        reelsFeedControllerProvider.overrideWith(
          () => ReelsFeedController(seedFactory: () => seeds[cursor++]),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('birinchi sahifa seed bilan, loadMore faqat next URL bilan', () async {
    final sub = container.listen(reelsFeedControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(reelsFeedControllerProvider.future);

    expect(api.calls, [(nextUrl: null, seed: 11)]);
    expect(container.read(reelsFeedControllerProvider.notifier).seed, 11);

    await container.read(reelsFeedControllerProvider.notifier).loadMore();
    expect(api.calls.last, (
      nextUrl: '/videos/?cursor=abc&seed=11',
      seed: null,
    ));
    expect(container.read(reelsFeedControllerProvider).value?.items.length, 2);
  });

  test('refresh yangi seed oladi (boshqa tartib)', () async {
    final sub = container.listen(reelsFeedControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(reelsFeedControllerProvider.future);
    await container.read(reelsFeedControllerProvider.notifier).refresh();

    expect(api.calls.map((call) => call.seed), [11, 22]);
    expect(container.read(reelsFeedControllerProvider.notifier).seed, 22);
  });

  test('seed backend oralig\'ida: 1..1000000', () {
    for (var i = 0; i < 200; i++) {
      final seed = ReelsFeedController().seed;
      expect(seed, inInclusiveRange(1, 1000000));
    }
  });
}

class _RecordingVideoApi extends Fake implements VideoApi {
  final List<({String? nextUrl, int? seed})> calls = [];

  @override
  Future<CursorPage<StoreVideo>> fetchFeed({String? nextUrl, int? seed}) async {
    calls.add((nextUrl: nextUrl, seed: seed));
    if (nextUrl != null) {
      return CursorPage(items: [_video('v-2')], nextUrl: null);
    }
    return CursorPage(
      items: [_video('v-1')],
      nextUrl: '/videos/?cursor=abc&seed=$seed',
    );
  }
}

StoreVideo _video(String id) => StoreVideo.fromJson({
  'id': id,
  'video_url': 'https://cdn.example/$id.mp4',
  'poster_url': null,
  'title': 'Video $id',
  'store': {'id': 'store-1', 'name': 'Xozmak', 'store_type': 'household'},
  'product': null,
  'duration': '10.0',
  'likes_count': 0,
  'comments_count': 0,
  'is_liked': false,
  'published_at': '2026-08-01T10:00:00Z',
});
