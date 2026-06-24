// Unit tests for the ProvinceChain geometry — the data-contract guard the
// position-math suite depends on. Covers chain integrity (TC-NF4) and the
// direction-aware helpers (distanceFromStartTo, distanceToDestination,
// destinationOf, checkpointsAhead, isOffDirectionTip) in both directions.
//
// Pure-data tests: no Flutter, no I/O, no timers. Asserts run against BOTH the
// explicit fixture chain (the AC worked example, total 1440) and the production
// vietnamProvinceChain constant (total exactly 2000).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';

const double kTol = 1e-6;

const Province muiCaMau = Province(id: 'mui_ca_mau', name: 'Mũi Cà Mau');
const Province canTho = Province(id: 'can_tho', name: 'Cần Thơ');
const Province daLat = Province(id: 'da_lat', name: 'Đà Lạt');
const Province daNang = Province(id: 'da_nang', name: 'Đà Nẵng');
const Province haNoi = Province(id: 'ha_noi', name: 'Hà Nội');
const Province haGiang = Province(id: 'ha_giang', name: 'Hà Giang');

ProvinceChain _fixtureChain() => ProvinceChain(
  nodes: const <Province>[muiCaMau, canTho, daLat, daNang, haNoi, haGiang],
  segmentsKm: const <double>[60, 170, 300, 310, 600],
);

void main() {
  group('ProvinceChain — constructor validation (TC-NF4)', () {
    test('rejectsFewerThanTwoNodes', () {
      expect(
        () => ProvinceChain(
          nodes: const <Province>[muiCaMau],
          segmentsKm: const <double>[],
        ),
        throwsArgumentError,
      );
    });

    test('rejectsWrongSegmentCount', () {
      expect(
        () => ProvinceChain(
          nodes: const <Province>[muiCaMau, canTho, daLat],
          segmentsKm: const <double>[60], // expected 2
        ),
        throwsArgumentError,
      );
    });

    test('rejectsDuplicateProvinceId', () {
      expect(
        () => ProvinceChain(
          nodes: const <Province>[muiCaMau, muiCaMau],
          segmentsKm: const <double>[60],
        ),
        throwsArgumentError,
      );
    });

    test('rejectsZeroOrNegativeSegment', () {
      expect(
        () => ProvinceChain(
          nodes: const <Province>[muiCaMau, canTho],
          segmentsKm: const <double>[0],
        ),
        throwsArgumentError,
      );
      expect(
        () => ProvinceChain(
          nodes: const <Province>[muiCaMau, canTho],
          segmentsKm: const <double>[-5],
        ),
        throwsArgumentError,
      );
    });
  });

  group('ProvinceChain — fixture integrity (TC-NF4)', () {
    final chain = _fixtureChain();

    test('isStrictlyOrderedSouthTipToNorthTip', () {
      expect(chain.southTip, muiCaMau);
      expect(chain.northTip, haGiang);
      expect(chain.nodes.first, muiCaMau);
      expect(chain.nodes.last, haGiang);
    });

    test('allSegmentsStrictlyPositive', () {
      for (final s in chain.segmentsKm) {
        expect(s, greaterThan(0));
      }
    });

    test('segmentSumEqualsTotalChainKm', () {
      final sum = chain.segmentsKm.fold<double>(0, (a, b) => a + b);
      expect(chain.totalChainKm, closeTo(sum, kTol));
      expect(chain.totalChainKm, closeTo(1440, kTol));
    });
  });

  group('ProvinceChain — production constant integrity (TC-NF4)', () {
    final chain = vietnamProvinceChain;

    test('hasAround10To15Checkpoints', () {
      expect(chain.nodes.length, inInclusiveRange(10, 15));
    });

    test('isStrictlyOrdered_muiCaMauToHaGiang', () {
      expect(chain.southTip.id, 'mui_ca_mau');
      expect(chain.northTip.id, 'ha_giang');
    });

    test('hasNoDuplicateIds', () {
      final ids = chain.nodes.map((p) => p.id).toSet();
      expect(ids.length, chain.nodes.length);
    });

    test('allSegmentsStrictlyPositive', () {
      for (final s in chain.segmentsKm) {
        expect(s, greaterThan(0));
      }
    });

    test('segmentSumEqualsTotalChainKm_exactly2000', () {
      final sum = chain.segmentsKm.fold<double>(0, (a, b) => a + b);
      expect(chain.totalChainKm, closeTo(sum, kTol));
      // Locked decision 2: total is exactly 2000 (÷ ~8h = 250 km/active-hour).
      expect(chain.totalChainKm, closeTo(2000, kTol));
    });

    test('segmentCountIsNodesMinusOne', () {
      expect(chain.segmentsKm.length, chain.nodes.length - 1);
    });
  });

  group('ProvinceChain — destinationOf (AC-8)', () {
    final chain = _fixtureChain();

    test('north_isNorthTip_regardlessOfStart', () {
      expect(
        chain.destinationOf(canTho, JourneyDirection.towardHaGiang),
        haGiang,
      );
      expect(
        chain.destinationOf(daNang, JourneyDirection.towardHaGiang),
        haGiang,
      );
    });

    test('south_isSouthTip_regardlessOfStart', () {
      expect(
        chain.destinationOf(daNang, JourneyDirection.towardMuiCaMau),
        muiCaMau,
      );
      expect(
        chain.destinationOf(haNoi, JourneyDirection.towardMuiCaMau),
        muiCaMau,
      );
    });
  });

  group('ProvinceChain — distanceFromStartTo (both directions)', () {
    final chain = _fixtureChain();

    test('north_aheadIsPositive', () {
      // Cần Thơ (cum 60) → Đà Nẵng (cum 530) = 470.
      expect(
        chain.distanceFromStartTo(
          canTho,
          daNang,
          JourneyDirection.towardHaGiang,
        ),
        closeTo(470, kTol),
      );
    });

    test('north_behindIsNegative', () {
      // Đà Lạt (cum 230) → Cần Thơ (cum 60) heading north = behind = -170.
      expect(
        chain.distanceFromStartTo(
          daLat,
          canTho,
          JourneyDirection.towardHaGiang,
        ),
        closeTo(-170, kTol),
      );
    });

    test('south_aheadIsPositive', () {
      // Đà Nẵng (cum 530) → Đà Lạt (cum 230) heading south = 300.
      expect(
        chain.distanceFromStartTo(
          daNang,
          daLat,
          JourneyDirection.towardMuiCaMau,
        ),
        closeTo(300, kTol),
      );
    });

    test('sameNode_isZero', () {
      expect(
        chain.distanceFromStartTo(daLat, daLat, JourneyDirection.towardHaGiang),
        closeTo(0, kTol),
      );
    });

    test('throwsForNodeNotInChain', () {
      const stranger = Province(id: 'stranger', name: 'Nowhere');
      expect(
        () => chain.distanceFromStartTo(
          stranger,
          canTho,
          JourneyDirection.towardHaGiang,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ProvinceChain — distanceToDestination (structural, AC-11)', () {
    final chain = _fixtureChain();

    test('north_fromCanTho_is1380', () {
      expect(
        chain.distanceToDestination(canTho, JourneyDirection.towardHaGiang),
        closeTo(1380, kTol),
      );
    });

    test('south_fromDaNang_is530', () {
      // Đà Nẵng (cum 530) → Mũi Cà Mau (cum 0) = 530.
      expect(
        chain.distanceToDestination(daNang, JourneyDirection.towardMuiCaMau),
        closeTo(530, kTol),
      );
    });

    test('fromOppositeTip_isFullChainLength', () {
      expect(
        chain.distanceToDestination(muiCaMau, JourneyDirection.towardHaGiang),
        closeTo(chain.totalChainKm, kTol),
      );
    });
  });

  group('ProvinceChain — checkpointsAhead (travel order, both directions)', () {
    final chain = _fixtureChain();

    test('north_excludesStart_endsAtNorthTip', () {
      expect(
        chain.checkpointsAhead(canTho, JourneyDirection.towardHaGiang),
        <Province>[daLat, daNang, haNoi, haGiang],
      );
    });

    test('south_excludesStart_reversedOrder_endsAtSouthTip', () {
      expect(
        chain.checkpointsAhead(daNang, JourneyDirection.towardMuiCaMau),
        <Province>[daLat, canTho, muiCaMau],
      );
    });
  });

  group('ProvinceChain — isOffDirectionTip (AC-15)', () {
    final chain = _fixtureChain();

    test('northTip_headingNorth_isOffDirection', () {
      expect(
        chain.isOffDirectionTip(haGiang, JourneyDirection.towardHaGiang),
        isTrue,
      );
    });

    test('southTip_headingSouth_isOffDirection', () {
      expect(
        chain.isOffDirectionTip(muiCaMau, JourneyDirection.towardMuiCaMau),
        isTrue,
      );
    });

    test('northTip_headingSouth_isValid', () {
      expect(
        chain.isOffDirectionTip(haGiang, JourneyDirection.towardMuiCaMau),
        isFalse,
      );
    });

    test('southTip_headingNorth_isValid', () {
      expect(
        chain.isOffDirectionTip(muiCaMau, JourneyDirection.towardHaGiang),
        isFalse,
      );
    });

    test('midChainNode_neitherDirection_isOffDirection', () {
      expect(
        chain.isOffDirectionTip(daLat, JourneyDirection.towardHaGiang),
        isFalse,
      );
      expect(
        chain.isOffDirectionTip(daLat, JourneyDirection.towardMuiCaMau),
        isFalse,
      );
    });
  });

  group('ProvinceChain — indexOf', () {
    final chain = _fixtureChain();

    test('returnsCanonicalIndex', () {
      expect(chain.indexOf(muiCaMau), 0);
      expect(chain.indexOf(haGiang), chain.nodes.length - 1);
    });

    test('returnsNegativeForUnknownProvince', () {
      const stranger = Province(id: 'stranger', name: 'Nowhere');
      expect(chain.indexOf(stranger), -1);
    });
  });
}
