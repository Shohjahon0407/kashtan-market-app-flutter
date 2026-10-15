import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';

/// One switch for checkout, order actions and payment initiation.
/// Existing order payment/status data remains unchanged.
final paymeEnabledProvider = Provider<bool>((_) => AppConfig.paymeEnabled);
