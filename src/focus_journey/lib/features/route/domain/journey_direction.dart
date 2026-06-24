/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// The direction a route is travelled along the Mũi Cà Mau ⇄ Hà Giang chain.
///
/// The province chain ([ProvinceChain]) is stored in a single canonical order,
/// south tip → north tip (`Mũi Cà Mau` → `Hà Giang`). A route picks a start
/// province and one of these two directions; the direction decides which chain
/// tip is the completion **destination** and the order in which checkpoints are
/// walked (locked decision 4 / AC-8).
enum JourneyDirection {
  /// Travel toward the north tip (`Hà Giang`) — "north". Walks the canonical
  /// chain order forward (ascending index). Destination = the north tip.
  towardHaGiang,

  /// Travel toward the south tip (`Mũi Cà Mau`) — "south". Walks the canonical
  /// chain order backward (descending index). Destination = the south tip.
  towardMuiCaMau,
}
