// Deterministic unit tests for the pure ActivitySegment value object.
//
// Scope: the segment record's shape, merge eligibility, extension, boundary
// ownership, and JSON round-trip — no engine, no Flutter, no timers. Backs the
// idle-accounting AC-3/AC-4 segment contract and the NFR-1 aggregate-only shape
// (tests/cases/idle-accounting.md TC-112/TC-114).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';

void main() {
  group('ActivitySegment — aggregate-only shape (NFR-1, TC-112)', () {
    test('jsonKeys_areOnlyAggregateFields_noInputContent', () {
      const segment = ActivitySegment(
        fromKm: 1.5,
        toKm: 3.0,
        elapsed: Duration(minutes: 2),
        classification: SegmentClassification.active,
        cause: SegmentCause.none,
      );

      final json = segment.toJson();

      // Exactly the five aggregate fields — no keystrokes, mouse coords,
      // window titles, or any raw signal.
      expect(json.keys.toSet(), <String>{
        'fromKm',
        'toKm',
        'elapsedMs',
        'classification',
        'cause',
      });
    });
  });

  group('ActivitySegment — merge eligibility (Decision (c), TC-118)', () {
    test('sameClassificationAndCause_areMergeable', () {
      const a = ActivitySegment(
        fromKm: 0,
        toKm: 1,
        elapsed: Duration(minutes: 1),
        classification: SegmentClassification.idle,
        cause: SegmentCause.voluntary,
      );
      const b = ActivitySegment(
        fromKm: 1,
        toKm: 1,
        elapsed: Duration(minutes: 1),
        classification: SegmentClassification.idle,
        cause: SegmentCause.voluntary,
      );

      expect(a.sameKindAs(b), isTrue);
    });

    test('differentClassification_orCause_areNotMergeable', () {
      const active = ActivitySegment(
        fromKm: 0,
        toKm: 1,
        elapsed: Duration(minutes: 1),
        classification: SegmentClassification.active,
        cause: SegmentCause.none,
      );
      const voluntaryIdle = ActivitySegment(
        fromKm: 1,
        toKm: 1,
        elapsed: Duration(minutes: 1),
        classification: SegmentClassification.idle,
        cause: SegmentCause.voluntary,
      );
      const lockIdle = ActivitySegment(
        fromKm: 1,
        toKm: 1,
        elapsed: Duration(minutes: 1),
        classification: SegmentClassification.idle,
        cause: SegmentCause.lockSleep,
      );

      expect(active.sameKindAs(voluntaryIdle), isFalse);
      expect(voluntaryIdle.sameKindAs(lockIdle), isFalse);
    });
  });

  group('ActivitySegment — extendedTo (growth bound, TC-118)', () {
    test('extendedTo_movesEnd_addsElapsed_keepsStartClassificationCause', () {
      const segment = ActivitySegment(
        fromKm: 2,
        toKm: 5,
        elapsed: Duration(minutes: 3),
        classification: SegmentClassification.active,
        cause: SegmentCause.none,
      );

      final extended = segment.extendedTo(8, const Duration(minutes: 2));

      expect(extended.fromKm, 2);
      expect(extended.toKm, 8);
      expect(extended.elapsed, const Duration(minutes: 5));
      expect(extended.classification, SegmentClassification.active);
      expect(extended.cause, SegmentCause.none);
    });
  });

  group('ActivitySegment — JSON round-trip (persistence, TC-119)', () {
    test('toJson_then_fromJson_isLossless', () {
      const segment = ActivitySegment(
        fromKm: 12.25,
        toKm: 12.25,
        elapsed: Duration(seconds: 90),
        classification: SegmentClassification.idle,
        cause: SegmentCause.lockSleep,
      );

      final restored = ActivitySegment.fromJson(segment.toJson());

      expect(restored, segment);
    });

    test('fromJson_unknownEnumNames_degradeToSafeDefaults', () {
      final restored = ActivitySegment.fromJson(<String, dynamic>{
        'fromKm': 1.0,
        'toKm': 1.0,
        'elapsedMs': 1000,
        'classification': 'bogus',
        'cause': 'bogus',
      });

      expect(restored.classification, SegmentClassification.idle);
      expect(restored.cause, SegmentCause.none);
    });

    test('fromJson_missingNumericField_throwsFormatException', () {
      expect(
        () => ActivitySegment.fromJson(<String, dynamic>{
          'toKm': 1.0,
          'elapsedMs': 1000,
          'classification': 'active',
          'cause': 'none',
        }),
        throwsFormatException,
      );
    });
  });
}
