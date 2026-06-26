/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

/// What an [ActivitySegment] represents for accounting and the downstream
/// `map-experience` (#7) red overlay.
///
/// Grace counts as **active/travel** for segments (consistent with
/// grace-stays-travel — `journey-engine` L131–132 / idle-accounting Decision
/// (d)), so a grace span is part of an [active] segment, never [idle].
enum SegmentClassification {
  /// Genuine input (`s ≤ F`) **or** the grace band (`F < s ≤ G`) — the vehicle
  /// is travelling. Distance accrues over this span.
  active,

  /// Past the grace band (`s > G`), screen locked, or sleep-inferred — the
  /// vehicle is stopped. No distance accrues over this span.
  idle,
}

/// Why an [idle][SegmentClassification.idle] segment went idle, so #7 can
/// colour/treat voluntary vs forced idle differently.
enum SegmentCause {
  /// Not an idle segment (an [active][SegmentClassification.active] segment
  /// always carries [none]).
  none,

  /// Voluntary idle ramp: active → grace → idle/paused via rising idle-seconds
  /// crossing the grace band (`s > G`). No lock, no sleep-sized reading.
  voluntary,

  /// Forced idle: the screen was reported locked, or a sleep-sized idle reading
  /// arrived. Onset is the lock/sleep **instant** (immediate, overrides grace).
  lockSleep,
}

/// One ordered, contiguous span of the route with a single classification and
/// cause, keyed by **distance-along-route** (`fromKm` / `toKm`) and timed by
/// duration (`elapsed`).
///
/// **Privacy by construction (NFR-1):** carries ONLY aggregate fields —
/// distance endpoints, an elapsed duration, the classification, and the cause.
/// Never any raw signal, keystroke, mouse coordinate, window title, or input
/// content.
///
/// ## Why both distance AND duration
/// `map-experience` (#7) paints by **position**, so segments are keyed by
/// `fromKm`/`toKm` (cumulative distance at the span's start/end). But an *idle*
/// span accrues **no distance** (`fromKm == toKm`), so distance alone cannot
/// reconstruct the timeline — `elapsed` carries the span's wall-time so the
/// summed durations equal total elapsed (AC-3 / TC-108). The two keys are
/// complementary: distance for spatial painting, duration for time accounting.
class ActivitySegment extends Equatable {
  /// Creates a segment. [fromKm] ≤ [toKm] (distance is monotonic); for an idle
  /// span the two are equal. [elapsed] is the span's wall-time (always ≥ 0).
  const ActivitySegment({
    required this.fromKm,
    required this.toKm,
    required this.elapsed,
    required this.classification,
    required this.cause,
  });

  /// Cumulative distance (km) at the span's start.
  final double fromKm;

  /// Cumulative distance (km) at the span's end. Equals [fromKm] for an idle
  /// span (idle accrues no distance).
  final double toKm;

  /// The span's elapsed wall-time. Summed across all segments this equals the
  /// run's total elapsed time (AC-3 / TC-108).
  final Duration elapsed;

  /// Whether the span is travelling ([active]) or stopped ([idle]).
  final SegmentClassification classification;

  /// Why an idle span went idle ([voluntary] vs [lockSleep]); [none] for active.
  final SegmentCause cause;

  /// A copy with the span extended by [extraElapsed] of wall-time and its end
  /// moved to [newToKm] — used when merging a same-classification, same-cause
  /// tick into the open segment (growth bound, Decision (c)).
  ActivitySegment extendedTo(double newToKm, Duration extraElapsed) =>
      ActivitySegment(
        fromKm: fromKm,
        toKm: newToKm,
        elapsed: elapsed + extraElapsed,
        classification: classification,
        cause: cause,
      );

  /// `true` when [other] has the same classification and cause, so two adjacent
  /// such segments may be merged into one (growth bound, Decision (c)). Distance
  /// and duration never block a merge — only a classification/cause *change*
  /// opens a new segment.
  bool sameKindAs(ActivitySegment other) =>
      classification == other.classification && cause == other.cause;

  /// Serialises to a JSON-compatible map. Distances as doubles; the duration as
  /// integer milliseconds; enums by name. Mirrors [JourneyProgress] conventions.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'fromKm': fromKm,
    'toKm': toKm,
    'elapsedMs': elapsed.inMilliseconds,
    'classification': classification.name,
    'cause': cause.name,
  };

  /// Reconstructs a segment from [toJson]'s output, **degrading safely** so a
  /// corrupt blob never crashes a restore (mirrors [JourneyProgress.fromJson]).
  /// A missing/wrong-typed numeric field throws [FormatException]; an unknown
  /// enum name falls back to a safe default (`idle` / `none`).
  factory ActivitySegment.fromJson(Map<String, dynamic> json) {
    return ActivitySegment(
      fromKm: _readDouble(json['fromKm'], 'fromKm'),
      toKm: _readDouble(json['toKm'], 'toKm'),
      elapsed: Duration(milliseconds: _readInt(json['elapsedMs'], 'elapsedMs')),
      classification: _classificationByName(json['classification'] as String?),
      cause: _causeByName(json['cause'] as String?),
    );
  }

  static double _readDouble(Object? value, String field) {
    if (value is num) {
      return value.toDouble();
    }
    throw FormatException('Field "$field" is missing or not a number', value);
  }

  static int _readInt(Object? value, String field) {
    if (value is int) {
      return value;
    }
    throw FormatException('Field "$field" is missing or not an int', value);
  }

  static SegmentClassification _classificationByName(String? name) {
    for (final value in SegmentClassification.values) {
      if (value.name == name) {
        return value;
      }
    }
    return SegmentClassification.idle;
  }

  static SegmentCause _causeByName(String? name) {
    for (final value in SegmentCause.values) {
      if (value.name == name) {
        return value;
      }
    }
    return SegmentCause.none;
  }

  @override
  List<Object?> get props => <Object?>[
    fromKm,
    toKm,
    elapsed,
    classification,
    cause,
  ];
}
