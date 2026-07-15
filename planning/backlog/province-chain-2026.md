# Province chain 2026 — journey data model on the 34 current units

**Intake date:** 2026-07-15
**Requested by:** tuyenv@joblogic.com (Kevin / Tuyen Vo)
**Size (rough):** M
**Part of wave:** refine-app-ui-ux · sibling of [vietnam-map-fidelity](../../specs/vietnam-map-fidelity/spec.md)

> Captured via `/capture-idea` (Phase 0). Sibling slice split out of `vietnam-map-fidelity` when scope became
> "map **and** journey data" (2026-07-15). Shared map framing lives in the
> [vietnam-map-fidelity](../../specs/vietnam-map-fidelity/spec.md) spec; the sourced **34-unit dataset is
> inlined at the bottom of this file** so it survives independently.

## Why
Vietnam merged 63 provinces into 34 units on 1 July 2025. The `vietnam-map-fidelity` slice makes the *map*
show the current provinces, but the journey's domain model still encodes the old province spine and its
13-stop chain. To "handle all the provinces of Vietnam (2026)", the province/route **data model** itself must
be rebuilt onto the current 34 units — otherwise the map and the journey disagree about what Vietnam is.

## Scope (indicative — firmed at `/new-feature`)
- Rebuild the province reference data (`province_geography.dart`, `province_chain.dart`) to the **34 current
  units** using the sourced dataset (names + administrative-centre lat/long; relocated centres flagged).
- Redefine the canonical spine (Mũi Cà Mau ⇄ Hà Giang endpoints change: Hà Giang is now within Tuyên Quang;
  the southern tip is in Cà Mau province) and the inter-unit distances feeding `kmPerActiveHour` pacing.
- Preserve ADR-0004(b)'s canonical-km projection and ADR-0005's derived sub-chain / route-authoring model —
  migrate, don't reinvent. Provide forward-migration for any persisted `RoutePlan` referencing old province ids.
- Handle the **relocated-centre** gotchas (Gia Lai→Quy Nhơn, An Giang→Rạch Giá, Bắc Ninh→Bắc Giang,
  Quảng Trị→Đồng Hới, Tây Ninh→Tân An, Đồng Tháp→Mỹ Tho, Lào Cai→Yên Bái) when seeding coordinates/distances.
- **Route geometry hugs the coast (carried from `vietnam-map-fidelity` AC-5, 2026-07-15).** On the now-accurate
  coastline, the shipped straight-line segments between checkpoints cross coastal bays (`vinh→ninh_binh`,
  `hue→vinh`, `mui_ca_mau→can_tho`, `nha_trang→quy_nhon`). The rebuilt chain must route on land (intermediate
  on-land waypoints / coast-following polyline) so no segment falls in the sea. Also re-derive the Mũi Cà Mau
  terminus coordinate (the map slice nudged it 0.95 km onto the generalized coast as a display fix).

### Out
- Map rendering / the base-map asset — that's `vietnam-map-fidelity` (slice 1).
- No change to the engine's active/idle accrual or the distance/stats split (BR-6).

## Signals
Ready to promote once slice 1 (`vietnam-map-fidelity`) has settled the base-map + projection ADR (so the
data model and the map agree on the 34-unit geometry and coordinate space). **[blocked by: vietnam-map-fidelity]**
Key open question for spec time: does the spine stay a curated 2-endpoint chain, or expand to route through
all 34 units? (product-domain-expert + system-architect to frame at `/new-feature`.)

## First step
Run `/new-feature province-chain-2026` to promote this into a spec (after `vietnam-map-fidelity` ships).
Framing agents will use the sourced 34-unit dataset inlined below.

## Sourced 34-unit dataset (2026) — from `ui-asset-curator`
Official administrative-centre names (authoritative); coordinates are city-level representative WGS84 points
(`approx` = lower-confidence / relocated). **Relocated centres** (admin centre sits in a former partner
province — matters for distance seeding): Lào Cai→Yên Bái, Bắc Ninh→Bắc Giang, Quảng Trị→Đồng Hới,
Gia Lai→Quy Nhơn, Tây Ninh→Tân An, Đồng Tháp→Mỹ Tho, An Giang→Rạch Giá. Count: 6 municipalities + 28
provinces = 34.

```json
[
  {"name":"Hà Nội","type":"municipality","centre":"Hoàn Kiếm","lat":21.028,"lon":105.854},
  {"name":"Hồ Chí Minh","type":"municipality","centre":"Sài Gòn","lat":10.776,"lon":106.701},
  {"name":"Hải Phòng","type":"municipality","centre":"Thủy Nguyên","lat":20.97,"lon":106.62,"approx":true},
  {"name":"Đà Nẵng","type":"municipality","centre":"Hải Châu","lat":16.060,"lon":108.221},
  {"name":"Huế","type":"municipality","centre":"Thuận Hóa","lat":16.463,"lon":107.590},
  {"name":"Cần Thơ","type":"municipality","centre":"Ninh Kiều","lat":10.033,"lon":105.784},
  {"name":"Cao Bằng","type":"province","centre":"Thục Phán (Cao Bằng)","lat":22.666,"lon":106.258},
  {"name":"Lạng Sơn","type":"province","centre":"Lương Văn Tri (Lạng Sơn)","lat":21.853,"lon":106.761},
  {"name":"Phú Thọ","type":"province","centre":"Việt Trì","lat":21.322,"lon":105.402},
  {"name":"Quảng Ninh","type":"province","centre":"Hạ Long","lat":20.951,"lon":107.076},
  {"name":"Thái Nguyên","type":"province","centre":"Phan Đình Phùng (Thái Nguyên)","lat":21.593,"lon":105.844},
  {"name":"Tuyên Quang","type":"province","centre":"Minh Xuân (Tuyên Quang)","lat":21.823,"lon":105.214},
  {"name":"Lào Cai","type":"province","centre":"Yên Bái (relocated centre)","lat":21.705,"lon":104.870,"approx":true},
  {"name":"Điện Biên","type":"province","centre":"Điện Biên Phủ","lat":21.386,"lon":103.017},
  {"name":"Lai Châu","type":"province","centre":"Tân Phong (Lai Châu)","lat":22.386,"lon":103.458},
  {"name":"Sơn La","type":"province","centre":"Chiềng Cơi (Sơn La)","lat":21.327,"lon":103.914},
  {"name":"Bắc Ninh","type":"province","centre":"Bắc Giang (relocated centre)","lat":21.281,"lon":106.197},
  {"name":"Hưng Yên","type":"province","centre":"Phố Hiến (Hưng Yên)","lat":20.646,"lon":106.051},
  {"name":"Ninh Bình","type":"province","centre":"Hoa Lư","lat":20.251,"lon":105.975},
  {"name":"Thanh Hóa","type":"province","centre":"Hạc Thành (Thanh Hóa)","lat":19.807,"lon":105.776},
  {"name":"Nghệ An","type":"province","centre":"Trường Vinh (Vinh)","lat":18.679,"lon":105.681},
  {"name":"Hà Tĩnh","type":"province","centre":"Thành Sen (Hà Tĩnh)","lat":18.343,"lon":105.900},
  {"name":"Quảng Trị","type":"province","centre":"Đồng Hới (relocated centre)","lat":17.468,"lon":106.622},
  {"name":"Quảng Ngãi","type":"province","centre":"Cẩm Thành (Quảng Ngãi)","lat":15.120,"lon":108.800},
  {"name":"Gia Lai","type":"province","centre":"Quy Nhơn (coastal relocated centre)","lat":13.782,"lon":109.219},
  {"name":"Đắk Lắk","type":"province","centre":"Buôn Ma Thuột","lat":12.688,"lon":108.050},
  {"name":"Khánh Hòa","type":"province","centre":"Nha Trang","lat":12.238,"lon":109.196},
  {"name":"Lâm Đồng","type":"province","centre":"Xuân Hương–Đà Lạt","lat":11.940,"lon":108.458},
  {"name":"Đồng Nai","type":"province","centre":"Trấn Biên (Biên Hòa)","lat":10.957,"lon":106.842},
  {"name":"Tây Ninh","type":"province","centre":"Tân An (relocated centre, former Long An)","lat":10.535,"lon":106.413,"approx":true},
  {"name":"Đồng Tháp","type":"province","centre":"Mỹ Tho (relocated centre, former Tiền Giang)","lat":10.360,"lon":106.359},
  {"name":"Vĩnh Long","type":"province","centre":"Long Châu (Vĩnh Long)","lat":10.253,"lon":105.972},
  {"name":"An Giang","type":"province","centre":"Rạch Giá (relocated centre, former Kiên Giang)","lat":10.012,"lon":105.081},
  {"name":"Cà Mau","type":"province","centre":"Tân Thành (Cà Mau)","lat":9.177,"lon":105.152}
]
```
> Source of the map + this list: *Vietnam administrative divisions 2025* (Wikimedia, TUBS/PIkne, CC BY-SA 3.0)
> + Wikipedia's current provinces table. Coordinates ≥1 should be re-verified during `/implement`.
