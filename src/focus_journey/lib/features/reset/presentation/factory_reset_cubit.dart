/// Presentation layer. The Cubit that runs a confirmed Factory reset: wipe all
/// local data via the injected [LocalDataResetService], then re-initialise the
/// in-memory app graph to zero via the injected [onReinitialise] seam (AC-4).
///
/// SEPARATION / DI: it holds NO engine, ticker, or repository directly — only the
/// domain reset service (dependency inversion) and a plain re-init callback the
/// composition root wires to its bootstrap path. It reads no OS signal and makes
/// no network call — it only deletes local data (NFR-2 / BR-1).
///
/// The DESTRUCTIVE CONFIRMATION is a widget concern (the dialog). This cubit is
/// the post-confirm action ONLY: callers must invoke [confirmReset] strictly
/// after an affirmative confirm, so a cancelled/dismissed dialog touches no data
/// (AC-2 / TC-701/TC-702).
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/local_data_reset_service.dart';

/// The status of a Factory reset (mostly for test observability; the wipe is
/// fast enough that no spinner is required — NFR-1).
enum FactoryResetStatus {
  /// No reset has run (or the previous one finished and the graph rebuilt).
  idle,

  /// A wipe + re-init is in flight.
  resetting,

  /// The wipe did not fully succeed (one or more stores failed to clear). The
  /// graph was STILL re-initialised (the app is never wedged), so this is a
  /// terminal state the UI surfaces so a partial wipe is never silent.
  failed,
}

/// Runs the confirmed Factory reset.
class FactoryResetCubit extends Cubit<FactoryResetStatus> {
  /// Creates the cubit over the [service] (the aggregating wipe seam) plus two
  /// composition-root seams that bound the wipe:
  /// - [onQuiesce] tears down the LIVE in-memory graph (stops the ticker + closes
  ///   the Blocs) so nothing can re-persist while/after the disk is cleared;
  /// - [onReinitialise] rebuilds the graph to a ZERO state from the now-empty
  ///   persistence (the bootstrap path).
  FactoryResetCubit({
    required LocalDataResetService service,
    required Future<void> Function() onQuiesce,
    required Future<void> Function() onReinitialise,
  }) : _service = service,
       _onQuiesce = onQuiesce,
       _onReinitialise = onReinitialise,
       super(FactoryResetStatus.idle);

  final LocalDataResetService _service;
  final Future<void> Function() _onQuiesce;
  final Future<void> Function() _onReinitialise;

  /// Wipes ALL local data and re-initialises the in-memory graph to zero
  /// (AC-3/AC-4). ORDER IS THE CORRECTNESS-CRITICAL PART (TC-706):
  ///
  ///  1. **Quiesce** — tear down the live engine/ticker/Blocs FIRST, so the old
  ///     ticker cannot fire an autosave that re-persists stale state during the
  ///     wipe (the disk-clear awaits a platform channel, which yields to the
  ///     event loop where a due timer could otherwise fire).
  ///  2. **Clear** — wipe every persisted key with NO live writer running.
  ///  3. **Re-initialise** — rebuild the graph to zero from the empty disk, so
  ///     the next autosave writes zero-state, never the pre-reset values.
  ///
  /// Only call after the destructive confirmation is affirmed (AC-1/AC-2).
  Future<void> confirmReset() async {
    if (!isClosed) {
      emit(FactoryResetStatus.resetting);
    }
    Object? failure;
    try {
      await _onQuiesce();
      await _service.clear();
    } catch (error) {
      // A store (or the quiesce) threw. Record it, but DO NOT abort: the app
      // must never wedge on the bootstrap splash — re-init runs in `finally`.
      failure = error;
    } finally {
      // ALWAYS re-initialise so the graph is rebuilt (to whatever data
      // survived) and the app can leave the splash, even after a partial wipe.
      // A re-init failure is captured too (never rethrown) so confirmReset can
      // never leave the app hung — the failure is surfaced via the state below.
      try {
        await _onReinitialise();
      } catch (error) {
        failure ??= error;
      }
    }
    if (!isClosed) {
      emit(
        failure == null ? FactoryResetStatus.idle : FactoryResetStatus.failed,
      );
    }
  }
}
