/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// The direction a route is travelled along the south⇄north province chain.
///
/// The province chain ([ProvinceChain]) is stored in a single canonical order,
/// south tip → north tip. A route picks a start province and one of these two
/// directions; the direction decides which chain tip is the completion
/// **destination** and the order in which checkpoints are walked (locked
/// decision 4 / AC-8).
///
/// **Enum-name stability (province-chain-2026 / candidate ADR-0009).** These
/// names are persisted-by-name and are kept as STABLE SYMBOLIC labels even
/// though the 2026 tip identities changed (the north terminus is now Cao Bằng,
/// the max-latitude current unit — the old `Hà Giang` is within Tuyên Quang; the
/// south tip is Cà Mau / Tân Thành). No persisted-enum migration is needed —
/// only these doc comments / UI labels are updated.
enum JourneyDirection {
  /// Travel toward the **north tip** — "north". Walks the canonical chain order
  /// forward (ascending index). Destination = the north tip (now Cao Bằng). The
  /// `HaGiang` in the name is a retained symbolic label, not the current tip id.
  towardHaGiang,

  /// Travel toward the **south tip** (Cà Mau) — "south". Walks the canonical
  /// chain order backward (descending index). Destination = the south tip.
  towardMuiCaMau,
}
