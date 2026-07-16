/// Data layer — the composition helper that builds the ONE production
/// [LocalDataResetService] over EVERY persisted `shared_preferences`-backed
/// store (journey-reset AC-3 / TC-704/TC-705).
///
/// This is the SINGLE source of the reset registry: `main.dart` and the
/// drift-guard test both call [buildResetService], so the store list can never
/// silently diverge between production wiring and the test that asserts the
/// canonical key set. A new persisted key added in a later wave must be
/// registered HERE (its repo added to the list) or Factory reset misses it —
/// and TC-705 fails, because the test asserts against exactly this construction.
///
/// PRIVACY (NFR-2 / BR-1): every store here only DELETES local data; none reads
/// a new OS/idle/screen/clipboard/file/location signal and none makes a network
/// call.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../journey/data/shared_preferences_journey_repository.dart';
import '../../mini_window/data/shared_preferences_compact_window_position_repository.dart';
import '../../mini_window/data/shared_preferences_hide_to_tray_hint_repository.dart';
import '../../route/data/shared_preferences_route_repository.dart';
import '../../route/domain/province_chain.dart';
import '../../stats/data/shared_preferences_earned_badges_repository.dart';
import '../../stats/data/shared_preferences_history_repository.dart';
import '../../stats/data/shared_preferences_settings_repository.dart';
import '../domain/local_data_reset_service.dart';
import '../domain/local_data_store.dart';

/// Builds the aggregating Factory-reset seam over every production store, all
/// sharing the one [prefs] instance so a wipe over any of them is visible to the
/// whole app. The route repository's geography defaults to the production
/// geography (the reset path only needs to enumerate/clear its keys).
///
/// The order is stable (deterministic wipe) but irrelevant to correctness —
/// each store owns a disjoint key set, and [LocalDataResetService.clear]
/// attempts every store regardless of an earlier failure.
LocalDataResetService buildResetService(SharedPreferences prefs) {
  return LocalDataResetService(<LocalDataStore>[
    SharedPreferencesJourneyRepository(prefs),
    SharedPreferencesRouteRepository(prefs, vietnamProvinceChain),
    SharedPreferencesSettingsRepository(prefs),
    SharedPreferencesHistoryRepository(prefs),
    SharedPreferencesEarnedBadgesRepository(prefs),
    SharedPreferencesCompactWindowPositionRepository(prefs),
    SharedPreferencesHideToTrayHintRepository(prefs),
  ]);
}
