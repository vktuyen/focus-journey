/// Presentation layer — the ONLY place the framework-free [GeoCoordinate] domain
/// type is converted to a `latlong2.LatLng` for `flutter_map`. Keeping this
/// conversion at the presentation boundary keeps the domain (geography model +
/// projector + mapper) free of any `latlong2` import (Clean Architecture).
library;

import 'package:latlong2/latlong.dart';

import '../domain/geo_polyline.dart';
import '../domain/province_geography.dart';

/// Converts a domain [GeoCoordinate] to a `flutter_map` [LatLng].
LatLng toLatLng(GeoCoordinate coordinate) =>
    LatLng(coordinate.latitude, coordinate.longitude);

/// Converts an ordered list of [GeoCoordinate] to [LatLng] (a polyline's points).
List<LatLng> toLatLngs(List<GeoCoordinate> coordinates) => <LatLng>[
  for (final c in coordinates) toLatLng(c),
];

/// Converts a domain [GeoPolyline] to a `flutter_map`-ready point list.
List<LatLng> polylineToLatLngs(GeoPolyline polyline) =>
    toLatLngs(polyline.points);
