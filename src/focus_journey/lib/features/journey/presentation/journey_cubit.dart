/// Presentation layer. The Bloc (Cubit) that adapts `JourneyEngine` output into
/// the flattened [JourneyViewState] the journey screen renders.
///
/// SEPARATION INVARIANT (AC-9/AC-10/TC-009/TC-010): this Cubit reads ONLY the
/// engine's already-decided `state`/`mode`/`distanceKm`. It performs NO activity
/// decision, reads NO OS signal, touches NO platform channel, and never mutates
/// journey state. It imports neither `ActivityPlugin` nor any `MethodChannel`.
/// (It does take a `JourneyEngine` reference to *read* its getters — the engine
/// is pure domain and owns all the activity/distance logic.) The app-layer
/// `ActivityTicker` is what drives this Cubit; the Cubit itself only maps.
///
/// A Cubit (not an event-Bloc) so tests can construct it and drive deterministic
/// snapshots directly (per the test-case conventions — a scriptable cubit/fake).
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/journey_engine.dart';
import 'journey_view_state.dart';

/// Emits [JourneyViewState] snapshots for the journey screen.
///
/// Starts at [JourneyViewState.initial] (parked, no overlay — AC-13). Call
/// [updateFromEngine] after each engine tick to publish the latest snapshot.
class JourneyCubit extends Cubit<JourneyViewState> {
  /// Creates the cubit in its pre-state parked default.
  JourneyCubit() : super(const JourneyViewState.initial());

  /// Reads the engine's current `state`/`mode`/`distanceKm`/`idleTimeToday` and
  /// emits the mapped view (TC-005/TC-021). Pure read — never writes to the
  /// engine.
  ///
  /// idle-accounting AC-2: the emitted [JourneyViewState.idleTimeToday] is the
  /// engine's `idleTimeToday` accumulator read VERBATIM — no independent
  /// rounding/smoothing — so the displayed idle counter and the engine's
  /// accounting agree with divergence 0 (Option B anchors both to the same
  /// stamped value).
  void updateFromEngine(JourneyEngine engine) {
    emit(
      JourneyViewState.fromEngine(
        engine.state,
        engine.mode,
        engine.distanceKm,
        idleTimeToday: engine.idleTimeToday,
      ),
    );
  }
}
