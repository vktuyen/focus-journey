// Shared test fixtures + doubles for the route-progress automation layers
// (cubit-wiring, widget, persistence-integration, wiring-smoke). Keyed off the
// ACs' worked-example FIXTURE chain (segments [60,170,300,310,600], total
// 1440 km — Đà Nẵng = 470 km, Hà Giang = 1380 km from Cần Thơ's start),
// corrected 2026-06-24. Tests assert against the fixture's *structure*, with the
// literals shown as the worked illustration.
//
// No timers, no DateTime.now(), no real I/O — every double here is deterministic.

import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/route_repository.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';

/// Float tolerance for distance / percentage assertions (±1e-6).
const double kTol = 1e-6;

/// The ACs' worked-example fixture chain (south tip → north tip).
/// Cumulative-from-Mũi: 0 / 60 / 230 / 530 / 840 / 1440.
ProvinceChain buildFixtureChain() => ProvinceChain(
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

/// Looks up a fixture node by its stable id.
Province nodeById(ProvinceChain chain, String id) =>
    chain.nodes.firstWhere((p) => p.id == id);

/// Convenience constructor for a validated selection over [chain].
RouteSelection selection(
  ProvinceChain chain,
  String startId,
  JourneyDirection direction, {
  double offset = 0,
}) => RouteSelection.create(
  start: nodeById(chain, startId),
  direction: direction,
  routeStartOffsetKm: offset,
  chain: chain,
);

/// An in-memory [RouteRepository] fake that **records every write** so tests can
/// assert the engine is never reset and route-progress writes only its own
/// selection (TC-012 / TC-014 / TC-017). Also serves the restart cases (TC-009 /
/// TC-010) by replaying its last saved selection on [load].
class RecordingRouteRepository implements RouteRepository {
  RecordingRouteRepository({RouteSelection? seed}) : _stored = seed;

  RouteSelection? _stored;

  /// Every selection passed to [save], in order — the write log.
  final List<RouteSelection> saves = <RouteSelection>[];

  /// Number of recorded [save] calls.
  int get saveCount => saves.length;

  @override
  Future<RouteSelection?> load() async => _stored;

  @override
  Future<void> save(RouteSelection selection) async {
    saves.add(selection);
    _stored = selection;
  }
}
