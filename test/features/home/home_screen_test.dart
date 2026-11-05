import 'dart:async';

import 'package:beshkashtan_customer/core/localization/app_locale.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/home/data/home_api.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/features/home/presentation/home_screen.dart';
import 'package:beshkashtan_customer/features/home/presentation/widgets/store_grid.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/interaction_tracker.dart';
import 'package:beshkashtan_customer/features/videos/data/video_api.dart';
import 'package:beshkashtan_customer/features/videos/data/video_models.dart';
import 'package:beshkashtan_customer/features/videos/domain/video_feed_controller.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/fake_recommendations_api.dart';

class _MockHomeApi extends Mock implements HomeApi {}

class _MockAuthApi extends Mock implements AuthApi {}

class _MockVideoApi extends Mock implements VideoApi {}

class _MockCheckoutApi extends Mock implements CheckoutApi {}

class _MockCartApi extends Mock implements CartApi {}

const _hub = [
  StoreHubItem(
    storeType: StoreType.shashlik,
    storeTypeWire: 'shashlik',
    label: 'Shashlik marenovka',
    subtitle: 'Marinovka sexi',
    imageUrl: null,
    accentColor: null,
    sortOrder: 0,
  ),
  StoreHubItem(
    storeType: StoreType.grocery,
    storeTypeWire: 'grocery',
    label: 'Misqol market',
    subtitle: 'Oziq-ovqat do\'koni',
    imageUrl: null,
    accentColor: null,
    sortOrder: 1,
  ),
  StoreHubItem(
    storeType: StoreType.household,
    storeTypeWire: 'household',
    label: 'Xozmak',
    subtitle: 'Uy uchun kerakli mahsulotlar',
    imageUrl: null,
    accentColor: null,
    sortOrder: 2,
  ),
  StoreHubItem(
    storeType: StoreType.restaurant,
    storeTypeWire: 'restaurant',
    label: 'Ofiyat milliy taomlari',
    subtitle: 'Restoran va issiq taomlar',
    imageUrl: null,
    accentColor: null,
    sortOrder: 3,
  ),
  StoreHubItem(
    storeType: StoreType.meat,
    storeTypeWire: 'meat',
    label: "Go'sht mahsulotlari",
    subtitle: "Mol, qo'y, tovuq go'shti",
    imageUrl: null,
    accentColor: null,
    sortOrder: 4,
  ),
];

const _defaultAddress = UserAddress(
  id: 'address-1',
  title: 'Chilonzor 12-kvartal',
  isDefault: true,
  latitude: 41.28,
  longitude: 69.2,
);

const _videos = [
  StoreVideo(
    id: 'video-1',
    videoUrl: 'https://example.com/video-1.mp4',
    title: 'Birinchi video',
    store: VideoStore(id: 'store-1', name: 'Xozmak', storeType: 'household'),
    likesCount: 0,
    commentsCount: 0,
    isLiked: false,
    publishedAt: null,
  ),
  StoreVideo(
    id: 'video-2',
    videoUrl: 'https://example.com/video-2.mp4',
    title: 'Ikkinchi video',
    store: VideoStore(id: 'store-1', name: 'Xozmak', storeType: 'household'),
    likesCount: 0,
    commentsCount: 0,
    isLiked: false,
    publishedAt: null,
  ),
];

/// Kuchli fling testlari uchun uzunroq lenta — 2 ta reel bilan "o'tib
/// ketish"ni ko'rib bo'lmaydi.
List<StoreVideo> _manyVideos(int count) => [
  for (var i = 1; i <= count; i++)
    StoreVideo(
      id: 'video-$i',
      videoUrl: 'https://example.com/video-$i.mp4',
      title: 'Video $i',
      store: const VideoStore(
        id: 'store-1',
        name: 'Xozmak',
        storeType: 'household',
      ),
      likesCount: 0,
      commentsCount: 0,
      isLiked: false,
      publishedAt: null,
    ),
];

const _rail = VideoProductRail(
  products: [],
  storeType: 'household',
  category: 'Uy jihozlari',
  categoryId: 'category-1',
);

void main() {
  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    required Future<HomeData> Function() fetch,
    List<UserAddress> addresses = const [_defaultAddress],
    Brightness brightness = Brightness.light,
    List<StoreVideo> videos = const [],
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final homeApi = _MockHomeApi();
    when(() => homeApi.fetch()).thenAnswer((_) => fetch());
    final checkoutApi = _MockCheckoutApi();
    final cartApi = _MockCartApi();
    when(() => checkoutApi.fetchAddresses()).thenAnswer((_) async => addresses);
    for (final type in StoreType.values) {
      when(
        () => cartApi.fetch(type.wire),
      ).thenAnswer((_) async => CartData.empty(type.wire));
    }
    final videoApi = _MockVideoApi();
    when(() => videoApi.fetchFeed()).thenAnswer(
      (_) async => CursorPage<StoreVideo>(items: videos, nextUrl: null),
    );
    when(() => videoApi.fetchProducts(any())).thenAnswer((_) async => _rail);

    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        authApiProvider.overrideWithValue(_MockAuthApi()),
        homeApiProvider.overrideWithValue(homeApi),
        recommendationsApiProvider.overrideWithValue(FakeRecommendationsApi()),
        checkoutApiProvider.overrideWithValue(checkoutApi),
        cartApiProvider.overrideWithValue(cartApi),
        videoApiProvider.overrideWithValue(videoApi),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          locale: const Locale('uz'),
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: ThemeData(brightness: brightness),
          home: const HomeScreen(),
        ),
      ),
    );
    return container;
  }

  for (final width in [320.0, 360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('home toolbar fits $width px at $scale scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 850));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpHome(
          tester,
          fetch: () async => const HomeData(banners: [], storeHub: _hub),
          textScale: scale,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('home-main-cart-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-language-button')),
          findsOneWidget,
        );
        final cartRect = tester.getRect(
          find.byKey(const ValueKey('home-main-cart-button')),
        );
        expect(cartRect.size, const Size(48, 48));
        if (scale == 1) {
          final titleRect = tester.getRect(find.text('Besh Kashtan'));
          // Normal phone widths must not push the icons onto a second row.
          expect(cartRect.top, lessThanOrEqualTo(titleRect.bottom));
          expect(cartRect.bottom, greaterThan(titleRect.top));
          expect(titleRect.right, lessThanOrEqualTo(cartRect.left));
        }
      });
    }
  }

  testWidgets('reference tartibi va backend do‘kon matnlari chiziladi', (
    tester,
  ) async {
    await pumpHome(
      tester,
      fetch: () async => const HomeData(banners: [], storeHub: _hub),
    );
    await tester.pumpAndSettle();

    expect(find.text('Besh Kashtan'), findsOneWidget);
    // Guest Home authenticated manzil endpointini yuklamaydi.
    expect(find.text('Manzil tanlanmagan'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-main-cart-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-language-button')), findsOneWidget);
    expect(find.text('Mahsulot qidiring'), findsNothing);
    expect(find.text("DO'KONLAR"), findsOneWidget);
    expect(find.text('06 / 06'), findsOneWidget);
    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.mainAxisSpacing, 16);
    expect(delegate.crossAxisSpacing, 16);
    expect(delegate.childAspectRatio, 0.90);
    expect((grid.childrenDelegate as SliverChildBuilderDelegate).childCount, 6);

    final storeGrid = tester.widget<StoreGrid>(find.byType(StoreGrid));
    expect(storeGrid.items.map((item) => item.storeTypeWire), [
      'household',
      'grocery',
      'shashlik',
      'restaurant',
      'meat',
    ]);

    final storesTitle = tester.widget<Text>(find.text("DO'KONLAR"));
    expect(storesTitle.style?.fontSize, 14);
    expect(storesTitle.style?.fontWeight, FontWeight.w900);

    final xozmakTitle = tester.widget<Text>(find.text('Xozmak'));
    expect(xozmakTitle.style?.fontSize, 13);
    expect(xozmakTitle.style?.fontWeight, FontWeight.w900);

    for (final label in [
      'Xozmak',
      'Ofiyat milliy taomlari',
      'Misqol market',
      'Shashlik marenovka',
      "Go'sht mahsulotlari",
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text("YO'Q TOVARLAR UCHUN ZAKAZ BERISH"), findsOneWidget);
    for (final number in ['01', '02', '03', '04', '05', '06']) {
      expect(find.text(number), findsOneWidget);
    }

    expect(find.text('Uyingizga yetkazib beramiz'), findsNothing);
    expect(find.text("Xo'jalik mollari"), findsNothing);
    expect(find.text('Uy uchun kerakli mahsulotlar'), findsOneWidget);
  });

  testWidgets('headerdagi til tugmasi locale tanlashni ochadi', (tester) async {
    final container = await pumpHome(
      tester,
      fetch: () async => const HomeData(banners: [], storeHub: _hub),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-language-button')));
    await tester.pumpAndSettle();
    expect(find.text("O'zbekcha"), findsOneWidget);
    expect(find.text('Ўзбекча'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);

    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider), AppLocale.ru);
  });

  testWidgets('manzil bo‘lmasa lokalizatsiyalangan fallback chiqadi', (
    tester,
  ) async {
    await pumpHome(
      tester,
      addresses: const [],
      fetch: () async => const HomeData(banners: [], storeHub: _hub),
    );
    await tester.pumpAndSettle();
    expect(find.text('Manzil tanlanmagan'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-address-button')), findsOneWidget);
  });

  testWidgets('request karta oltinchi va do‘kon kartasiga teng o‘lchamda', (
    tester,
  ) async {
    await pumpHome(
      tester,
      fetch: () async => const HomeData(banners: [], storeHub: _hub),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-missing-product-card')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final request = find.byKey(const ValueKey('home-missing-product-card'));
    final meat = find.byKey(const ValueKey('home-store-meat'));
    expect(request, findsOneWidget);
    expect(tester.getSize(request), tester.getSize(meat));
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('home-missing-product-image')),
    );
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/stores/missing_product.webp',
    );
    expect(find.text('Matn'), findsNothing);
    expect(find.text('Rasm'), findsNothing);
    expect(find.text('Ovoz'), findsNothing);
  });

  testWidgets('light theme va home xatosi mustaqil chiziladi', (tester) async {
    await pumpHome(
      tester,
      brightness: Brightness.light,
      fetch: () async => throw Exception('down'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Qayta urinish'), findsOneWidget);
    expect(find.text('Mahsulot qidiring'), findsNothing);
    expect(find.text('Manzil tanlanmagan'), findsOneWidget);
  });

  testWidgets('loading skeleton 2x3 ko‘rinishda oltita karta chizadi', (
    tester,
  ) async {
    final pending = Completer<HomeData>();
    await pumpHome(tester, fetch: () => pending.future);
    await tester.pump();

    expect(find.byType(AspectRatio), findsNWidgets(6));
  });

  testWidgets('360px mobil ekranda 2x3 grid overflow bermaydi', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(
      tester,
      fetch: () async => const HomeData(banners: [], storeHub: _hub),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect((grid.childrenDelegate as SliverChildBuilderDelegate).childCount, 6);
    expect(tester.takeException(), isNull);
  });

  /// Fling tugaguncha kadrma-kadr pump qilib, ko'rsatilgan reel tepasining
  /// ENG KICHIK `dy` qiymatini qaytaradi — ya'ni foydalanuvchi uni qanchalik
  /// "o'tib ketganini" o'lchaydi (manfiy = reel tepadan yuqoriga chiqib ketdi).
  Future<double> pumpFlingTrackingMinTop(
    WidgetTester tester,
    Finder reel,
  ) async {
    var minTop = double.infinity;
    for (var frame = 0; frame < 120; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (reel.evaluate().isNotEmpty) {
        final top = tester.getTopLeft(reel).dy;
        if (top < minTop) minTop = top;
      }
    }
    return minTop;
  }

  /// `pumpAndSettle` bu ekranda ishlamaydi: video kartadagi spinner cheksiz
  /// animatsiya. Spring simulyatsiyasi ~1 s ichida albatta tinchiydi.
  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 75; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> enterReels(WidgetTester tester, Finder scroll) async {
    // Do'konlar qismidan reels'ga: fling 1-reel tepasida to'xtashi kerak.
    await tester.fling(scroll, const Offset(0, -400), 2500);
    await settle(tester);
  }

  testWidgets('har vertikal swipe faqat bitta to‘liq reelga snap qiladi', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = await pumpHome(
      tester,
      videos: _videos,
      fetch: () async => const HomeData(banners: [], storeHub: _hub),
    );
    addTearDown(container.dispose);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final scroll = find.byKey(const PageStorageKey('home-scroll'));
    final first = find.byKey(const ValueKey('home-reel-page-video-1'));
    final second = find.byKey(const ValueKey('home-reel-page-video-2'));

    await enterReels(tester, scroll);
    expect(tester.getSize(first).height, 800);
    expect(tester.getTopLeft(first).dy, closeTo(0, 2));

    await tester.fling(scroll, const Offset(0, -200), 1500);
    await settle(tester);
    expect(tester.getTopLeft(second).dy, closeTo(0, 2));

    await tester.fling(scroll, const Offset(0, 200), 1500);
    await settle(tester);
    expect(tester.getTopLeft(first).dy, closeTo(0, 2));

    // 1-reeldan yuqoriga: Home kontentiga tabiiy qaytish.
    await tester.fling(scroll, const Offset(0, 300), 2500);
    await settle(tester);
    // A taller responsive header can put the first reel outside the lazy
    // viewport entirely. Both cases mean the user has returned to Home.
    if (first.evaluate().isNotEmpty) {
      expect(tester.getTopLeft(first).dy, greaterThan(400));
    }
    expect(find.text('Besh Kashtan').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'juda kuchli fling ham FAQAT bitta reel o‘tadi va orqaga qaytmaydi',
    (tester) async {
      // Shikoyat: qattiq scroll'da 2-3 reel o'tib ketib, keyin orqaga
      // qaytardi (avval ballistik o'tib ketish, so'ng alohida snap
      // animatsiyasi). Endi snap simulyatsiyaning o'zida — bitta sahifa,
      // bitta harakat.
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = await pumpHome(
        tester,
        videos: _manyVideos(6),
        fetch: () async => const HomeData(banners: [], storeHub: _hub),
      );
      addTearDown(container.dispose);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final scroll = find.byKey(const PageStorageKey('home-scroll'));
      final first = find.byKey(const ValueKey('home-reel-page-video-1'));
      final second = find.byKey(const ValueKey('home-reel-page-video-2'));

      await enterReels(tester, scroll);
      expect(tester.getTopLeft(first).dy, closeTo(0, 2));

      // Juda kuchli fling.
      await tester.fling(scroll, const Offset(0, -700), 9000);
      final minSecondTop = await pumpFlingTrackingMinTop(tester, second);
      await settle(tester);

      expect(
        tester.getTopLeft(second).dy,
        closeTo(0, 2),
        reason: 'ikkinchi reel tepada bo\'lishi kerak (uchinchisi emas)',
      );
      // Chegara: sahifaning 1% i. Spring nishonda tinchayotganda bir-ikki
      // pikselga o'tib qaytadi (PageView'da ham shunday) — ko'zga ko'rinmaydi.
      // Tuzatishdan oldin bu qiymat −3279 px edi (4 sahifa o'tib ketardi).
      expect(
        minSecondTop,
        greaterThanOrEqualTo(-8),
        reason:
            'ikkinchi reel tepadan sezilarli o\'tib ketmasligi kerak — '
            'aks holda "o\'tib ketib, orqaga qaytish" bo\'lgan',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reel sahifalari lazy quriladi — uzoqdagilari mounted emas', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = await pumpHome(
      tester,
      videos: _manyVideos(8),
      fetch: () async => const HomeData(banners: [], storeHub: _hub),
    );
    addTearDown(container.dispose);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // 8 ta reel = 6400 px; sahifa boshida faqat ko'rinish + cache
    // oynasidagi reel'lar quriladi, oxirgisi esa yo'q.
    expect(find.byKey(const ValueKey('home-reel-page-video-8')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
