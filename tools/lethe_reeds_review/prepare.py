"""Prepare a combat painting guide from the untouched Roseaux route geometry."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ROOM = ROOT / "data/rooms/catabase_routes/route_6d5efdb88ff0"
OUT = ROOT / "assets/catabase/combat/lethe_reeds_v1"
BASE = ROOT / "artifacts/dev/lethe-reeds/before"
CANVAS = (1920, 1200)
BOAT = [105, 745, 385, 890]
BASELINE_FILES = ("room.tres", "geometry_manifest.json", "terrain_plan.json")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hull(points):
    points = sorted(set(points))
    def cross(o, a, b):
        return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for sequence, chain in [(points, lower), (points[::-1], upper)]:
        for point in sequence:
            while len(chain) >= 2 and cross(chain[-2], chain[-1], point) <= 0:
                chain.pop()
            chain.append(point)
    return lower[:-1] + upper[:-1]


def expand(points, radius):
    # Same square Minkowski reserve as Lances: full cells retain the clearance.
    return hull([(x+dx, y+dy) for x, y in points for dx, dy in
                 [(-radius, -radius), (-radius, radius), (radius, -radius), (radius, radius)]])


def bounds(points):
    return {"min": [min(p[i] for p in points) for i in (0, 1)],
            "max": [max(p[i] for p in points) for i in (0, 1)]}


def preserve_baseline():
    BASE.mkdir(parents=True, exist_ok=True)
    existing = [(BASE/name).exists() for name in BASELINE_FILES]
    record_path = BASE / "baseline.json"
    if any(existing):
        if not all(existing) or not record_path.is_file():
            raise ValueError("Incomplete immutable baseline: inspect it before proceeding")
        record = json.loads(record_path.read_text(encoding="utf-8"))
        if any(digest(BASE/name) != record["sha256"][name] for name in BASELINE_FILES):
            raise ValueError("Immutable baseline was modified")
        return
    record = {"room": str(ROOM.relative_to(ROOT)), "sha256": {}}
    for name in BASELINE_FILES:
        with (BASE/name).open("xb") as stream:
            stream.write((ROOM/name).read_bytes())
        record["sha256"][name] = digest(BASE/name)
    with record_path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(record, indent=2) + "\n")


def main():
    before = {name: digest(ROOM/name) for name in BASELINE_FILES}
    preserve_baseline()
    OUT.mkdir(parents=True, exist_ok=True)
    geo = json.loads((ROOM/"geometry_manifest.json").read_text(encoding="utf-8-sig"))
    if geo["arena_id"] != "route_6d5efdb88ff0" or tuple(geo["image_size"]) != CANVAS:
        raise ValueError("Unexpected room identity or source canvas")
    if len(geo["floor_cells"]) != geo["expected_floor_count"]:
        raise ValueError("Geometry floor count differs from its authored contract")
    ox, oy = geo["grid_origin"]
    ax, ay = geo["axis_x"]
    bx, by = geo["axis_y"]
    def polygon(cell):
        x, y = cell
        cx, cy = ox+x*ax+y*bx, oy+x*ay+y*by
        return [(cx+dx*ax+dy*bx, cy+dx*ay+dy*by) for dx, dy in
                [(-.5, -.5), (.5, -.5), (.5, .5), (-.5, .5)]]
    floor = [polygon(cell) for cell in geo["floor_cells"]]
    footprint = hull([point for tile in floor for point in tile])
    reserve, shore = expand(footprint, 60), expand(footprint, 100)
    shore_bounds = bounds(shore)
    if any(shore_bounds["min"][i] < 0 or shore_bounds["max"][i] > CANVAS[i] for i in (0, 1)):
        raise ValueError("Shore reserve exceeds the painting canvas")
    boat_mask, shore_mask = Image.new("L", CANVAS), Image.new("L", CANVAS)
    ImageDraw.Draw(boat_mask).rectangle(BOAT, fill=255)
    ImageDraw.Draw(shore_mask).polygon(shore, fill=255)
    if ImageChops.multiply(boat_mask, shore_mask).getbbox() is not None:
        raise ValueError("Boat bounding box intersects the reserved shore")
    image = Image.new("RGB", CANVAS, "#123f42")
    draw = ImageDraw.Draw(image)
    draw.polygon(shore, fill="#626b62")
    draw.line(shore+[shore[0]], fill="#b5c9a6", width=4)
    draw.polygon(reserve, fill="#8c9881")
    for recess in geo.get("pits", []):
        for cell in recess["cells"]:
            draw.polygon(polygon(cell), fill="#174a51", outline="#326269")
    for tile in floor:
        draw.polygon(tile, fill="#adbd9c", outline="#314737")
    for obstacle in geo["obstacles"]:
        blocks_sight = obstacle.get("blocks_line_of_sight", obstacle.get("blocks_sight", False))
        for cell in obstacle["cells"]:
            draw.polygon(polygon(cell), fill="#734854" if blocks_sight else "#c99152")
    for cells, color in [(geo["hero_spawns"], "#4297dd"), (geo["enemy_spawns"], "#dd5542")]:
        for cell in cells:
            draw.polygon(polygon(cell), fill=color)
    draw.ellipse(BOAT, fill="#9c713e", outline="#e6c080", width=4)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 25)
    draw.text((45, 38), "LES ROSEAUX DU TIREUR | ENGINE COMBAT GEOMETRY | 1920 x 1200", font=font, fill="#edf1d8")
    draw.text((45, 1030), "Green: 112 floor cells. Dark teal cells: existing recesses / pits. Orange: 8 low props.", font=font, fill="#edf1d8")
    draw.text((45, 1070), "Blue: hero spawn. Red: enemy anchors. Pale border: 60 px reserve / 100 px shore.", font=font, fill="#edf1d8")
    draw.text((45, 1110), "Brown oval: 280 px boat. Interior recesses may be water; keep actual floor cells readable.", font=font, fill="#edf1d8")
    image.save(OUT/"calibration.png")
    data = {
        "canvas_size": list(CANVAS), "allowed_floor_polygon": reserve, "shore_polygon": shore,
        "boat_region": BOAT, "floor_count": len(floor), "obstacle_count": len(geo["obstacles"]),
        "pit_cell_count": sum(len(p["cells"]) for p in geo.get("pits", [])),
        "floor_bounds": bounds(footprint), "reserve_bounds": bounds(reserve), "shore_bounds": shore_bounds,
        "reserve_margin_px": 60, "shore_margin_px": 100,
        "tile_diagonal_native_px": [abs(ax) + abs(bx), abs(ay) + abs(by)],
        "boat_benches": 3,
        "reserve_semantics": "Outer footprint envelope only. Internal pit and route-cut cells may be open water; the engine retains actual floor and pit rendering.",
        "room_sha256": before["room.tres"], "geometry_sha256": before["geometry_manifest.json"],
        "terrain_plan_sha256": before["terrain_plan.json"],
        "boat_rect_disjoint_from_shore": True,
        "camera_proposal": {"offset": [-120, -30], "zoom_multiplier": 1.0, "keep_painting_in_view": True,
                            "engine_review_required": True},
        "route_reference": {"seed": 2401, "catalog_revision": 4, "node_id": "d05_1", "depth": 5,
                            "kind": "normal", "reward": "ranged", "incoming": ["d04_2"], "outgoing": ["d06_2"],
                            "evidence": "docs/maps/catabase_route_audit_2026-09-11.md; current expedition_route_itineraries.gd"},
        "encounter_reference": {"name": "Les roseaux sifflants", "roster": ["archer", "archer", "archer"],
                                "authority": "core/expedition/catabase_monster_encounter_catalog.gd"},
        "legend": "Green cells: engine floor. Dark teal cells: engine pits; no new walkable islands. Blue/red: hero/enemy anchors. Orange: existing low obstacles. Reserve protects actual floor cells from painted blockers; internal recesses may remain water. Brown oval is boat outside combat. Geometry is never inferred from painting."
    }
    (OUT/"calibration.json").write_text(json.dumps(data, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
    if before != {name: digest(ROOM/name) for name in BASELINE_FILES}:
        raise ValueError("Production room files changed during guide preparation")
    print(json.dumps({"floor_count": len(floor), "floor_bounds": data["floor_bounds"],
                      "boat_region": BOAT, "boat_disjoint_from_shore": True,
                      "guide": str(OUT/"calibration.png"), "baseline": str(BASE)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
