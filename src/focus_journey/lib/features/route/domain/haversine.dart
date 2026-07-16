/// Domain layer — pure Dart. No Flutter, no platform channels, no `latlong2`,
/// no I/O, no network. Deterministic and fully unit-testable.
///
/// The SINGLE source for great-circle distances between two WGS-84 coordinates
/// (province-chain-2026 / candidate ADR-0009). `ProvinceChain`'s segment
/// distances are computed from this — never hand-authored stylized km — so the
/// journey's `totalChainKm` reflects real 2026 geography (AC-3).
///
/// PRIVACY (NFR-2 — gating): a pure function of its four `double` arguments. It
/// reads no device position, no GPS, no OS state — it only measures the distance
/// between two static reference coordinates.
library;

import 'dart:math' as math;

/// Mean Earth radius (km) — the standard spherical approximation used by the
/// haversine great-circle formula. Fixed so segment distances are reproducible.
const double kEarthRadiusKm = 6371.0;

/// The great-circle (haversine) distance in kilometres between two points given
/// as latitude/longitude in **degrees** (south/west negative).
///
/// Formula: `d = 2R·asin(√(sin²(Δφ/2) + cosφ₁·cosφ₂·sin²(Δλ/2)))`, with the mean
/// Earth radius [kEarthRadiusKm]. Degrees are converted to radians internally.
/// Deterministic; returns `0` for identical points.
double greatCircleKm(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = _toRadians(lat1);
  final phi2 = _toRadians(lat2);
  final dPhi = _toRadians(lat2 - lat1);
  final dLambda = _toRadians(lon2 - lon1);

  final sinHalfDPhi = math.sin(dPhi / 2);
  final sinHalfDLambda = math.sin(dLambda / 2);

  final a =
      sinHalfDPhi * sinHalfDPhi +
      math.cos(phi1) * math.cos(phi2) * sinHalfDLambda * sinHalfDLambda;
  // Clamp the argument into [0, 1] to guard against a tiny float overshoot at
  // near-antipodal or identical points before asin.
  final clampedA = a < 0 ? 0.0 : (a > 1 ? 1.0 : a);
  final c = 2 * math.asin(math.sqrt(clampedA));
  return kEarthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180.0;
