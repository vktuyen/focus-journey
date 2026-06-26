// Dedicated, exhaustive unit pass for the route-planner-v2 auto-insert /
// sub-chain builder (ADR-0005 decisions 1/2; spec AC-1..AC-5, AC-8, AC-12).
//
// PURE DOMAIN — no Flutter binding, no timers, no DateTime.now(), no I/O, no
// network. Mirrors the route-progress resolver's determinism + ±1e-6 km
// tolerance convention. The smoke pass (route_planner_test.dart) asserts the
// load-bearing shapes; this file pins down direction, span-extend, segment-merge
// exactness, restore determinism, and the static-geography-only reads.
//
// Fixture chain (from map_test_fixtures.dart): mui/can_tho/da_lat/da_nang/
// ha_noi/ha_giang, segments [60,170,300,310,600], total 1440. Cumulative from
// the south tip (mui): 0 / 60 / 230 / 530 / 840 / 1440.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';

import '../map_test_fixtures.dart';

const double _tol = 1e-6;

void main() {
  final chain = buildFixtureChain();
  final geography = buildFixtureGeography(chain);

  Province p(String id) => nodeById(chain, id);

  ResolvedRoute resolve(
    String start,
    String end, {
    List<String> stops = const <String>[],
    Set<String> removed = const <String>{},
  }) => RoutePlanner.resolve(
    fullChain: chain,
    fullGeography: geography,
    start: p(start),
    end: p(end),
    markedStops: <Province>[for (final s in stops) p(s)],
    removedStops: removed,
  );

  group(
    'RoutePlanner.resolve — endpoint selection + spine-order fill (AC-1/AC-3)',
    () {
      test('northBoundEndpoints_resolveContiguousSliceInSpineOrder', () {
        final r = resolve('can_tho', 'da_nang');
        expect(r.orderedNodeIds, <String>['can_tho', 'da_lat', 'da_nang']);
        // Every spine checkpoint between the endpoints, inclusive, none skipped.
        expect(r.subChain.nodes.map((n) => n.id).toList(), <String>[
          'can_tho',
          'da_lat',
          'da_nang',
        ]);
      });

      test('southBoundEndpoints_reverseTravelOrderSameStretch', () {
        final r = resolve('ha_noi', 'da_lat');
        // Travel order runs start → end (Hà Nội → Đà Nẵng → Đà Lạt).
        expect(r.orderedNodeIds, <String>['ha_noi', 'da_nang', 'da_lat']);
        // The materialised sub-chain stays canonical (south→north).
        expect(r.subChain.nodes.map((n) => n.id).toList(), <String>[
          'da_lat',
          'da_nang',
          'ha_noi',
        ]);
        expect(r.subChain.southTip.id, 'da_lat');
        expect(r.subChain.northTip.id, 'ha_noi');
      });

      test('sameStretchOppositeOrder_northAndSouthAreMirrorImages', () {
        final north = resolve('da_lat', 'ha_noi');
        final south = resolve('ha_noi', 'da_lat');
        // Same canonical sub-chain, reversed travel order.
        expect(north.orderedNodeIds, south.orderedNodeIds.reversed.toList());
        expect(north.subPathKm, closeTo(south.subPathKm, _tol));
        expect(north.canonicalOriginKm, closeTo(south.canonicalOriginKm, _tol));
      });

      test('fullSpineEndpoints_resolveEveryCheckpointInclusive', () {
        final r = resolve('mui', 'ha_giang');
        expect(r.orderedNodeIds, <String>[
          'mui',
          'can_tho',
          'da_lat',
          'da_nang',
          'ha_noi',
          'ha_giang',
        ]);
        expect(r.subPathKm, closeTo(1440, _tol));
        expect(r.canonicalOriginKm, closeTo(0, _tol));
      });
    },
  );

  group('RoutePlanner.resolve — subPathKm + canonicalOriginKm (AC-8)', () {
    test('subPathKm_equalsSummedSpineSegmentsBetweenEndpoints', () {
      final r = resolve('can_tho', 'da_nang');
      // 170 (can_tho→da_lat) + 300 (da_lat→da_nang) = 470.
      expect(r.subPathKm, closeTo(470, _tol));
      // And it equals the sub-chain's own totalChainKm by construction.
      expect(r.subPathKm, closeTo(r.subChain.totalChainKm, _tol));
      // The summed segment list equals subPathKm.
      final summed = r.subChain.segmentsKm.fold<double>(0, (a, b) => a + b);
      expect(summed, closeTo(r.subPathKm, _tol));
    });

    test('canonicalOriginKm_isCumulativeKmOfSubPathOriginInFullChain', () {
      // Origin = da_lat → cumulative-from-south-tip = 60 + 170 = 230.
      final r = resolve('da_lat', 'ha_noi');
      expect(r.canonicalOriginKm, closeTo(230, _tol));
    });

    test('canonicalOriginKm_isZeroWhenSubPathStartsAtSouthTip', () {
      final r = resolve('mui', 'da_lat');
      expect(r.canonicalOriginKm, closeTo(0, _tol));
    });

    test('canonicalOriginKm_isSouthMostNodeRegardlessOfTravelDirection', () {
      // South-bound: travel start is ha_noi but the south-most node is da_lat.
      final r = resolve('ha_noi', 'da_lat');
      expect(r.canonicalOriginKm, closeTo(230, _tol));
    });

    test('countryPercentInputs_originPlusSubPathReachesFullChainEnd', () {
      // canonicalOriginKm + subPathKm of a full-spine route == totalChainKm.
      final r = resolve('mui', 'ha_giang');
      expect(r.canonicalOriginKm + r.subPathKm, closeTo(1440, _tol));
      // And a mid-spine route's origin + length lands on its end's cumulative.
      final mid = resolve('can_tho', 'da_nang');
      expect(mid.canonicalOriginKm + mid.subPathKm, closeTo(530, _tol));
    });
  });

  group('RoutePlanner.resolve — minimum / start==end (AC-2)', () {
    test('startEqualsEnd_throwsArgumentError', () {
      expect(() => resolve('da_lat', 'da_lat'), throwsArgumentError);
    });

    test('adjacentEndpoints_resolveTwoNodeRouteWithNoIntermediate', () {
      final r = resolve('mui', 'can_tho');
      expect(r.orderedNodeIds, <String>['mui', 'can_tho']);
      expect(r.subChain.nodes.length, 2);
      // subPathKm == the single inter-node distance.
      expect(r.subPathKm, closeTo(60, _tol));
      expect(r.subChain.segmentsKm.single, closeTo(60, _tol));
    });

    test('startNotInChain_throwsArgumentError', () {
      expect(
        () => RoutePlanner.resolve(
          fullChain: chain,
          fullGeography: geography,
          start: const Province(id: 'mars', name: 'Mars'),
          end: p('da_lat'),
        ),
        throwsArgumentError,
      );
    });

    test('endNotInChain_throwsArgumentError', () {
      expect(
        () => RoutePlanner.resolve(
          fullChain: chain,
          fullGeography: geography,
          start: p('da_lat'),
          end: const Province(id: 'mars', name: 'Mars'),
        ),
        throwsArgumentError,
      );
    });
  });

  group(
    'RoutePlanner.resolve — marked stops extend / preserve span (AC-4)',
    () {
      test('stopBeyondNorthEnd_extendsSpanNorthToTheStop', () {
        // can_tho → da_lat, stop ha_noi (north of da_lat) extends to ha_noi.
        final r = resolve('can_tho', 'da_lat', stops: <String>['ha_noi']);
        expect(r.orderedNodeIds, <String>[
          'can_tho',
          'da_lat',
          'da_nang',
          'ha_noi',
        ]);
        // 170 + 300 + 310 = 780.
        expect(r.subPathKm, closeTo(780, _tol));
      });

      test('stopBeyondSouthEnd_extendsSpanSouthToTheStop', () {
        // da_lat → da_nang (north-bound), stop mui is south of da_lat: the span
        // extends south to mui, and the new south-most extreme is mui. Travel
        // order still runs from the chosen start direction (ascending here).
        final r = resolve('da_lat', 'da_nang', stops: <String>['mui']);
        expect(r.orderedNodeIds, <String>[
          'mui',
          'can_tho',
          'da_lat',
          'da_nang',
        ]);
        expect(r.canonicalOriginKm, closeTo(0, _tol));
        // 60 + 170 + 300 = 530.
        expect(r.subPathKm, closeTo(530, _tol));
      });

      test('stopInsideSpan_leavesRouteUnchanged', () {
        // can_tho → ha_noi already auto-fills da_lat, da_nang; marking da_nang
        // (in-span) changes nothing.
        final without = resolve('can_tho', 'ha_noi');
        final with_ = resolve('can_tho', 'ha_noi', stops: <String>['da_nang']);
        expect(with_.orderedNodeIds, without.orderedNodeIds);
        expect(with_.subPathKm, closeTo(without.subPathKm, _tol));
      });

      test('multipleOutOfSpanStops_extendToTheUnionMinMax', () {
        // da_lat → da_nang, stops mui (far south) + ha_giang (far north): span
        // becomes the whole spine.
        final r = resolve(
          'da_lat',
          'da_nang',
          stops: <String>['mui', 'ha_giang'],
        );
        expect(r.orderedNodeIds, <String>[
          'mui',
          'can_tho',
          'da_lat',
          'da_nang',
          'ha_noi',
          'ha_giang',
        ]);
        expect(r.subPathKm, closeTo(1440, _tol));
      });

      test('stopNotInChain_throwsArgumentError', () {
        expect(
          () => RoutePlanner.resolve(
            fullChain: chain,
            fullGeography: geography,
            start: p('can_tho'),
            end: p('da_nang'),
            markedStops: const <Province>[Province(id: 'mars', name: 'Mars')],
          ),
          throwsArgumentError,
        );
      });
    },
  );

  group('RoutePlanner.resolve — interior removal merges segments (AC-5)', () {
    test('removeInteriorNode_mergesAdjacentSegmentsPreservingSubPathKm', () {
      final full = resolve('can_tho', 'da_nang'); // 470 km, 3 nodes.
      final pruned = resolve('can_tho', 'da_nang', removed: <String>{'da_lat'});
      expect(pruned.orderedNodeIds, <String>['can_tho', 'da_nang']);
      // The two legs (170 + 300) merge into one 470 km leg — exact.
      expect(pruned.subChain.segmentsKm.single, closeTo(470, _tol));
      // Total distance is preserved EXACTLY across the merge (±1e-6).
      expect(pruned.subPathKm, closeTo(full.subPathKm, _tol));
    });

    test('removeOneOfTwoInteriors_survivingNeighbourBecomesAdjacent', () {
      // mui → ha_noi has interiors can_tho, da_lat, da_nang. Remove da_lat.
      final pruned = resolve('mui', 'ha_noi', removed: <String>{'da_lat'});
      expect(pruned.orderedNodeIds, <String>[
        'mui',
        'can_tho',
        'da_nang',
        'ha_noi',
      ]);
      // can_tho → da_nang merged leg = 170 + 300 = 470.
      final legs = pruned.subChain.segmentsKm;
      expect(legs[0], closeTo(60, _tol)); // mui → can_tho
      expect(legs[1], closeTo(470, _tol)); // can_tho → da_nang (merged)
      expect(legs[2], closeTo(310, _tol)); // da_nang → ha_noi
      // Full spine slice subPathKm preserved: 60+170+300+310 = 840.
      expect(pruned.subPathKm, closeTo(840, _tol));
    });

    test('removeMultipleInteriors_subPathKmStillExact', () {
      final full = resolve('mui', 'ha_giang'); // 1440 km full spine.
      final pruned = resolve(
        'mui',
        'ha_giang',
        removed: <String>{'can_tho', 'da_lat', 'da_nang', 'ha_noi'},
      );
      expect(pruned.orderedNodeIds, <String>['mui', 'ha_giang']);
      expect(pruned.subPathKm, closeTo(full.subPathKm, _tol));
      expect(pruned.subChain.segmentsKm.single, closeTo(1440, _tol));
    });

    test('removeEndpoints_ignoredEndpointsAreNeverRemovable', () {
      final r = resolve(
        'can_tho',
        'da_nang',
        removed: <String>{'can_tho', 'da_nang', 'da_lat'},
      );
      // The two endpoints survive (2-node minimum); only da_lat is dropped.
      expect(r.orderedNodeIds, <String>['can_tho', 'da_nang']);
      expect(r.subChain.nodes.length, 2);
    });

    test('removeMarkedStop_protectedFromRemoval', () {
      // da_lat is both auto-inserted AND marked: removal request is ignored.
      final r = resolve(
        'can_tho',
        'da_nang',
        stops: <String>['da_lat'],
        removed: <String>{'da_lat'},
      );
      expect(r.orderedNodeIds, <String>['can_tho', 'da_lat', 'da_nang']);
    });

    test('removeNonexistentInteriorId_isNoOp', () {
      final r = resolve('can_tho', 'da_nang', removed: <String>{'mars'});
      expect(r.orderedNodeIds, <String>['can_tho', 'da_lat', 'da_nang']);
      expect(r.subPathKm, closeTo(470, _tol));
    });
  });

  group(
    'RoutePlanner.resolve — determinism + static-only reads (AC-3/AC-12)',
    () {
      test('resolvingIdenticalInputsTwice_yieldsEqualResults', () {
        final a = resolve('can_tho', 'ha_noi');
        final b = resolve('can_tho', 'ha_noi');
        expect(a.orderedNodeIds, b.orderedNodeIds);
        expect(a.subPathKm, closeTo(b.subPathKm, _tol));
        expect(a.canonicalOriginKm, closeTo(b.canonicalOriginKm, _tol));
        expect(a.subChain.segmentsKm, b.subChain.segmentsKm);
      });

      test('subGeography_reusesFullGeographyCoordinatesUnchanged', () {
        final r = resolve('can_tho', 'da_nang');
        for (final node in r.subChain.nodes) {
          expect(
            r.subGeography.coordinateOf(node),
            geography.coordinateOf(node),
            reason:
                'sub-geography must reuse the static coordinate, not invent one',
          );
        }
      });

      test('subGeographyCoordinates_areInCanonicalSubChainOrder', () {
        final r = resolve('ha_noi', 'da_lat'); // south-bound
        expect(r.subGeography.canonicalCoordinates, <Object>[
          geography.coordinateOf(p('da_lat')),
          geography.coordinateOf(p('da_nang')),
          geography.coordinateOf(p('ha_noi')),
        ]);
      });
    },
  );

  group('RoutePlanner.fromOrderedIds — deterministic rebuild (AC-12)', () {
    test('rebuildsIdenticalSubChainFromPersistedIdList_northBound', () {
      final resolved = resolve('can_tho', 'da_nang');
      final rebuilt = RoutePlanner.fromOrderedIds(
        fullChain: chain,
        fullGeography: geography,
        orderedNodeIds: resolved.orderedNodeIds,
      );
      expect(rebuilt.orderedNodeIds, resolved.orderedNodeIds);
      expect(rebuilt.subPathKm, closeTo(resolved.subPathKm, _tol));
      expect(
        rebuilt.canonicalOriginKm,
        closeTo(resolved.canonicalOriginKm, _tol),
      );
      expect(
        rebuilt.subChain.nodes.map((n) => n.id).toList(),
        resolved.subChain.nodes.map((n) => n.id).toList(),
      );
      expect(rebuilt.subChain.segmentsKm, resolved.subChain.segmentsKm);
    });

    test('rebuildsIdenticalSubChain_southBound', () {
      final resolved = resolve('da_nang', 'can_tho'); // south-bound
      final rebuilt = RoutePlanner.fromOrderedIds(
        fullChain: chain,
        fullGeography: geography,
        orderedNodeIds: resolved.orderedNodeIds,
      );
      expect(rebuilt.orderedNodeIds, <String>['da_nang', 'da_lat', 'can_tho']);
      expect(rebuilt.subChain.southTip.id, 'can_tho');
      expect(rebuilt.subPathKm, closeTo(resolved.subPathKm, _tol));
      expect(
        rebuilt.canonicalOriginKm,
        closeTo(resolved.canonicalOriginKm, _tol),
      );
    });

    test('rebuildsMergedSubPath_afterInteriorRemoval', () {
      // A persisted post-edit list (da_lat removed) rebuilds the merged leg.
      final pruned = resolve('mui', 'ha_noi', removed: <String>{'da_lat'});
      final rebuilt = RoutePlanner.fromOrderedIds(
        fullChain: chain,
        fullGeography: geography,
        orderedNodeIds: pruned.orderedNodeIds,
      );
      expect(rebuilt.orderedNodeIds, pruned.orderedNodeIds);
      expect(rebuilt.subPathKm, closeTo(pruned.subPathKm, _tol));
      expect(rebuilt.subChain.segmentsKm, pruned.subChain.segmentsKm);
    });

    test('fewerThanTwoIds_throwsArgumentError', () {
      expect(
        () => RoutePlanner.fromOrderedIds(
          fullChain: chain,
          fullGeography: geography,
          orderedNodeIds: const <String>['can_tho'],
        ),
        throwsArgumentError,
      );
    });

    test('idNotInChain_throwsArgumentError', () {
      expect(
        () => RoutePlanner.fromOrderedIds(
          fullChain: chain,
          fullGeography: geography,
          orderedNodeIds: const <String>['can_tho', 'mars'],
        ),
        throwsArgumentError,
      );
    });

    test('nonMonotonicIdList_throwsArgumentError', () {
      expect(
        () => RoutePlanner.fromOrderedIds(
          fullChain: chain,
          fullGeography: geography,
          orderedNodeIds: const <String>['can_tho', 'da_nang', 'da_lat'],
        ),
        throwsArgumentError,
      );
    });

    test('rebuildIsIdempotent_acrossRepeatedRestores', () {
      final ids = resolve('mui', 'ha_giang').orderedNodeIds;
      final once = RoutePlanner.fromOrderedIds(
        fullChain: chain,
        fullGeography: geography,
        orderedNodeIds: ids,
      );
      final twice = RoutePlanner.fromOrderedIds(
        fullChain: chain,
        fullGeography: geography,
        orderedNodeIds: once.orderedNodeIds,
      );
      expect(twice.orderedNodeIds, once.orderedNodeIds);
      expect(twice.subPathKm, closeTo(once.subPathKm, _tol));
      expect(twice.subChain.segmentsKm, once.subChain.segmentsKm);
    });
  });
}
