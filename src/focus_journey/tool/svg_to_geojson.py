#!/usr/bin/env python3
"""One-time OFFLINE build tool: convert the sourced Wikimedia Vietnam province
SVG into a georeferenced (lat/long) GeoJSON FeatureCollection for the bundled
base map (ADR-0008 step 0).

NOT part of the app runtime. Run manually when the source asset changes:

    python3 tool/svg_to_geojson.py

Input : assets/map/vietnam_provinces_2025_base.svg  (Wikimedia, CC BY-SA 3.0,
        TUBS/PIkne). Equirectangular / plate-carree drawing in pixel space.
Output: assets/map/vietnam_provinces_2025.geojson    (bundled, wired in pubspec)

Projection (inverse of the asset's documented equirectangular projection):
    lat = 24.0 - (py / 2349.176) * 16.0
    lon = 101.8 + (px / 1200.0)  * 8.5
where (px, py) are RENDERED-image pixels (top-left origin, 1200 x 2349.176).
The source viewBox is "0.344 0.001 1200.001 2349.175"; the ~0.344/0.001 origin
offset is < 0.03% of the frame and below the coastline-vs-bounds alignment
error, so it is ignored (matches the CREDITS georeferencing note that rendering
the viewBox to a 1200-wide image normalises the origin).

Province AREAS vs label glyphs (the curator's baked-label gotcha): the province
polygons carry per-province PASTEL choropleth fills; the province-name LABELS
and boundary strokes share fill #646464. We therefore keep ONLY the pastel-
filled area paths and drop every #646464 path (labels + strokes) plus Sea /
Lakes / Rivers / other_countries. We draw our own thin borders in-app, so the
#646464 strokes are not needed. This is a clean fill-based separation, so the
STOP-and-report fallback in ADR-0008 step 0 was not required.
"""
import json
import math
import os
import re
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, os.pardir, "assets", "map",
                   "vietnam_provinces_2025_base.svg")
OUT = os.path.join(HERE, os.pardir, "assets", "map",
                   "vietnam_provinces_2025.geojson")

NS = "{http://www.w3.org/2000/svg}"

# Per-province choropleth fills = province AREAS (borders). #fefee4 is the
# single `id="Vietnam"` master landmass drawn UNDER the choropleth (the clean
# national outline). Everything else (#646464 labels/strokes, sea, lakes,
# rivers, neighbours) is dropped.
PROVINCE_FILLS = {"#e8f2ad", "#ebcef2", "#fffdc0", "#ffcccc", "#ffdea9"}
LAND_FILL = "#fefee4"

# Frame + bounds (ADR-0008 / CREDITS georeferencing).
VIEW_W = 1200.0
VIEW_H = 2349.176
LAT_N, LAT_S = 24.0, 8.0
LON_W, LON_E = 101.8, 110.3

# Bezier flattening: samples per curve segment, then Douglas-Peucker simplify.
BEZIER_STEPS = 8

# Douglas-Peucker tolerance in DEGREES (~0.004 deg ~= 440 m). Coarse enough to
# shrink the file, fine enough to keep the S-shape / deltas / Ca Mau point.
SIMPLIFY_EPS = 0.004

# Border features: drop province rings below this area (sq-degrees) so tiny
# offshore island specks do not clutter the drawn province borders. The land
# fill (master polygon) still includes them, so the coastline is unaffected.
MIN_PROVINCE_AREA = 0.05

# Land features: keep even small rings (islands) so the coast is complete, but
# drop sub-pixel glyph/artefact specks.
MIN_LAND_AREA = 5.0e-4


def px_to_lonlat(px, py):
    lat = LAT_N - (py / VIEW_H) * (LAT_N - LAT_S)
    lon = LON_W + (px / VIEW_W) * (LON_E - LON_W)
    return lon, lat


# ---- transforms ----------------------------------------------------------
def mat_mul(a, b):
    # a,b are (a,b,c,d,e,f) for [[a c e],[b d f],[0 0 1]]
    a0, a1, a2, a3, a4, a5 = a
    b0, b1, b2, b3, b4, b5 = b
    return (
        a0 * b0 + a2 * b1,
        a1 * b0 + a3 * b1,
        a0 * b2 + a2 * b3,
        a1 * b2 + a3 * b3,
        a0 * b4 + a2 * b5 + a4,
        a1 * b4 + a3 * b5 + a5,
    )


def apply_mat(m, x, y):
    a0, a1, a2, a3, a4, a5 = m
    return a0 * x + a2 * y + a4, a1 * x + a3 * y + a5


IDENT = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def parse_transform(s):
    if not s:
        return IDENT
    m = IDENT
    for name, args in re.findall(r"(\w+)\s*\(([^)]*)\)", s):
        nums = [float(v) for v in re.split(r"[\s,]+", args.strip()) if v]
        if name == "matrix" and len(nums) == 6:
            t = tuple(nums)
        elif name == "translate":
            tx = nums[0]
            ty = nums[1] if len(nums) > 1 else 0.0
            t = (1.0, 0.0, 0.0, 1.0, tx, ty)
        elif name == "scale":
            sx = nums[0]
            sy = nums[1] if len(nums) > 1 else sx
            t = (sx, 0.0, 0.0, sy, 0.0, 0.0)
        else:
            t = IDENT
        m = mat_mul(m, t)
    return m


# ---- path parsing --------------------------------------------------------
_TOKEN = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?")


def tokenize(d):
    return _TOKEN.findall(d)


def flatten_path(d):
    """Parse an SVG path 'd' into a list of subpath rings; each ring is a list
    of (x, y) points. Beziers are flattened; arcs approximated as line-to (none
    appear in this asset). Handles absolute + relative commands."""
    toks = tokenize(d)
    i = 0
    rings = []
    cur = []
    x = y = 0.0
    start_x = start_y = 0.0
    cmd = None
    prev_ctrl = None

    def num():
        nonlocal i
        v = float(toks[i])
        i += 1
        return v

    while i < len(toks):
        t = toks[i]
        if re.match(r"[A-Za-z]", t):
            cmd = t
            i += 1
        rel = cmd.islower()
        c = cmd.upper()
        if c == "M":
            nx, ny = num(), num()
            if rel:
                nx += x
                ny += y
            if cur:
                rings.append(cur)
            cur = [(nx, ny)]
            x, y = nx, ny
            start_x, start_y = nx, ny
            cmd = "l" if rel else "L"  # subsequent pairs are lineto
            prev_ctrl = None
        elif c == "L":
            nx, ny = num(), num()
            if rel:
                nx += x
                ny += y
            cur.append((nx, ny))
            x, y = nx, ny
            prev_ctrl = None
        elif c == "H":
            nx = num()
            if rel:
                nx += x
            cur.append((nx, y))
            x = nx
            prev_ctrl = None
        elif c == "V":
            ny = num()
            if rel:
                ny += y
            cur.append((x, ny))
            y = ny
            prev_ctrl = None
        elif c in ("C", "S"):
            if c == "C":
                x1, y1 = num(), num()
                x2, y2 = num(), num()
                nx, ny = num(), num()
                if rel:
                    x1 += x; y1 += y; x2 += x; y2 += y; nx += x; ny += y
            else:  # S: first ctrl is reflection of previous
                x2, y2 = num(), num()
                nx, ny = num(), num()
                if rel:
                    x2 += x; y2 += y; nx += x; ny += y
                if prev_ctrl is not None:
                    x1 = 2 * x - prev_ctrl[0]
                    y1 = 2 * y - prev_ctrl[1]
                else:
                    x1, y1 = x, y
            for s in range(1, BEZIER_STEPS + 1):
                tt = s / BEZIER_STEPS
                mt = 1 - tt
                bx = (mt**3 * x + 3 * mt**2 * tt * x1 +
                      3 * mt * tt**2 * x2 + tt**3 * nx)
                by = (mt**3 * y + 3 * mt**2 * tt * y1 +
                      3 * mt * tt**2 * y2 + tt**3 * ny)
                cur.append((bx, by))
            prev_ctrl = (x2, y2)
            x, y = nx, ny
        elif c in ("Q", "T"):
            if c == "Q":
                x1, y1 = num(), num()
                nx, ny = num(), num()
                if rel:
                    x1 += x; y1 += y; nx += x; ny += y
            else:
                nx, ny = num(), num()
                if rel:
                    nx += x; ny += y
                if prev_ctrl is not None:
                    x1 = 2 * x - prev_ctrl[0]
                    y1 = 2 * y - prev_ctrl[1]
                else:
                    x1, y1 = x, y
            for s in range(1, BEZIER_STEPS + 1):
                tt = s / BEZIER_STEPS
                mt = 1 - tt
                bx = mt**2 * x + 2 * mt * tt * x1 + tt**2 * nx
                by = mt**2 * y + 2 * mt * tt * y1 + tt**2 * ny
                cur.append((bx, by))
            prev_ctrl = (x1, y1)
            x, y = nx, ny
        elif c == "A":
            # arc: skip params, treat as line-to endpoint (none in this asset)
            num(); num(); num(); num(); num()
            nx, ny = num(), num()
            if rel:
                nx += x; ny += y
            cur.append((nx, ny))
            x, y = nx, ny
            prev_ctrl = None
        elif c == "Z":
            if cur:
                cur.append((start_x, start_y))
                rings.append(cur)
                cur = []
            x, y = start_x, start_y
            prev_ctrl = None
        else:
            i += 1
    if cur:
        rings.append(cur)
    return rings


def ring_area(ring):
    """Shoelace area (absolute) of a ring in projected lon/lat space."""
    a = 0.0
    n = len(ring)
    for k in range(n):
        x1, y1 = ring[k]
        x2, y2 = ring[(k + 1) % n]
        a += x1 * y2 - x2 * y1
    return abs(a) / 2.0


def _perp_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy)


def simplify(ring, eps):
    """Douglas-Peucker on an open point list (keeps endpoints)."""
    if len(ring) < 3:
        return ring
    dmax, idx = 0.0, 0
    for i in range(1, len(ring) - 1):
        d = _perp_dist(ring[i], ring[0], ring[-1])
        if d > dmax:
            dmax, idx = d, i
    if dmax > eps:
        left = simplify(ring[:idx + 1], eps)
        right = simplify(ring[idx:], eps)
        return left[:-1] + right
    return [ring[0], ring[-1]]


# ---- style resolution ----------------------------------------------------
def resolved_fill(el, inherited):
    st = el.get("style", "")
    m = re.search(r"fill:\s*([^;]+)", st)
    if m:
        return m.group(1).strip().lower()
    f = el.get("fill")
    return f.lower() if f else inherited


def collect(el, transform, fill, land, prov):
    tag = el.tag.replace(NS, "")
    t = mat_mul(transform, parse_transform(el.get("transform", "")))
    f = resolved_fill(el, fill)
    if tag == "path":
        if f == LAND_FILL:
            land.append((el.get("d", ""), t))
        elif f in PROVINCE_FILLS:
            prov.append((el.get("d", ""), t))
        return
    for c in el:
        collect(c, t, f, land, prov)


def paths_to_rings(raw, min_area):
    """Flatten + project + simplify a list of (d, transform) into lon/lat rings
    with area >= min_area."""
    rings = []
    for d, t in raw:
        for ring_px in flatten_path(d):
            ring = []
            for px, py in ring_px:
                wx, wy = apply_mat(t, px, py)
                lon, lat = px_to_lonlat(wx, wy)
                ring.append((lon, lat))
            if len(ring) < 4:
                continue
            ring = simplify(ring, SIMPLIFY_EPS)
            if len(ring) < 4:
                continue
            if ring_area(ring) >= min_area:
                rings.append(ring)
    return rings


def _feature(ring, role):
    coords = [[round(lon, 5), round(lat, 5)] for lon, lat in ring]
    if coords[0] != coords[-1]:
        coords.append(coords[0])
    return {
        "type": "Feature",
        "properties": {"role": role, "area": round(ring_area(ring), 6)},
        "geometry": {"type": "Polygon", "coordinates": [coords]},
    }


def main():
    tree = ET.parse(SRC)
    root = tree.getroot()
    land_raw, prov_raw = [], []
    collect(root, IDENT, None, land_raw, prov_raw)
    print(f"master land paths={len(land_raw)}  "
          f"pastel province paths={len(prov_raw)}")

    land = paths_to_rings(land_raw, MIN_LAND_AREA)
    prov = paths_to_rings(prov_raw, MIN_PROVINCE_AREA)
    print(f"land rings (fill)   = {len(land)}")
    print(f"province rings (border, area>=%.2f) = %d" %
          (MIN_PROVINCE_AREA, len(prov)))
    parea = sorted((ring_area(r) for r in prov), reverse=True)
    print("province ring areas:", ", ".join("%.3g" % a for a in parea))
    tot_pts = sum(len(r) for r in land) + sum(len(r) for r in prov)
    print(f"total vertices after simplify = {tot_pts}")

    features = [_feature(r, "land") for r in land]
    features += [_feature(r, "province") for r in prov]
    fc = {
        "type": "FeatureCollection",
        "properties": {
            "source": "vietnam_provinces_2025_base.svg (Wikimedia, TUBS/PIkne)",
            "license": "CC BY-SA 3.0",
            "bounds": {"north": LAT_N, "south": LAT_S,
                       "west": LON_W, "east": LON_E},
            "note": "role=land: single-tone national landmass (fill + "
                    "point-in-landmass). role=province: 2025 unit outlines "
                    "(thin borders).",
        },
        "features": features,
    }
    with open(OUT, "w") as fh:
        json.dump(fc, fh, separators=(",", ":"))
    print(f"wrote {OUT}: {len(features)} features, "
          f"{os.path.getsize(OUT)} bytes")

    # ---- sanity: point-in-polygon for known cities (against LAND) ----
    def pip(lon, lat):
        inside = False
        for ring in land:
            n = len(ring)
            j = n - 1
            r = False
            for k in range(n):
                xi, yi = ring[k]
                xj, yj = ring[j]
                if ((yi > lat) != (yj > lat)) and (
                    lon < (xj - xi) * (lat - yi) / (yj - yi + 1e-15) + xi
                ):
                    r = not r
                j = k
            if r:
                inside = True
                break
        return inside

    cities = {
        "Ha Noi": (105.85, 21.03),
        "Ca Mau": (105.15, 9.2),
        "Da Nang": (108.22, 16.06),
        "HCMC": (106.63, 10.82),
        "Ha Giang": (104.98, 22.82),
    }
    print("point-in-landmass sanity:")
    for name, (lon, lat) in cities.items():
        print(f"  {name:10} ({lat},{lon}) -> {'LAND' if pip(lon,lat) else 'SEA/MISS'}")


if __name__ == "__main__":
    main()
