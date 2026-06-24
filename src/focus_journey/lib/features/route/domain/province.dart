/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

/// A single checkpoint on the Vietnam province chain.
///
/// A value object identified by its stable [id] (used for persistence /
/// equality); [name] is the human-facing label drawn on the map. The chain
/// itself ([ProvinceChain]) owns ordering and inter-province distances — a
/// [Province] carries no position of its own, so it can be reused across runs
/// and compared by identity (mirrors the `JourneyProgress` value-object style).
class Province extends Equatable {
  /// Creates a province checkpoint with a stable [id] and display [name].
  const Province({required this.id, required this.name});

  /// Stable identifier, persisted in the [RouteSelection] JSON. Never localised.
  final String id;

  /// Human-facing display name (may contain Vietnamese diacritics).
  final String name;

  @override
  List<Object?> get props => <Object?>[id, name];

  @override
  String toString() => 'Province($id)';
}
