// Deterministic unit tests for LocalDataResetService — the single aggregating
// Factory-reset seam (journey-reset AC-3).
//
// Scope: the drift guard (TC-705), the seam's clear() completeness over the
// canonical key registry, and clear()'s fault isolation (one throwing store
// must not skip the rest, and the aggregate error must surface). The service
// depends only on the LocalDataStore abstraction, so most cases use a tiny
// in-memory FakeLocalDataStore. The canonical-set case wires the REAL
// production registry via `buildResetService` (the SAME factory main.dart uses)
// over a mock shared_preferences (SharedPreferences.setMockInitialValues) so no
// real disk / platform channel is touched, and asserts registeredKeys equals
// the canonical persisted-key set exactly — any new store key added to the real
// factory but not reflected here (or vice versa) fails.
//
// Conventions mirror test/features/journey/data/shared_preferences_journey_repository_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/data/shared_preferences_journey_repository.dart';
import 'package:focus_journey/features/reset/data/reset_service_factory.dart';
import 'package:focus_journey/features/reset/domain/local_data_reset_service.dart';
import 'package:focus_journey/features/reset/domain/local_data_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// THE canonical persisted-key registry the app writes (journey-reset spec
/// "Persisted keys in scope for the full wipe"). This is the single source of
/// truth the drift guard (TC-705) asserts against — NOT a copy of production's
/// store list. The spec names EIGHT conceptual keys; the compact-window position
/// is one of them but is physically stored under TWO shared_preferences keys
/// (`.x` + `.y`), so the string-set the seam clears has NINE members. Editing a
/// store's `ownedKeys` without editing this set — or vice versa — fails the guard.
const Set<String> _canonicalKeys = <String>{
  'app_settings_v1', // stats/settings
  'journey_progress_v1', // journey
  'route_plan_v1', // route (v2 plan)
  'route_selection_v1', // route (legacy v1 — the one most likely forgotten)
  'stats_history_v1', // stats/history
  'earned_badges_v1', // stats/earned-badges
  'mini_window_hide_to_tray_hint_shown_v1', // mini_window: hide-to-tray hint
  'mini_window.compact_position.x', // mini_window: compact position (x)
  'mini_window.compact_position.y', // mini_window: compact position (y)
};

/// A tiny in-memory [LocalDataStore] that records whether clear() ran and over
/// which keys, so the seam's fan-out can be asserted without any I/O.
class FakeLocalDataStore implements LocalDataStore {
  FakeLocalDataStore(this._owned);

  final Set<String> _owned;
  int clearCalls = 0;

  @override
  Set<String> get ownedKeys => _owned;

  @override
  Future<void> clear() async {
    clearCalls++;
  }
}

/// A [LocalDataStore] whose clear() throws, to prove the seam still clears every
/// OTHER store and surfaces an aggregate error (fault isolation).
class ThrowingLocalDataStore implements LocalDataStore {
  ThrowingLocalDataStore(this._owned, this.error);

  final Set<String> _owned;
  final Object error;

  @override
  Set<String> get ownedKeys => _owned;

  @override
  Future<void> clear() async => throw error;
}

/// Builds the reset service via the SAME production factory main.dart uses, over
/// a mock prefs. Consuming `buildResetService` here means the drift guard asserts
/// the REAL registry — a repo wired into a feature but forgotten in the factory
/// cannot pass this test. registeredKeys is the true production union (the
/// compact-window store owns two prefs keys, x/y).
Future<LocalDataResetService> _productionSeam() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return buildResetService(prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDataResetService.registeredKeys — drift guard (TC-705, AC-3)', () {
    test('registeredKeys_overProductionStores_equalsCanonicalKeySet', () async {
      final seam = await _productionSeam();

      // Exact set equality both ways: a store gaining a key that is not added to
      // _canonicalKeys (a later-wave key that would survive Factory reset), or a
      // canonical key whose store is dropped, both fail here.
      expect(seam.registeredKeys, _canonicalKeys);
    });

    test(
      'registeredKeys_explicitlyIncludesLegacyAndBothMiniWindowKeys',
      () async {
        final seam = await _productionSeam();

        // The three most likely to slip (spec call-out): the legacy route key and
        // the two mini_window keys living outside the journey/stats repos.
        expect(
          seam.registeredKeys,
          containsAll(<String>{
            'route_selection_v1',
            'mini_window_hide_to_tray_hint_shown_v1',
            'mini_window.compact_position.x',
            'mini_window.compact_position.y',
          }),
        );
      },
    );

    test('registeredKeys_isUnionOfEveryStoresOwnedKeys', () {
      final a = FakeLocalDataStore(<String>{'k_a'});
      final b = FakeLocalDataStore(<String>{'k_b1', 'k_b2'});
      final seam = LocalDataResetService(<LocalDataStore>[a, b]);

      expect(seam.registeredKeys, <String>{'k_a', 'k_b1', 'k_b2'});
    });
  });

  group('LocalDataResetService.clear — fans out to every store (AC-3)', () {
    test('clear_invokesClearOnEveryRegisteredStoreExactlyOnce', () async {
      final a = FakeLocalDataStore(<String>{'k_a'});
      final b = FakeLocalDataStore(<String>{'k_b'});
      final c = FakeLocalDataStore(<String>{'k_c'});
      final seam = LocalDataResetService(<LocalDataStore>[a, b, c]);

      await seam.clear();

      expect(a.clearCalls, 1);
      expect(b.clearCalls, 1);
      expect(c.clearCalls, 1);
    });

    test('clear_overProductionStores_removesEveryCanonicalKey', () async {
      // Populate every canonical key with a non-empty value, then wipe.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_settings_v1': '{"seen":true}',
        'journey_progress_v1': '{"distanceKm":123.0}',
        'route_plan_v1': '{"orderedNodeIds":["a","b"]}',
        'route_selection_v1': '{"start":"a"}',
        'stats_history_v1': '[]',
        'earned_badges_v1': '{"ids":[]}',
        'mini_window_hide_to_tray_hint_shown_v1': true,
        'mini_window.compact_position.x': 12.0,
        'mini_window.compact_position.y': 34.0,
      });
      final prefs = await SharedPreferences.getInstance();
      final seam = buildResetService(prefs);

      await seam.clear();

      // "Empty" means the key is GONE, not mapped to a zero-ish value.
      for (final key in _canonicalKeys) {
        expect(
          prefs.containsKey(key),
          isFalse,
          reason: 'expected $key to be removed by the full wipe',
        );
      }
      expect(prefs.getKeys(), isEmpty);
    });

    test('clear_leavesUnregisteredKeyUntouched_noBluntPrefsClear', () async {
      // A key NOT owned by any registered store (e.g. a future key that was
      // forgotten) must SURVIVE — proving the seam clears per-registered-key,
      // not a blunt prefs.clear() that would mask the drift guard.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'journey_progress_v1': '{"distanceKm":1.0}',
        'unregistered_future_key_v9': 'still here',
      });
      final prefs = await SharedPreferences.getInstance();
      final seam = LocalDataResetService(<LocalDataStore>[
        SharedPreferencesJourneyRepository(prefs),
      ]);

      await seam.clear();

      expect(prefs.containsKey('journey_progress_v1'), isFalse);
      expect(prefs.getString('unregistered_future_key_v9'), 'still here');
    });
  });

  group('LocalDataResetService.clear — fault isolation (no half-reset)', () {
    test(
      'clear_whenAStoreThrows_stillClearsEveryOtherStore_thenRethrowsAggregate',
      () async {
        // A failing store sits in the MIDDLE, so both the store before AND the
        // stores after it must still be cleared (the exact "store #3 throws so
        // #4-7 never clear" half-reset this feature prevents).
        final before = FakeLocalDataStore(<String>{'k_before'});
        final bad = ThrowingLocalDataStore(<String>{
          'k_bad',
        }, StateError('platform channel failed'));
        final afterA = FakeLocalDataStore(<String>{'k_after_a'});
        final afterB = FakeLocalDataStore(<String>{'k_after_b'});
        final seam = LocalDataResetService(<LocalDataStore>[
          before,
          bad,
          afterA,
          afterB,
        ]);

        // The aggregate error surfaces (never swallowed) so the caller can warn.
        await expectLater(
          seam.clear(),
          throwsA(isA<LocalDataResetException>()),
        );

        // Every non-failing store was still cleared exactly once — max data
        // wiped, no store skipped because an earlier one threw.
        expect(before.clearCalls, 1);
        expect(afterA.clearCalls, 1);
        expect(afterB.clearCalls, 1);
      },
    );

    test('clear_aggregatesEveryStoreFailure_notJustTheFirst', () async {
      final bad1 = ThrowingLocalDataStore(<String>{'b1'}, StateError('one'));
      final ok = FakeLocalDataStore(<String>{'ok'});
      final bad2 = ThrowingLocalDataStore(<String>{'b2'}, StateError('two'));
      final seam = LocalDataResetService(<LocalDataStore>[bad1, ok, bad2]);

      LocalDataResetException? caught;
      try {
        await seam.clear();
      } on LocalDataResetException catch (error) {
        caught = error;
      }

      expect(caught, isNotNull);
      // Both failures are collected (attempted-all, not fail-fast).
      expect(caught!.failures, hasLength(2));
      // ...and the store between the two failures was still cleared.
      expect(ok.clearCalls, 1);
    });
  });

  group('LocalDataResetService.stores — coverage view', () {
    test('stores_reflectsRegisteredStores_readOnly', () {
      final a = FakeLocalDataStore(<String>{'k_a'});
      final seam = LocalDataResetService(<LocalDataStore>[a]);

      expect(seam.stores, hasLength(1));
      expect(
        () => seam.stores.add(FakeLocalDataStore(<String>{'x'})),
        throwsUnsupportedError,
      );
    });
  });
}
