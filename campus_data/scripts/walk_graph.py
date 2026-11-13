"""Walking network for routing, built from OpenStreetMap ways.

Nodes are OSM nodes (junctions are shared node ids, so connectivity is real OSM topology).
Each building gets up to 3 "access points": the closest spots on the path network next to it,
inserted as extra nodes. Routes end at an access point; the last few metres to the wall
(the "door" point) are drawn dotted in the app because entrances are not surveyed.
"""
import math

# Walking cost multipliers: prefer footpaths over walking along roads.
WALKABLE = {
    "footway": 1.0, "path": 1.0, "pedestrian": 1.0, "cycleway": 1.0, "corridor": 1.0,
    "steps": 1.15, "living_street": 1.1, "service": 1.2, "track": 1.2,
    "unclassified": 1.4, "residential": 1.4, "tertiary": 1.6,
}
NO_FOOT = {"no", "private"}

LAT0 = -12.372
KX = 111_320 * math.cos(math.radians(LAT0))
KY = 110_574


def to_m(lon, lat):
    return ((lon - 130.869) * KX, (lat - LAT0) * KY)


def to_ll(x, y):
    return (x / KX + 130.869, y / KY + LAT0)


def seg_closest(p, a, b):
    """Closest point to p on segment a-b, and its parameter t."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / L2))
    return (ax + t * dx, ay + t * dy), t


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def polygon_rings_m(geojson_geom):
    """Outer and inner rings of a (Multi)Polygon GeoJSON geometry, in metres."""
    polys = geojson_geom["coordinates"]
    if geojson_geom["type"] == "Polygon":
        polys = [polys]
    return [[to_m(*pt) for pt in ring] for poly in polys for ring in poly]


def point_in_rings(p, rings):
    inside = False
    for ring in rings:
        for i in range(len(ring) - 1):
            (x1, y1), (x2, y2) = ring[i], ring[i + 1]
            if (y1 > p[1]) != (y2 > p[1]):
                x = x1 + (p[1] - y1) * (x2 - x1) / (y2 - y1)
                if x > p[0]:
                    inside = not inside
    return inside


def closest_on_rings(p, rings):
    best, bd = None, float("inf")
    for ring in rings:
        for i in range(len(ring) - 1):
            q, _ = seg_closest(p, ring[i], ring[i + 1])
            d = dist(p, q)
            if d < bd:
                best, bd = q, d
    return best, bd


def build(osm_elements, buildings, max_access_m=35.0):
    """buildings: list of GeoJSON features (with properties.id). Returns (graph_json, report_lines)."""
    nodes = {}  # osm node id -> (x, y)
    edges = []  # [a_key, b_key, factor, highway]
    for e in osm_elements:
        t = e.get("tags", {})
        hw = t.get("highway")
        if e["type"] != "way" or hw not in WALKABLE or t.get("foot") in NO_FOOT:
            continue
        ids, geom = e.get("nodes", []), e.get("geometry", [])
        if len(ids) != len(geom) or len(ids) < 2:
            continue
        for nid, g in zip(ids, geom):
            nodes[nid] = to_m(g["lon"], g["lat"])
        passage = t.get("tunnel") == "building_passage" or t.get("indoor") == "yes" or hw == "corridor"
        for a, b in zip(ids, ids[1:]):
            if a != b:
                edges.append([a, b, WALKABLE[hw], "passage" if passage else hw])

    # Keep the largest connected component
    parent = {n: n for n in nodes}

    def find(n):
        while parent[n] != n:
            parent[n] = parent[parent[n]]
            n = parent[n]
        return n

    for a, b, *_ in edges:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb
    sizes = {}
    for n in nodes:
        sizes[find(n)] = sizes.get(find(n), 0) + 1
    main = max(sizes, key=sizes.get)
    dropped = len(nodes) - sizes[main]
    nodes = {n: p for n, p in nodes.items() if find(n) == main}
    edges = [e for e in edges if e[0] in nodes]

    # Segments that cross a building footprint (and are not mapped as a passage) are
    # made 3x as costly, so routes go around buildings unless there is no other way.
    footprints = []
    for f in buildings:
        rings = polygon_rings_m(f["geometry"])
        xs = [p[0] for r in rings for p in r]
        ys = [p[1] for r in rings for p in r]
        footprints.append(((min(xs), min(ys), max(xs), max(ys)), rings))
    through = 0
    for e in edges:
        if e[3] == "passage":
            continue
        pa, pb = nodes[e[0]], nodes[e[1]]
        n = max(1, int(dist(pa, pb) / 2))
        samples = [(pa[0] + k / n * (pb[0] - pa[0]), pa[1] + k / n * (pb[1] - pa[1])) for k in range(1, n)]
        samples = samples or [((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2)]
        hit = False
        for (x0, y0, x1, y1), rings in footprints:
            for p in samples:
                if x0 <= p[0] <= x1 and y0 <= p[1] <= y1 and point_in_rings(p, rings):
                    hit = True
                    break
            if hit:
                break
        if hit:
            e[2] *= 3.0
            e[3] = "through-building"
            through += 1

    # Access points for each building
    splits = {}  # edge index -> list of (t, key)
    access = {}
    report = []
    for f in buildings:
        bid = f["properties"]["id"]
        rings = polygon_rings_m(f["geometry"])
        xs = [p[0] for r in rings for p in r]
        ys = [p[1] for r in rings for p in r]
        box = (min(xs) - max_access_m, min(ys) - max_access_m, max(xs) + max_access_m, max(ys) + max_access_m)
        cands = []
        for i, (a, b, *_rest) in enumerate(edges):
            pa, pb = nodes[a], nodes[b]
            if max(pa[0], pb[0]) < box[0] or min(pa[0], pb[0]) > box[2] or \
               max(pa[1], pb[1]) < box[1] or min(pa[1], pb[1]) > box[3]:
                continue
            # sample the segment every ~1 m and keep the point closest to the building
            n = max(1, int(dist(pa, pb)))
            best = None
            for k in range(n + 1):
                tt = k / n
                p = (pa[0] + tt * (pb[0] - pa[0]), pa[1] + tt * (pb[1] - pa[1]))
                if point_in_rings(p, rings):
                    d, door = 0.0, p
                else:
                    door, d = closest_on_rings(p, rings)
                if best is None or d < best[0]:
                    best = (d, tt, p, door)
            if best and best[0] <= max_access_m:
                cands.append((best[0], i, best[1], best[2], best[3]))
        cands.sort()
        chosen = []
        for d, i, tt, p, door in cands:
            if chosen and d > min(chosen[0][0] + 15, max_access_m):
                break
            if all(dist(p, c[3]) >= 25 for c in chosen):
                chosen.append((d, i, tt, p, door))
            if len(chosen) == 3:
                break
        if not chosen:
            report.append(f"{bid}: no path within {max_access_m} m")
            continue
        access[bid] = []
        for d, i, tt, p, door in chosen:
            key = ("acc", bid, len(access[bid]))
            nodes[key] = p
            splits.setdefault(i, []).append((tt, key))
            access[bid].append((key, door, round(d, 1)))

    # Split edges at access points
    new_edges = []
    for i, (a, b, factor, hw) in enumerate(edges):
        chain = [a] + [k for _, k in sorted(splits.get(i, []))] + [b]
        for u, v in zip(chain, chain[1:]):
            new_edges.append((u, v, factor, hw))

    # Number the nodes and write compact JSON
    index = {k: i for i, k in enumerate(nodes)}
    out_nodes = [[round(c, 7) for c in to_ll(*nodes[k])] for k in nodes]
    out_edges = []
    for u, v, factor, hw in new_edges:
        # zero-length links are kept: they join an access point that sits exactly on a junction
        L = dist(nodes[u], nodes[v])
        out_edges.append([index[u], index[v], round(L, 2), factor, hw])
    out_access = {
        bid: [{"node": index[k], "door": [round(c, 7) for c in to_ll(*door)], "gap": gap}
              for k, door, gap in lst]
        for bid, lst in access.items()
    }
    report.insert(0, f"walk graph: {len(out_nodes)} nodes, {len(out_edges)} edges, "
                     f"{dropped} nodes dropped (not connected), {len(out_access)} buildings reachable, "
                     f"{through} segments cross a building (penalised)")
    return {"nodes": out_nodes, "edges": out_edges, "access": out_access}, report
