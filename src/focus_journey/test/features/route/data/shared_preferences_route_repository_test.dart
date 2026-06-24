// Focused unit tests for the data-layer SharedPreferencesRouteRepository.
//
// Scope: the RouteRepository contract over the real shared_preferences impl,
// driven by SharedPreferences.setMockInitialValues({}) so there is no real disk
// I/O or platform channel (AC-9/AC-10 / TC-009/TC-010 restore path). Mirrors
// shared_preferences_journey_repository_test.dart exactly: single key, corrupt-
// blob-safe load() → null.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/shared_preferences_route_repository.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double kTol = 1e-6;

const Province muiCaMau = Province(id: 'mui_ca_mau', name: 'Mũi Cà Mau');
const Province canTho = Province(id: 'can_tho', name: 'Cần Thơ');
const Province daLat = Province(id: 'da_lat', name: 'Đà Lạt');
const Province haGiang = Province(id: 'ha_giang', name: 'Hà Giang');

ProvinceChain _chain() => ProvinceChain(
  nodes: const <Province>[muiCaMau, canTho, daLat, haGiang],
  segmentsKm: const <double>[60, 170, 1210],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final chain = _chain();

  group('SharedPreferencesRouteRepository — round-trip (AC-9/AC-10)', () {
    test('load_whenNothingPersisted_returnsNull', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesRouteRepository(prefs, chain);

      expect(await repo.load(), isNull);
    });

    test('saveThenLoad_roundTripsSelection (AC-9)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesRouteRepository(prefs, chain);
      const sel = RouteSelection(
        start: canTho,
        direction: JourneyDirection.towardHaGiang,
        routeStartOffsetKm: 0,
      );

      await repo.save(sel);
      final loaded = await repo.load();

      expect(loaded, isNotNull);
      expect(loaded, sel); // Equatable.
    });

    test('saveThenLoad_preservesCompletedAndOffset (AC-10)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesRouteRepository(prefs, chain);
      const sel = RouteSelection(
        start: daLat,
        direction: JourneyDirection.towardMuiCaMau,
        routeStartOffsetKm: 1500.0,
        completed: true,
      );

      await repo.save(sel);
      final loaded = await repo.load();

      expect(loaded, sel);
      expect(loaded!.completed, isTrue);
      expect(loaded.routeStartOffsetKm, closeTo(1500.0, kTol));
    });

    test('save_overwritesPreviousSelection', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesRouteRepository(prefs, chain);

      await repo.save(
        const RouteSelection(
          start: canTho,
          direction: JourneyDirection.towardHaGiang,
          routeStartOffsetKm: 0,
        ),
      );
      const second = RouteSelection(
        start: daLat,
        direction: JourneyDirection.towardMuiCaMau,
        routeStartOffsetKm: 42,
        completed: true,
      );
      await repo.save(second);

      expect(await repo.load(), second);
    });

    test('usesSingleStableKey_noNewStore (AC-9)', () {
      expect(SharedPreferencesRouteRepository.storageKey, 'route_selection_v1');
    });
  });

  group(
    'SharedPreferencesRouteRepository — corrupt blob never crashes (B-4)',
    () {
      Future<SharedPreferencesRouteRepository> repoWith(String stored) async {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesRouteRepository.storageKey: stored,
        });
        final prefs = await SharedPreferences.getInstance();
        return SharedPreferencesRouteRepository(prefs, chain);
      }

      test('corruptNonJsonString_returnsNull', () async {
        final repo = await repoWith('{not valid json at all');
        expect(await repo.load(), isNull);
      });

      test('nonObjectTopLevelJson_returnsNull', () async {
        final repo = await repoWith('[1, 2, 3]');
        expect(await repo.load(), isNull);
      });

      test('missingRequiredKey_returnsNull', () async {
        final repo = await repoWith(
          '{"direction":"towardHaGiang","routeStartOffsetKm":0,"completed":false}',
        );
        expect(await repo.load(), isNull);
      });

      test('startIdNotInChain_returnsNull', () async {
        final repo = await repoWith(
          '{"startId":"atlantis","direction":"towardHaGiang",'
          '"routeStartOffsetKm":0,"completed":false}',
        );
        expect(await repo.load(), isNull);
      });

      test('unknownDirection_returnsNull', () async {
        final repo = await repoWith(
          '{"startId":"can_tho","direction":"sideways",'
          '"routeStartOffsetKm":0,"completed":false}',
        );
        expect(await repo.load(), isNull);
      });

      test('wrongTypedOffset_returnsNull', () async {
        final repo = await repoWith(
          '{"startId":"can_tho","direction":"towardHaGiang",'
          '"routeStartOffsetKm":"oops","completed":false}',
        );
        expect(await repo.load(), isNull);
      });
    },
  );
}
