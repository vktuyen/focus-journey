// Persistence-integration test for route-progress (TC-009 / TC-010).
//
// Exercises the REAL SharedPreferencesRouteRepository over
// SharedPreferences.setMockInitialValues (no real disk / platform channel),
// then proves a "restart" — a fresh RouteProgressCubit seeded from the reloaded
// blob — restores the saved selection and resolves the current distance against
// it. Mirrors the journey repo/integration pattern.
//
// Covers:
//   TC-009  start + direction persist across an app restart (no new store/key)
//   TC-010  route-completion state persists across an app restart (stays
//           completed, summary available, does not revert / auto-advance)
//
// Runs under `flutter test` (headless) and on a desktop device:
//   fvm flutter test integration_test/route_persistence_test.dart
//   fvm flutter test integration_test/route_persistence_test.dart -d macos

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/shared_preferences_route_repository.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _tol = 1e-6;

ProvinceChain _fixture() => ProvinceChain(
  nodes: const <Province>[
    Province(id: 'mui', name: 'Mũi Cà Mau'),
    Province(id: 'can_tho', name: 'Cần Thơ'),
    Province(id: 'da_lat', name: 'Đà Lạt'),
    Province(id: 'da_nang', name: 'Đà Nẵng'),
    Province(id: 'ha_noi', name: 'Hà Nội'),
    Province(id: 'ha_giang', name: 'Hà Giang'),
  ],
  segmentsKm: const <double>[60, 170, 300, 310, 600],
);

Province _node(ProvinceChain chain, String id) =>
    chain.nodes.firstWhere((p) => p.id == id);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProvinceChain chain;

  setUp(() {
    chain = _fixture();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('TC-009 start + direction persist across restart', () {
    testWidgets('saved selection is restored and resolution matches', (
      tester,
    ) async {
      // --- Session 1: pick Cần Thơ + north and save via the real repo. ---
      final prefs1 = await SharedPreferences.getInstance();
      final repo1 = SharedPreferencesRouteRepository(prefs1, chain);
      final session1 = RouteProgressCubit(chain: chain, repository: repo1);
      addTearDown(session1.close);
      session1.updateFromDistance(400);
      await session1.startNewRoute(
        _node(chain, 'can_tho'),
        JourneyDirection.towardHaGiang,
      );
      final session1Position = session1.state.position!;

      // Persistence used only the existing route key — no new store introduced.
      expect(prefs1.getKeys(), <String>{
        SharedPreferencesRouteRepository.storageKey,
      });

      // --- Session 2 ("relaunch"): fresh repo loads the saved blob. ---
      final prefs2 = await SharedPreferences.getInstance();
      final repo2 = SharedPreferencesRouteRepository(prefs2, chain);
      final restored = await repo2.load();
      expect(restored, isNotNull);
      expect(restored!.start.id, 'can_tho');
      expect(restored.direction, JourneyDirection.towardHaGiang);

      final session2 = RouteProgressCubit(
        chain: chain,
        repository: repo2,
        initialSelection: restored,
      );
      addTearDown(session2.close);
      // Same selection → resolving the same distance gives the same position
      // (the user is never silently reset to a default start/direction).
      session2.updateFromDistance(400);
      expect(session2.state.position, equals(session1Position));
      expect(session2.state.selection!.start.id, 'can_tho');
    });
  });

  group('TC-010 route-completion state persists across restart', () {
    testWidgets('completed route stays completed and does not auto-advance', (
      tester,
    ) async {
      final dest = chain.distanceToDestination(
        _node(chain, 'can_tho'),
        JourneyDirection.towardHaGiang,
      );

      // --- Session 1: reach completion; the cubit latches + persists it. ---
      final prefs1 = await SharedPreferences.getInstance();
      final repo1 = SharedPreferencesRouteRepository(prefs1, chain);
      final session1 = RouteProgressCubit(chain: chain, repository: repo1);
      addTearDown(session1.close);
      await session1.startNewRoute(
        _node(chain, 'can_tho'),
        JourneyDirection.towardHaGiang,
      );
      session1.updateFromDistance(dest); // arrive → completion latched
      // Let the fire-and-forget completion save flush.
      await tester.pump();
      expect(session1.state.isCompleted, isTrue);

      // --- Session 2 ("relaunch"): restore from the persisted completed blob. ---
      final prefs2 = await SharedPreferences.getInstance();
      final repo2 = SharedPreferencesRouteRepository(prefs2, chain);
      final restored = await repo2.load();
      expect(restored, isNotNull);
      expect(restored!.completed, isTrue);

      final session2 = RouteProgressCubit(
        chain: chain,
        repository: repo2,
        initialSelection: restored,
      );
      addTearDown(session2.close);
      // Resolving a still-climbing cumulative does NOT revert to in-progress
      // nor auto-start a new route (terminal until an explicit user choice).
      session2.updateFromDistance(dest + 1000);
      expect(session2.state.isCompleted, isTrue);
      expect(session2.state.position!.next, isNull);
      // % of country is full-chain (decision 3): a mid-chain start (can_tho)
      // completes at the HONEST fraction of Vietnam it crossed — NOT 100% (only
      // a tip-to-tip route reaches 100%). Keyed structurally (dest ÷ totalChainKm)
      // so it survives fixture re-tuning; frozen at the arrival value (terminal,
      // AC-11/AC-13) even though cumulative climbed by +1000.
      expect(
        session2.state.position!.percentOfCountry,
        closeTo(dest / chain.totalChainKm * 100, 1e-3),
      );
      expect(session2.state.position!.fractionAlongRoute, closeTo(1, _tol));
      // Same start/direction — never auto-restarted.
      expect(session2.state.selection!.start.id, 'can_tho');
      expect(
        session2.state.selection!.direction,
        JourneyDirection.towardHaGiang,
      );
    });
  });
}
