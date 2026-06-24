/// Presentation layer (Flame). Maps the cosmetic [TravelMode] to its skin
/// sprite — data, not code. Adding a new vehicle is a new [JourneySkin] entry,
/// never new components (parameterise-by-skin invariant).
///
/// Depends inward ONLY on the pure-Dart `domain` [TravelMode] enum. No Flutter,
/// no Bloc, no engine, no OS. The skin carries cosmetic data only; it NEVER
/// carries a speed (v1 single-speed invariant — AC-8/TC-008).
library;

import '../../domain/travel_mode.dart';
import 'journey_assets.dart';

/// Cosmetic description of how one [TravelMode] is drawn. Speed is deliberately
/// absent — all skins scroll at the scene's single shared speed.
class JourneySkin {
  /// Creates an immutable skin descriptor.
  const JourneySkin({
    required this.mode,
    required this.assetPath,
    this.bobAmplitude = 4.0,
    this.bobFrequencyHz = 2.0,
  });

  /// The mode this skin renders.
  final TravelMode mode;

  /// The sprite path (relative to [JourneyAssets.assetPrefix]). Must be a
  /// member of [JourneyAssets.all].
  final String assetPath;

  /// Vertical "bob" travel in logical px applied while moving, to read as a
  /// running/engine animation without needing a multi-frame sprite sheet.
  /// Cosmetic only; zero contribution while parked or reduce-motion.
  final double bobAmplitude;

  /// Bob oscillations per second while moving. Cosmetic only.
  final double bobFrequencyHz;
}

/// The skin table. One entry per [TravelMode]; [motorbike] is the v1 default.
abstract final class JourneySkins {
  /// All skins keyed by mode. A new vehicle is a new line here.
  static const Map<TravelMode, JourneySkin> byMode = <TravelMode, JourneySkin>{
    TravelMode.walk: JourneySkin(
      mode: TravelMode.walk,
      assetPath: JourneyAssets.vehicleWalk,
      bobAmplitude: 5,
      bobFrequencyHz: 2.4,
    ),
    TravelMode.run: JourneySkin(
      mode: TravelMode.run,
      assetPath: JourneyAssets.vehicleRun,
      bobAmplitude: 7,
      bobFrequencyHz: 3.2,
    ),
    TravelMode.bicycle: JourneySkin(
      mode: TravelMode.bicycle,
      assetPath: JourneyAssets.vehicleBicycle,
      bobAmplitude: 3,
      bobFrequencyHz: 2.0,
    ),
    TravelMode.motorbike: JourneySkin(
      mode: TravelMode.motorbike,
      assetPath: JourneyAssets.vehicleMotorbike,
      bobAmplitude: 2,
      bobFrequencyHz: 6.0,
    ),
    TravelMode.car: JourneySkin(
      mode: TravelMode.car,
      assetPath: JourneyAssets.vehicleCar,
      bobAmplitude: 1.5,
      bobFrequencyHz: 5.0,
    ),
    TravelMode.ship: JourneySkin(
      mode: TravelMode.ship,
      assetPath: JourneyAssets.vehicleShip,
      bobAmplitude: 6,
      bobFrequencyHz: 0.8,
    ),
  };

  /// The v1 default skin used before a real mode is known.
  static const JourneySkin fallback = JourneySkin(
    mode: TravelMode.motorbike,
    assetPath: JourneyAssets.vehicleMotorbike,
  );

  /// The skin for [mode], or [fallback] if (defensively) absent.
  static JourneySkin of(TravelMode mode) => byMode[mode] ?? fallback;
}
