/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// The traveller's current motion state, derived per-tick by the
/// [JourneyEngine] from the two-knob decision policy (grace `G`, threshold `T`).
///
/// Note (spec / AC-16): in both [idle] and [paused] the *accounting* is
/// identical — only `idleTimeToday` accrues, no distance/journey/raw — they
/// differ only as a UI-facing distinction. Distance and journey time stop at
/// `G`, never reaching the `(G, T]` band.
enum JourneyState {
  /// Genuine recent input (idle ≤ `F`) **or** within the grace band
  /// `F < s ≤ G`, unlocked, not sleep-inferred. The vehicle is moving:
  /// `distanceKm` and `activeTimeToday` accrue (AC-1/AC-3/AC-4). `rawActiveTime`
  /// accrues only on genuine-input ticks, not grace ticks (AC-2/AC-4).
  active,

  /// True idle has passed the grace window but not the hard threshold
  /// (`G < s ≤ T`), unlocked, not sleep-inferred. Vehicle stopped: only
  /// `idleTimeToday` accrues, no travel (AC-5/AC-16). With the default
  /// `G = T = 5 min` this band is empty (TC-010).
  idle,

  /// True idle past the threshold (`s > T`), **or** screen locked, **or** sleep
  /// inferred from a large idle/`delta`. Vehicle stopped: only `idleTimeToday`
  /// accrues (AC-5/AC-6/AC-8/AC-16).
  paused,
}
