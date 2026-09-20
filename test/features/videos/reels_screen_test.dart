import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/features/home/domain/home_tab_controller.dart';
import 'package:beshkashtan_customer/features/store/presentation/widgets/store_state_views.dart';
import 'package:beshkashtan_customer/features/videos/data/video_api.dart';
import 'package:beshkashtan_customer/features/videos/data/video_models.dart';
import 'package:beshkashtan_customer/features/videos/domain/video_feed_controller.dart';
import 'package:beshkashtan_customer/features/videos/presentation/reels_screen.dart';
import 'package:beshkashtan_customer/features/videos/presentation/widgets/video_reel_card.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Videolar tabi ekrani: reels sahifalari, bo'sh/xato holatlari, oxiriga
/// yaqinlashganda loadMore.
void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    VideoApi api, {
    HomeTab tab = HomeTab.videos,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        videoApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    container.read(homeTabProvider.notifier).set(tab);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReelsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  testWidgets('sahifalar reel kartasi bilan quriladi, oxirida loadMore', (
    tester,
  ) async {
    final api = _FakeVideoApi(count: 3, hasMore: true);
    await pump(tester, api);

    expect(find.byKey(const ValueKey('reels-page-v-0')), findsOneWidget);
    expect(find.byType(VideoReelCard), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(
      tester.widget<PageView>(find.byType(PageView)).scrollDirection,
      Axis.vertical,
    );

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    controller.jumpToPage(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('reels-page-v-1')), findsOneWidget);
    // index 1 >= 3 - 2 → keyingi sahifa so'raladi.
    expect(api.nextCalls, 1);
  });

  testWidgets('bo\'sh lenta — bo\'sh holat, tortib yangilash mumkin', (
    tester,
  ) async {
    await pump(tester, _FakeVideoApi(count: 0));
    expect(find.byType(StoreEmptyView), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('xato — qayta urinish tugmasi', (tester) async {
    final api = _FakeVideoApi(count: 2, failFirst: true);
    await pump(tester, api);
    expect(find.byType(StoreErrorView), findsOneWidget);

    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('reels-page-v-0')), findsOneWidget);
  });
}

class _FakeVideoApi extends Fake implements VideoApi {
  _FakeVideoApi({
    required this.count,
    this.hasMore = false,
    this.failFirst = false,
  });

  final int count;
  final bool hasMore;
  bool failFirst;
  int nextCalls = 0;

  @override
  Future<CursorPage<StoreVideo>> fetchFeed({String? nextUrl, int? seed}) async {
    if (nextUrl != null) {
      nextCalls++;
      return CursorPage(items: [_video('v-$count')], nextUrl: null);
    }
    if (failFirst) {
      failFirst = false;
      throw StateError('network');
    }
    return CursorPage(
      items: [for (var i = 0; i < count; i++) _video('v-$i')],
      nextUrl: hasMore ? '/videos/?cursor=next' : null,
    );
  }

  @override
  Future<VideoProductRail> fetchProducts(String videoId) async =>
      VideoProductRail.fromJson({
        'category': null,
        'results': <Object>[],
        'see_all': null,
      });
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
