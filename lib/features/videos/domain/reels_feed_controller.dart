import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paginated.dart';
import '../data/video_api.dart';
import '../data/video_models.dart';
import 'video_feed_controller.dart';

/// Videolar tabi lentasi: tartib har sessiyada tasodifiy (`?seed=`), lekin
/// bitta seed ichida barqaror — cursor sahifalash to'g'ri ishlaydi.
/// Pull-to-refresh yangi seed oladi (boshqa tartib). Home'ning
/// `videoFeedControllerProvider`idan mustaqil: tab almashganda joy saqlanadi.
final reelsFeedControllerProvider =
    AsyncNotifierProvider<ReelsFeedController, VideoFeedState>(
      ReelsFeedController.new,
    );

class ReelsFeedController extends VideoFeedController {
  ReelsFeedController({int Function()? seedFactory})
    : _seedFactory = seedFactory ?? _randomSeed,
      _seed = (seedFactory ?? _randomSeed)();

  static final _random = Random();

  /// Backend qabul qiladigan oraliq: 1..1_000_000 (`parse_seed`).
  static int _randomSeed() => _random.nextInt(1000000) + 1;

  final int Function() _seedFactory;
  int _seed;

  int get seed => _seed;

  @override
  Future<CursorPage<StoreVideo>> fetchFirstPage(VideoApi api) =>
      api.fetchFeed(seed: _seed);

  @override
  Future<void> refresh() {
    _seed = _seedFactory();
    return super.refresh();
  }
}
