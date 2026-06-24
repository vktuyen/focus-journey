/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'app_settings.dart';
import 'day_stats.dart';
import 'earned_badges.dart';

/// Persistence seam for [AppSettings]. The Cubits depend on this interface
/// (dependency inversion) — the `shared_preferences`+JSON impl lives in `data/`
/// (AC-9 / NF Clean-Architecture). Swapping a real ↔ in-memory fake requires no
/// Cubit change.
abstract interface class SettingsRepository {
  /// Loads persisted settings, or `null` if none saved yet (use defaults).
  Future<AppSettings?> load();

  /// Persists [settings], overwriting any previous value.
  Future<void> save(AppSettings settings);
}

/// Persistence seam for the bounded per-day history store (AC-5/AC-6/AC-7).
abstract interface class HistoryRepository {
  /// Loads the persisted history (newest-last ordering not guaranteed; the
  /// caller sorts), or an empty list if none saved.
  Future<List<DayStats>> load();

  /// Persists the whole [history] list, overwriting the previous blob. The
  /// caller is responsible for bounding/pruning before calling (AC-6).
  Future<void> save(List<DayStats> history);
}

/// Persistence seam for the earned-badge store (AC-13/AC-18).
abstract interface class EarnedBadgesRepository {
  /// Loads persisted earned-badge state, or `null` if none saved (start empty).
  Future<EarnedBadges?> load();

  /// Persists [earned], overwriting any previous value.
  Future<void> save(EarnedBadges earned);
}

/// OS "open at login" seam (AC-10), backed by the `launch_at_startup` package in
/// `data/`. The settings Cubit depends only on this interface and is tested
/// against an in-memory fake — no real OS registration in automated tests.
///
/// **Privacy:** exposes only get/set of the open-at-login flag — no capability
/// to read input/screen/files/network (AC-21).
abstract interface class StartupController {
  /// Reads the **actual** current OS open-at-login state (AC-10).
  Future<bool> isEnabled();

  /// Enables or disables OS open-at-login to match [enabled] (AC-10).
  Future<void> setEnabled(bool enabled);
}

/// Local OS-toast seam (AC-11/AC-12), backed by the `local_notifier` package in
/// `data/`. **Local toasts only — no network, no push** (NF No network). The
/// notification logic depends only on this interface; tests use a fake that
/// records toast requests.
abstract interface class Notifier {
  /// Shows a local OS toast announcing a newly-earned badge (AC-12).
  Future<void> showBadgeEarned({
    required String title,
    required String description,
  });

  /// Shows a local OS toast nudging the user to keep their focus streak (AC-12).
  Future<void> showStreakReminder({
    required String title,
    required String body,
  });
}
