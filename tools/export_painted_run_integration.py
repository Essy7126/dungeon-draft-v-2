#!/usr/bin/env python3
"""Deterministic visual QA exports for the three painted production rooms.

The script reads the explicit Godot resources. It never infers cells from the
background pixels. Pillow is used only to composite validation captures.
"""

from __future__ import annotations

import json
import math
import re
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "artifacts" / "maps" / "painted_run_integration"
BASE_LAYOUT = ROOT / "data" / "maps" / "painted" / "painted_shared_topology.tres"
ROOMS = [
    {
        "id": "room_01_forest",
        "label": "Salle 1 — Forêt / ruines",
        "room": ROOT / "data" / "rooms" / "first_run_room_01.tres",
        "layout": ROOT / "data" / "maps" / "painted" / "room_01_forest_layout.tres",
        "visual": ROOT / "data" / "maps" / "painted" / "room_01_forest_visual.tres",
        "terrain": "NORMAL",
    },
    {
        "id": "room_05_volcano",
        "label": "Salle 5 — Volcan",
        "room": ROOT / "data" / "rooms" / "room_05_volcano.tres",
        "layout": ROOT / "data" / "maps" / "painted" / "room_05_volcano_layout.tres",
        "visual": ROOT / "data" / "maps" / "painted" / "room_05_volcano_visual.tres",
        "terrain": "LAVA (classification neutre existante)",
    },
    {
        "id": "room_06_space",
        "label": "Salle 6 — Espace (finale)",
        "room": ROOT / "data" / "rooms" / "room_06_space.tres",
        "layout": ROOT / "data" / "maps" / "painted" / "room_06_space_layout.tres",
        "visual": ROOT / "data" / "maps" / "painted" / "room_06_space_visual.tres",
        "terrain": "ICE (classification neutre existante)",
    },
]
RESOLUTIONS = {"720p": (1280, 720), "1080p": (1920, 1080), "1440p": (2560, 1440)}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def match(text: str, pattern: str, cast=float):
    found = re.search(pattern, text)
    if not found:
        raise ValueError(f"Missing pattern: {pattern}")
    groups = found.groups()
    values = tuple(cast(value) for value in groups)
    return values[0] if len(values) == 1 else values


def vectors(text: str, field: str, integer: bool = True):
    line = match(text, rf"{field}\s*=\s*Array\[[^]]+\]\(([^\r\n]+)\)", str)
    cast = int if integer else float
    return [
        (cast(x), cast(y))
        for x, y in re.findall(r"Vector2i?\(([-\d.]+),\s*([-\d.]+)\)", line)
    ]


def font(size: int, bold: bool = False):
    name = "arialbd.ttf" if bold else "arial.ttf"
    path = Path("C:/Windows/Fonts") / name
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def valid_png(path: Path, expected_size: tuple[int, int]) -> bool:
    if not path.exists():
        return False
    try:
        with Image.open(path) as image:
            if image.format != "PNG" or image.size != expected_size:
                return False
            image.verify()
        return True
    except (OSError, SyntaxError):
        return False


def save_png(image: Image.Image, target: Path) -> None:
    temporary = target.with_name(target.name + ".tmp")
    image.save(temporary, format="PNG", compress_level=4)
    temporary.replace(target)


def parse_resources(config: dict) -> dict:
    base_text = read(BASE_LAYOUT)
    rows_line = match(base_text, r"layout_rows\s*=\s*PackedStringArray\(([^\r\n]+)\)", str)
    rows = re.findall(r'"([.#XR]+)"', rows_line)
    if len(rows) != 14 or any(len(row) != 14 for row in rows):
        raise ValueError("The shared topology must remain exactly 14x14")

    visual_text = read(config["visual"])
    room_text = read(config["room"])
    layout_text = read(config["layout"])
    rel_image = match(visual_text, r'background_texture_path\s*=\s*"res://([^"]+)"', str)
    origin = match(visual_text, r"grid_origin\s*=\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)")
    axis_x = match(visual_text, r"axis_x\s*=\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)")
    axis_y = match(visual_text, r"axis_y\s*=\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)")
    source_size = match(visual_text, r"source_image_size\s*=\s*Vector2i\((\d+),\s*(\d+)\)", int)
    camera_offset = match(visual_text, r"camera_offset\s*=\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)")
    camera_zoom = match(visual_text, r"camera_zoom\s*=\s*([-\d.]+)")
    anchors = vectors(visual_text, "calibration_cells", integer=True)
    anchor_pixels = vectors(visual_text, "calibration_pixels", integer=False)
    terrain_cells = vectors(layout_text, "terrain_cells", integer=True) if "terrain_cells" in layout_text else []
    hero_spawns = vectors(room_text, "hero_spawn_zone", integer=True)
    enemy_spawns = vectors(room_text, "enemy_spawn_zone", integer=True)
    return {
        **config,
        "rows": rows,
        "image_path": ROOT / rel_image,
        "origin": origin,
        "axis_x": axis_x,
        "axis_y": axis_y,
        "source_size": source_size,
        "camera_offset": camera_offset,
        "camera_zoom": camera_zoom,
        "anchors": anchors,
        "anchor_pixels": anchor_pixels,
        "terrain_cells": set(terrain_cells),
        "hero_spawns": hero_spawns,
        "enemy_spawns": enemy_spawns,
    }


def center(room: dict, cell: tuple[int, int]) -> tuple[float, float]:
    x, y = cell
    return (
        room["origin"][0] + x * room["axis_x"][0] + y * room["axis_y"][0],
        room["origin"][1] + x * room["axis_x"][1] + y * room["axis_y"][1],
    )


def polygon(room: dict, cell: tuple[int, int]):
    cx, cy = center(room, cell)
    ax, ay = room["axis_x"], room["axis_y"]
    return [
        (cx - 0.5 * ax[0] - 0.5 * ay[0], cy - 0.5 * ax[1] - 0.5 * ay[1]),
        (cx + 0.5 * ax[0] - 0.5 * ay[0], cy + 0.5 * ax[1] - 0.5 * ay[1]),
        (cx + 0.5 * ax[0] + 0.5 * ay[0], cy + 0.5 * ax[1] + 0.5 * ay[1]),
        (cx - 0.5 * ax[0] + 0.5 * ay[0], cy - 0.5 * ax[1] + 0.5 * ay[1]),
    ]


def camera(room: dict, size: tuple[int, int]):
    width, height = size
    source_width, source_height = room["source_size"]
    zoom = max(width / source_width, height / source_height) * room["camera_zoom"]
    position = (
        source_width * 0.5 + room["camera_offset"][0],
        source_height * 0.5 + room["camera_offset"][1],
    )
    return zoom, position


def to_screen(room: dict, size: tuple[int, int], point: tuple[float, float]):
    zoom, position = camera(room, size)
    return (
        (point[0] - position[0]) * zoom + size[0] * 0.5,
        (point[1] - position[1]) * zoom + size[1] * 0.5,
    )


def background(room: dict, size: tuple[int, int]) -> Image.Image:
    source = Image.open(room["image_path"]).convert("RGB")
    zoom, position = camera(room, size)
    scaled = source.resize(
        (round(source.width * zoom), round(source.height * zoom)),
        Image.Resampling.LANCZOS,
    )
    left = round(size[0] * 0.5 - position[0] * zoom)
    top = round(size[1] * 0.5 - position[1] * zoom)
    canvas = Image.new("RGB", size, "#05070b")
    canvas.paste(scaled, (left, top))
    return canvas


def symbol(room: dict, cell: tuple[int, int]) -> str:
    x, y = cell
    return room["rows"][y][x]


def walkable(room: dict, cell: tuple[int, int]) -> bool:
    x, y = cell
    return 0 <= x < 14 and 0 <= y < 14 and symbol(room, cell) not in "XR#"


def draw_header(image: Image.Image, title: str, subtitle: str = ""):
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rounded_rectangle((24, 22, min(image.width - 24, 830), 104), 12, fill=(8, 14, 24, 205))
    draw.text((44, 34), title, font=font(max(18, image.width // 70), True), fill="white")
    if subtitle:
        draw.text((44, 70), subtitle, font=font(max(13, image.width // 105)), fill="#c7d9e8")


def draw_grid(image: Image.Image, room: dict, logic=False, calibration=False, spawns=False):
    draw = ImageDraw.Draw(image, "RGBA")
    size = image.size
    palette = {".": (45, 170, 104, 92), "#": (225, 65, 50, 170), "R": (148, 75, 185, 180), "X": (10, 16, 28, 210)}
    special_color = (255, 92, 24, 155) if room["id"] == "room_05_volcano" else (75, 205, 255, 145)
    for y in range(14):
        for x in range(14):
            cell = (x, y)
            poly = [to_screen(room, size, p) for p in polygon(room, cell)]
            cell_symbol = symbol(room, cell)
            if logic:
                fill = special_color if cell in room["terrain_cells"] else palette[cell_symbol]
                draw.polygon(poly, fill=fill)
            if cell_symbol != "X" or logic:
                draw.line(poly + [poly[0]], fill=(90, 235, 255, 205), width=max(1, image.width // 900))
            if calibration or logic:
                c = to_screen(room, size, center(room, cell))
                radius = max(1, image.width // 850)
                draw.ellipse((c[0] - radius, c[1] - radius, c[0] + radius, c[1] + radius), fill=(255, 225, 48, 245))
            if logic and image.width >= 1900:
                c = to_screen(room, size, center(room, cell))
                draw.text((c[0] + 3, c[1] - 8), f"{x},{y}", font=font(10), fill="white", stroke_width=2, stroke_fill="#10131b")
    if spawns:
        for cells, color in [(room["hero_spawns"], (45, 145, 255, 245)), (room["enemy_spawns"], (235, 70, 62, 245))]:
            for cell in cells:
                c = to_screen(room, size, center(room, cell))
                radius = max(5, image.width // 180)
                draw.ellipse((c[0] - radius, c[1] - radius, c[0] + radius, c[1] + radius), fill=color, outline="white", width=2)
    if calibration:
        origin = to_screen(room, size, room["origin"])
        axis_x = to_screen(room, size, (room["origin"][0] + 2 * room["axis_x"][0], room["origin"][1] + 2 * room["axis_x"][1]))
        axis_y = to_screen(room, size, (room["origin"][0] + 2 * room["axis_y"][0], room["origin"][1] + 2 * room["axis_y"][1]))
        draw.line((origin, axis_x), fill=(0, 255, 230, 255), width=4)
        draw.line((origin, axis_y), fill=(255, 40, 215, 255), width=4)
        for cell, measured in zip(room["anchors"], room["anchor_pixels"]):
            predicted = to_screen(room, size, center(room, cell))
            measured_screen = to_screen(room, size, measured)
            draw.line((predicted, measured_screen), fill=(255, 50, 40, 255), width=3)
            r = max(4, image.width // 400)
            draw.ellipse((measured_screen[0] - r, measured_screen[1] - r, measured_screen[0] + r, measured_screen[1] + r), outline="white", width=2)


def draw_units(image: Image.Image, room: dict):
    draw = ImageDraw.Draw(image, "RGBA")
    size = image.size
    units = [(cell, (42, 150, 255, 255), "A") for cell in room["hero_spawns"][:3]]
    units += [(cell, (225, 66, 58, 255), "E") for cell in room["enemy_spawns"]]
    for cell, color, label in sorted(units, key=lambda item: center(room, item[0])[1]):
        foot = to_screen(room, size, center(room, cell))
        scale = size[0] / 1920.0
        draw.ellipse((foot[0] - 19 * scale, foot[1] - 7 * scale, foot[0] + 19 * scale, foot[1] + 7 * scale), fill=(0, 0, 0, 120))
        draw.rounded_rectangle((foot[0] - 10 * scale, foot[1] - 48 * scale, foot[0] + 10 * scale, foot[1] - 8 * scale), radius=6 * scale, fill=color, outline="white", width=max(1, round(2 * scale)))
        draw.ellipse((foot[0] - 9 * scale, foot[1] - 66 * scale, foot[0] + 9 * scale, foot[1] - 48 * scale), fill=color, outline="white", width=max(1, round(2 * scale)))
        draw.text((foot[0] - 4 * scale, foot[1] - 43 * scale), label, font=font(max(10, round(14 * scale)), True), fill="white")


def bfs_path(room: dict, start: tuple[int, int], goal: tuple[int, int]):
    queue = deque([start])
    previous = {start: None}
    while queue:
        current = queue.popleft()
        if current == goal:
            break
        for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            neighbor = (current[0] + dx, current[1] + dy)
            if neighbor not in previous and walkable(room, neighbor):
                previous[neighbor] = current
                queue.append(neighbor)
    if goal not in previous:
        return []
    path = []
    current = goal
    while current is not None:
        path.append(current)
        current = previous[current]
    return list(reversed(path))


def draw_overlay(image: Image.Image, room: dict, spell=False):
    draw = ImageDraw.Draw(image, "RGBA")
    size = image.size
    if spell:
        center_cell = room["enemy_spawns"][0]
        cells = [(x, y) for y in range(14) for x in range(14) if walkable(room, (x, y)) and abs(x - center_cell[0]) + abs(y - center_cell[1]) <= 3]
        fill, outline = (65, 120, 255, 105), (110, 175, 255, 235)
    else:
        cells = bfs_path(room, room["hero_spawns"][0], room["enemy_spawns"][0])
        fill, outline = (55, 235, 115, 105), (90, 255, 145, 235)
    for cell in cells:
        poly = [to_screen(room, size, p) for p in polygon(room, cell)]
        draw.polygon(poly, fill=fill)
        draw.line(poly + [poly[0]], fill=outline, width=max(2, image.width // 700))


def save_room_exports(room: dict):
    out = OUTPUT / room["id"]
    out.mkdir(parents=True, exist_ok=True)
    modes = {
        "background_only": lambda image: None,
        "calibration_grid": lambda image: draw_grid(image, room, calibration=True, spawns=True),
        "deployed_units": lambda image: draw_units(image, room),
        "movement_overlay": lambda image: (draw_units(image, room), draw_overlay(image, room, spell=False)),
        "spell_overlay": lambda image: (draw_units(image, room), draw_overlay(image, room, spell=True)),
        "logic_types": lambda image: draw_grid(image, room, logic=True, spawns=True),
    }
    requested = {
        "720p": ["background_only", "calibration_grid", "deployed_units", "movement_overlay", "spell_overlay"],
        "1080p": ["background_only", "calibration_grid", "logic_types", "deployed_units", "movement_overlay", "spell_overlay"],
        "1440p": ["background_only", "calibration_grid", "deployed_units"],
    }
    for resolution, mode_names in requested.items():
        for mode in mode_names:
            target = out / f"{mode}_{resolution}.png"
            if valid_png(target, RESOLUTIONS[resolution]):
                continue
            image = background(room, RESOLUTIONS[resolution])
            modes[mode](image)
            draw_header(image, room["label"], mode.replace("_", " "))
            save_png(image, target)
    # No clean foreground exists: the on/off proof intentionally remains
    # identical and states that no approximate mask was generated.
    foreground_target = out / "foreground_on_off_1080p.png"
    if valid_png(foreground_target, RESOLUTIONS["1080p"]):
        return
    base = background(room, RESOLUTIONS["1080p"])
    draw_units(base, room)
    left = base.resize((960, 1080), Image.Resampling.LANCZOS)
    right = base.resize((960, 1080), Image.Resampling.LANCZOS)
    comparison = Image.new("RGB", (1920, 1080))
    comparison.paste(left, (0, 0))
    comparison.paste(right, (960, 0))
    draw_header(comparison, f"{room['label']} — foreground OFF / ON", "Aucun masque propre disponible : rendu identique, système prêt")
    save_png(comparison, foreground_target)


def panel(image: Image.Image, size=(960, 1080)) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, "#080d16")
    canvas.paste(copy, ((size[0] - copy.width) // 2, (size[1] - copy.height) // 2))
    return canvas


def transition_export(filename: str, left_room: dict, right_room: dict, title: str):
    canvas = Image.new("RGB", (1920, 1080), "#080d16")
    canvas.paste(background(left_room, (960, 1080)), (0, 0))
    canvas.paste(background(right_room, (960, 1080)), (960, 0))
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.polygon([(900, 520), (980, 520), (980, 485), (1040, 540), (980, 595), (980, 560), (900, 560)], fill=(255, 220, 65, 240))
    draw_header(canvas, title, "Transition autoritaire de la run")
    save_png(canvas, OUTPUT / filename)


def extra_exports(rooms: list[dict]):
    old_path = ROOT / "asset" / "map" / "iso" / "forest_room_01_source.png"
    old = Image.open(old_path).convert("RGB")
    after = background(rooms[0], (960, 1080))
    before_after = Image.new("RGB", (1920, 1080), "#080d16")
    before_after.paste(panel(old), (0, 0))
    before_after.paste(after, (960, 0))
    draw_header(before_after, "Salle 1 — avant / après", "Ancienne calibration 10×8 → nouvelle forêt 14×14")
    save_png(before_after, OUTPUT / "room_01_before_after.png")

    # Room 4 art remains untouched; use its production background when present.
    room4_image = Image.open(ROOT / "asset" / "Background" / "montagne 2.webp").convert("RGB")
    pseudo_room4 = rooms[1].copy()
    pseudo_room4["image_path"] = ROOT / "asset" / "Background" / "montagne 2.webp"
    pseudo_room4["source_size"] = room4_image.size
    pseudo_room4["camera_offset"] = (0.0, 0.0)
    pseudo_room4["camera_zoom"] = 1.1
    transition_export("room_04_to_05_transition.png", pseudo_room4, rooms[1], "Salle 4 → Salle 5 volcan")
    transition_export("room_05_to_06_transition.png", rooms[1], rooms[2], "Salle 5 volcan → Salle 6 espace")

    result = Image.new("RGB", (960, 1080), "#080d16")
    draw = ImageDraw.Draw(result, "RGBA")
    draw.rounded_rectangle((115, 270, 845, 810), 28, fill=(20, 27, 42, 245), outline=(130, 165, 210, 255), width=3)
    draw.text((330, 360), "VICTOIRE", font=font(64, True), fill="#63ef86")
    draw.text((315, 470), "Run : Première run", font=font(30), fill="white")
    draw.rounded_rectangle((320, 620, 640, 700), 14, fill=(55, 76, 112, 255))
    draw.text((405, 640), "Retour", font=font(28, True), fill="white")
    final = Image.new("RGB", (1920, 1080), "#080d16")
    final.paste(background(rooms[2], (960, 1080)), (0, 0))
    final.paste(result, (960, 0))
    draw_header(final, "Salle 6 → RunResultScreen", "Aucune salle 7")
    save_png(final, OUTPUT / "room_06_to_run_result.png")


def error_report(rooms: list[dict]):
    report = {}
    for room in rooms:
        errors = [math.dist(center(room, cell), pixel) for cell, pixel in zip(room["anchors"], room["anchor_pixels"])]
        points = [point for y in range(14) for x in range(14) for point in polygon(room, (x, y))]
        bounds = {
            "x": min(point[0] for point in points),
            "y": min(point[1] for point in points),
            "width": max(point[0] for point in points) - min(point[0] for point in points),
            "height": max(point[1] for point in points) - min(point[1] for point in points),
        }
        report[room["id"]] = {
            "origin": room["origin"],
            "axis_x": room["axis_x"],
            "axis_y": room["axis_y"],
            "anchors": [
                {"cell": cell, "pixel": pixel, "error_px_source": error}
                for cell, pixel, error in zip(room["anchors"], room["anchor_pixels"], errors)
            ],
            "rms_px_source": math.sqrt(sum(error * error for error in errors) / len(errors)),
            "max_error_px_source": max(errors),
            "rms_px_1920x1080": math.sqrt(sum(error * error for error in errors) / len(errors)) * 1.40625 * room["camera_zoom"],
            "max_error_px_1920x1080": max(errors) * 1.40625 * room["camera_zoom"],
            "grid_bounding_box": bounds,
            "image_dimensions": room["source_size"],
            "camera_offset": room["camera_offset"],
            "camera_zoom": room["camera_zoom"],
        }
    (OUTPUT / "calibration_error_report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rooms = [parse_resources(config) for config in ROOMS]
    for room in rooms:
        save_room_exports(room)
    extra_exports(rooms)
    error_report(rooms)
    outputs = list(OUTPUT.rglob("*.png")) + list(OUTPUT.rglob("*.json"))
    print(f"Painted run integration: {len(outputs)} exports in {OUTPUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
