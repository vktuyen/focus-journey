#!/usr/bin/env python3
"""Build assets/map/vietnam_national_route.geojson from OpenStreetMap road data.

Source (dev-time only; the app makes NO runtime network call):
  - QL1  (Quốc lộ 1)  OSM route relation 15683339  — Cà Mau → Lạng Sơn
  - QL4A (Quốc lộ 4A)  OSM route relation 18208508  — Lạng Sơn → Cao Bằng

Overpass export files (raw `out geom;` JSON) are read from the scratch dir passed
as argv[1]. Data © OpenStreetMap contributors, licensed ODbL. See assets/CREDITS.md.

Pipeline: stitch member ways → order along a piecewise-monotone parameter
(lat+lon in the SW→NE south, latitude in the S→N centre/north) taking the median
of each bin (averages dual carriageways / rejects spur outliers) → Douglas–Peucker
decimation. Coordinates are raw WGS84 [lon, lat]; NOT projected to pixels.
"""
import json
import math
import sys

import numpy as np

BOUNDS = {"north": 24.0, "south": 8.0, "west": 101.8, "east": 110.3}


def load_pts(path):
    d = json.load(open(path))
    rel = [e for e in d["elements"] if e["type"] == "relation"][0]
    pts = []
    for m in rel["members"]:
        if m["type"] == "way" and "geometry" in m:
            for g in m["geometry"]:
                pts.append((g["lon"], g["lat"]))
    return np.array(pts, dtype=float), rel["tags"], d["osm3s"]


def bin_median(lon, lat, mask, param, bin_):
    key = np.round(param[mask] / bin_).astype(int)
    lo, la = lon[mask], lat[mask]
    out = []
    for k in np.unique(key):  # unique() is sorted -> ordered along param
        sel = key == k
        out.append((float(np.median(lo[sel])), float(np.median(la[sel]))))
    return out


def rdp(points, eps):
    pts = points
    n = len(pts)
    if n < 3:
        return list(pts)
    keep = [False] * n
    keep[0] = keep[-1] = True
    stack = [(0, n - 1)]

    def pldist(p, a, b):
        latc = math.cos(math.radians((a[1] + b[1]) / 2))
        ax, ay, bx, by, px, py = a[0]*latc, a[1], b[0]*latc, b[1], p[0]*latc, p[1]
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        if L2 == 0:
            return math.hypot(px - ax, py - ay)
        t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
        return math.hypot(px - (ax + t * dx), py - (ay + t * dy))

    while stack:
        i0, i1 = stack.pop()
        dmax, idx = 0.0, -1
        for i in range(i0 + 1, i1):
            dd = pldist(pts[i], pts[i0], pts[i1])
            if dd > dmax:
                dmax, idx = dd, i
        if dmax > eps:
            keep[idx] = True
            stack.append((i0, idx))
            stack.append((idx, i1))
    return [tuple(p) for p, k in zip(pts, keep) if k]


def build_ql1(path):
    pts, tags, osm3s = load_pts(path)
    lon, lat = pts[:, 0], pts[:, 1]
    SEAM = 12.3
    south = lat <= SEAM
    north = lat > SEAM
    prof = (bin_median(lon, lat, south, lat + lon, 0.008)
            + bin_median(lon, lat, north, lat, 0.008))
    return prof, tags, osm3s, len(pts)


def chain_ways(path):
    """Order the member ways of a route relation into one polyline by greedy
    nearest-neighbour, starting from the southernmost endpoint. Returns the
    ordered point list and the original vertex count."""
    d = json.load(open(path))
    rel = [e for e in d["elements"] if e["type"] == "relation"][0]
    ways = [np.array([(g["lon"], g["lat"]) for g in m["geometry"]], float)
            for m in rel["members"]
            if m["type"] == "way" and "geometry" in m and len(m["geometry"]) >= 2]
    n = len(ways)
    SC = math.cos(math.radians(22.5))
    starts = np.array([w[0] for w in ways])
    ends = np.array([w[-1] for w in ways])
    S = starts.copy(); S[:, 0] *= SC
    E = ends.copy(); E[:, 0] *= SC
    used = np.zeros(n, bool)
    si = int(np.argmin(np.minimum(starts[:, 1], ends[:, 1])))
    w0 = ways[si] if starts[si, 1] <= ends[si, 1] else ways[si][::-1]
    out = [w0]
    used[si] = True
    end = w0[-1].copy()
    orig = sum(len(w) for w in ways)
    for _ in range(n - 1):
        px, py = end[0] * SC, end[1]
        ds = (S[:, 0] - px) ** 2 + (S[:, 1] - py) ** 2
        de = (E[:, 0] - px) ** 2 + (E[:, 1] - py) ** 2
        ds[used] = np.inf; de[used] = np.inf
        i_s, i_e = int(np.argmin(ds)), int(np.argmin(de))
        if ds[i_s] <= de[i_e]:
            i, w = i_s, ways[i_s]
        else:
            i, w = i_e, ways[i_e][::-1]
        used[i] = True
        out.append(w)
        end = w[-1].copy()
    return np.concatenate(out), orig, rel["tags"], d["osm3s"]


def build_ql4a(path, cao_bang=(106.258, 22.666)):
    """Chain QL4A south→north from Lạng Sơn and trim at its closest approach to
    Cao Bằng (the relation continues past it toward Bảo Lạc)."""
    poly, orig, tags, osm3s = chain_ways(path)
    dkm = np.hypot((poly[:, 0] - cao_bang[0]) * math.cos(math.radians(22.6)),
                   poly[:, 1] - cao_bang[1]) * 111.0
    cut = int(np.argmin(dkm))
    residual = float(dkm[cut])
    seg = [tuple(p) for p in poly[:cut + 1]]
    return seg, tags, osm3s, orig, residual


def main():
    scratch = sys.argv[1]
    out_path = sys.argv[2]

    ql1_prof, ql1_tags, osm3s, ql1_orig = build_ql1(f"{scratch}/rel_geom.json")
    ql4_prof, ql4_tags, _, ql4_orig, ql4_residual = build_ql4a(
        f"{scratch}/conn_geom.json")

    ql1_dec = rdp(ql1_prof, 0.006)
    ql4_dec = rdp(ql4_prof, 0.006)

    # bounds clamp sanity (should already be inside)
    for name, seg in (("QL1", ql1_dec), ("QL4A", ql4_dec)):
        for x, y in seg:
            assert BOUNDS["west"] <= x <= BOUNDS["east"], (name, x)
            assert BOUNDS["south"] <= y <= BOUNDS["north"], (name, y)

    def rnd(seg):
        return [[round(x, 5), round(y, 5)] for x, y in seg]

    src = ("OpenStreetMap via Overpass API; route relations "
           "15683339 (QL1) and 18208508 (QL4A); exported 2026-07-16")
    lic = "ODbL — © OpenStreetMap contributors"

    fc = {
        "type": "FeatureCollection",
        "properties": {
            "source": src,
            "license": lic,
            "bounds": BOUNDS,
            "note": ("Vietnam national highway, ordered south→north. "
                     "Raw WGS84 [lon,lat]; unprojected (same frame as "
                     "vietnam_provinces_2025.geojson). Dev-time sourced; "
                     "app makes no runtime network call."),
        },
        "features": [
            {
                "type": "Feature",
                "properties": {
                    "ref": "QL1A",
                    "name": "Quốc lộ 1 (National Route 1)",
                    "from": "Đất Mũi, Cà Mau",
                    "to": "Hữu Nghị, Lạng Sơn",
                    "source": src,
                    "license": lic,
                },
                "geometry": {"type": "LineString", "coordinates": rnd(ql1_dec)},
            },
            {
                "type": "Feature",
                "properties": {
                    "ref": "QL4A",
                    "name": "Quốc lộ 4A (Lạng Sơn – Cao Bằng connector)",
                    "from": "Đồng Đăng, Lạng Sơn",
                    "to": "Cao Bằng",
                    "source": src,
                    "license": lic,
                },
                "geometry": {"type": "LineString", "coordinates": rnd(ql4_dec)},
            },
        ],
    }
    json.dump(fc, open(out_path, "w"), ensure_ascii=False, separators=(",", ":"))

    print("QL1 : orig %d profile %d decimated %d"
          % (ql1_orig, len(ql1_prof), len(ql1_dec)), file=sys.stderr)
    print("QL4A: orig %d profile %d decimated %d"
          % (ql4_orig, len(ql4_prof), len(ql4_dec)), file=sys.stderr)
    print("total decimated vertices: %d" % (len(ql1_dec) + len(ql4_dec)),
          file=sys.stderr)
    print("QL4A north terminus %.2f km from Cao Bằng city; ends at %s"
          % (ql4_residual, ql4_dec[-1]), file=sys.stderr)


if __name__ == "__main__":
    main()
