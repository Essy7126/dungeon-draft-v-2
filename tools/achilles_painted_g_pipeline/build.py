"""Higgsfield sandbox only: python build.py input.json [--inspect].
See README.md for schema and runtime contracts.
Requires Pillow/numpy; scipy speeds component cleanup.
"""
import hashlib
import io
import json
import math
import re
import sys
import urllib.parse
import urllib.request
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

CANVAS = (512, 384)
ANCHOR = (256, 320)
ASSET_PATH = "res://assets/characters/Achilles/sprites_painted_g/"
DIRECTIONS = "NESW"
GROUPS = {
    "locomotion": {"rows": 4, "clips": {"idle": list(range(4)),
        "walk": list(range(4, 12)), "attack": list(range(12, 16))}},
    "base": {"rows": 3, "clips": {"dash": list(range(4)),
        "bow": list(range(4, 8)), "guard": list(range(8, 12))}},
    "extra": {"rows": 4, "clips": {"sweep": list(range(4)),
        "volley": list(range(4, 8)), "hit": list(range(8, 12)),
        "death": list(range(12, 16))}},
}
BOOKENDS = {"bow", "guard", "sweep", "volley"}
DURATIONS = {"idle": 2.0, "walk": .56, "attack": .60, "dash": 1.20,
    "bow": .72, "guard": .48, "sweep": .72, "volley": .72,
    "hit": .24, "death": .48}
RELEASES = {"attack": .30, "dash": .10, "bow": .36, "guard": .24,
    "sweep": .36, "volley": .36}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding="utf-8")


def download(url):
    parsed = urllib.parse.urlparse(url)
    host = (parsed.hostname or "").lower()
    if parsed.scheme != "https" or not (host.endswith(".cloudfront.net") or
            host == "higgsfield.ai" or host.endswith(".higgsfield.ai")):
        raise ValueError("Only HTTPS Higgsfield/CloudFront source URLs are allowed")
    with urllib.request.urlopen(url, timeout=90) as response:
        return response.read()


def tiny_components(mask, maximum=3):
    """Only discard disconnected specks of at most three source pixels."""
    removed = np.zeros(mask.shape, dtype=bool)
    summaries = []
    try:
        from scipy.ndimage import label, find_objects
        labels, count = label(mask, structure=np.ones((3, 3), dtype=np.uint8))
        areas = np.bincount(labels.ravel())
        objects = find_objects(labels)
        for number in range(1, count + 1):
            if areas[number] > maximum:
                continue
            region = objects[number - 1]
            if region is None:
                continue
            removed[region] |= labels[region] == number
            summaries.append({"area": int(areas[number]), "bbox": [region[1].start,
                region[0].start, region[1].stop, region[0].stop]})
    except ImportError:
        visited = np.zeros(mask.shape, dtype=bool)
        height, width = mask.shape
        for y, x in zip(*np.nonzero(mask)):
            if visited[y, x]:
                continue
            queue = deque([(int(x), int(y))])
            visited[y, x] = True
            points = []
            area = 0
            while queue:
                px, py = queue.pop()
                area += 1
                if area <= maximum:
                    points.append((px, py))
                for ny in range(max(0, py - 1), min(height, py + 2)):
                    for nx in range(max(0, px - 1), min(width, px + 2)):
                        if mask[ny, nx] and not visited[ny, nx]:
                            visited[ny, nx] = True
                            queue.append((nx, ny))
            if area <= maximum:
                for px, py in points:
                    removed[py, px] = True
                xs, ys = zip(*points)
                summaries.append({"area": area, "bbox": [min(xs), min(ys), max(xs)+1, max(ys)+1]})
    return removed, summaries


def chroma_key(cell):
    src = np.array(cell.convert("RGBA"))
    rgb = src[:, :, :3].astype(np.float32)
    dominance = np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1]
    eligible = (np.minimum(rgb[:, :, 0], rgb[:, :, 2]) > 60) & (dominance > 30)
    factor = np.where(eligible, np.clip((110 - dominance) / 70, 0, 1), 1)
    alpha = np.rint(src[:, :, 3] * factor).astype(np.uint8)
    partial = (factor > 0) & (factor < 1) & (src[:, :, 3] > 0)
    unmixed = np.clip((rgb - (1 - factor[:, :, None]) * [255, 0, 255]) /
        np.maximum(factor[:, :, None], 1 / 255), 0, 255)
    result = src.copy()
    result[:, :, :3][partial] = np.rint(unmixed[partial]).astype(np.uint8)
    result[:, :, 3] = alpha
    specks, components = tiny_components(alpha > 0)
    result[:, :, 3][specks] = 0
    edge = partial & (result[:, :, 3] > 0)
    clean = result[:, :, :3].astype(np.float32)
    residual = np.maximum(np.minimum(clean[:, :, 0], clean[:, :, 2]) - clean[:, :, 1] - 18, 0)
    clean[:, :, 0][edge] -= residual[edge]
    clean[:, :, 2][edge] -= residual[edge]
    result[:, :, :3] = np.clip(np.rint(clean), 0, 255).astype(np.uint8)
    result[:, :, :3][result[:, :, 3] == 0] = 0
    border = np.concatenate((result[0, :, 3], result[-1, :, 3], result[:, 0, 3], result[:, -1, 3]))
    border_fraction = float((border > 32).mean())
    if border_fraction >= .01:
        raise ValueError("Magenta key leaves %.2f%% opaque border pixels; inspect background or true source clipping" % (border_fraction * 100))
    return Image.fromarray(result), {"keyType": "magenta", "keyColor": [255, 0, 255],
        "dominanceTransparentAt": 110, "dominanceOpaqueBelow": 40,
        "borderForegroundFraction": border_fraction,
        "alphaChanged": int((result[:, :, 3] != src[:, :, 3]).sum()),
        "pixelsChanged": int(np.any(result != src, axis=2).sum()),
        "transparentPixels": int((result[:, :, 3] == 0).sum()),
        "softAlphaPixels": int(((result[:, :, 3] > 0) & (result[:, :, 3] < 255)).sum()),
        "removedSpeckPixels": int(specks.sum()), "removedSpeckComponents": components,
        "removalPolicy": "Remove disconnected <=3px specks only."}


def border_connected(mask, seeds=()):
    try:
        from scipy.ndimage import label
        labels, _ = label(mask, structure=np.ones((3, 3), dtype=np.uint8))
        seed_labels = np.array([labels[y, x] for x, y in seeds], dtype=labels.dtype)
        touched = np.unique(np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1], seed_labels)))
        return np.isin(labels, touched[touched != 0])
    except ImportError:
        height, width = mask.shape
        connected = np.zeros(mask.shape, dtype=bool)
        queue = deque()
        for x in range(width):
            for y in (0, height - 1):
                if mask[y, x] and not connected[y, x]:
                    connected[y, x] = True
                    queue.append((x, y))
        for y in range(height):
            for x in (0, width - 1):
                if mask[y, x] and not connected[y, x]:
                    connected[y, x] = True
                    queue.append((x, y))
        for x, y in seeds:
            if mask[y, x] and not connected[y, x]:
                connected[y, x] = True
                queue.append((x, y))
        while queue:
            x, y = queue.pop()
            for ny in range(max(0, y - 1), min(height, y + 2)):
                for nx in range(max(0, x - 1), min(width, x + 2)):
                    if mask[ny, nx] and not connected[ny, nx]:
                        connected[ny, nx] = True
                        queue.append((nx, ny))
        return connected


def validate_background_seeds(src, key_color, seeds):
    if seeds is None:
        return []
    if not isinstance(seeds, (list, tuple)):
        raise ValueError("backgroundSeeds must be a list of integer [x,y] coordinates")
    bg = np.asarray(key_color, dtype=np.float32)
    if bg.shape != (3,) or not np.isfinite(bg).all() or np.any(bg < 0) or np.any(bg > 255):
        raise ValueError("keyColor must contain three finite RGB values in [0,255]")
    height, width = src.shape[:2]
    audit = []
    for seed in seeds:
        if not isinstance(seed, (list, tuple)) or len(seed) != 2 or any(
                not isinstance(v, (int, np.integer)) or isinstance(v, (bool, np.bool_)) for v in seed):
            raise ValueError("Each background seed must be an integer [x,y] pair")
        x, y = map(int, seed)
        if not (0 <= x < width and 0 <= y < height):
            raise ValueError("Background seed outside source: " + str(seed))
        pixel = src[y, x]
        distance = float(np.max(np.abs(pixel[:3].astype(np.float32) - bg)))
        if distance > 18:
            raise ValueError("Background seed %s is not close to keyColor (RGB%s, distance %.1f >18)" %
                (seed, pixel[:3].tolist(), distance))
        audit.append({"point": [x, y], "rgb": pixel[:3].tolist(), "alpha": int(pixel[3]),
            "distanceToKeyColor": distance})
    return audit


def solid_key(cell, key_color, background_seeds=None):
    bg = np.asarray(key_color, dtype=np.float32)
    if bg.shape != (3,) or not np.isfinite(bg).all() or np.any(bg < 0) or np.any(bg > 255):
        raise ValueError("keyColor must contain three finite RGB values in [0,255]")
    src = np.array(cell.convert("RGBA"))
    seeds = validate_background_seeds(src, bg, background_seeds)
    rgb = src[:, :, :3].astype(np.float32)
    distance = np.max(np.abs(rgb - bg), axis=2)
    similar = (distance <= 40) | (src[:, :, 3] == 0)
    border_only = border_connected(similar)
    connected = border_connected(similar, [item["point"] for item in seeds]) if seeds else border_only
    factor = np.ones(distance.shape, dtype=np.float32)
    factor[connected] = np.clip((distance[connected] - 18) / 22, 0, 1)
    partial = connected & (factor > 0) & (factor < 1) & (src[:, :, 3] > 0)
    result = src.copy()
    result[:, :, 3] = np.rint(src[:, :, 3] * factor).astype(np.uint8)
    unmatte = np.clip((rgb - (1 - factor[:, :, None]) * bg) /
        np.maximum(factor[:, :, None], 1 / 255), 0, 255)
    result[:, :, :3][partial] = np.rint(unmatte[partial]).astype(np.uint8)
    result[:, :, :3][result[:, :, 3] == 0] = 0
    opaque_source = src[:, :, 3] > 0
    removed = opaque_source & (result[:, :, 3] == 0)
    enclosed = similar & ~connected & opaque_source
    return Image.fromarray(result), {"keyType": "border-and-seed-solid-color" if seeds else "border-connected-solid-color",
        "keyColor": bg.tolist(), "transparentTolerance": 18, "softTolerance": 40,
        "backgroundSeeds": seeds, "seedCoordinateSpace": "input-image-pixels",
        "borderConnectedPixels": int(border_only.sum()), "borderOrSeedConnectedPixels": int(connected.sum()),
        "seedConnectedPixelsAdded": int((connected & ~border_only).sum()),
        "seedFullyKeyedPixels": int((removed & ~border_only).sum()), "fullyKeyedPixels": int(removed.sum()),
        "softEdgePixels": int(partial.sum()), "enclosedSimilarPixelsRetained": int(enclosed.sum()),
        "pixelsChanged": int(np.any(result != src, axis=2).sum()),
        "transparentPixels": int((result[:, :, 3] == 0).sum()),
        "softAlphaPixels": int(((result[:, :, 3] > 0) & (result[:, :, 3] < 255)).sum()),
        "removalPolicy": "Color-similar regions connected to borders or explicit validated seeds; other enclosed colors preserved."}


def remove_detached_projectiles(cell, nominal_size=None):
    rgba = np.array(cell.convert("RGBA"))
    core = rgba[:, :, 3] > 32
    height, width = core.shape
    nominal_width, nominal_height = nominal_size or cell.size
    try:
        from scipy.ndimage import label
        labels, count = label(core, structure=np.ones((3, 3), dtype=np.uint8))
    except ImportError:
        labels = np.zeros(core.shape, dtype=np.int32)
        count = 0
        for y, x in zip(*np.nonzero(core)):
            if labels[y, x]:
                continue
            count += 1
            labels[y, x] = count
            queue = deque([(int(x), int(y))])
            while queue:
                px, py = queue.pop()
                for ny in range(max(0, py - 1), min(height, py + 2)):
                    for nx in range(max(0, px - 1), min(width, px + 2)):
                        if core[ny, nx] and not labels[ny, nx]:
                            labels[ny, nx] = count
                            queue.append((nx, ny))
    areas = np.bincount(labels.ravel(), minlength=count + 1)
    largest = int(np.argmax(areas[1:]) + 1) if count else 0
    removed = np.zeros(core.shape, dtype=bool)
    details = []
    for number in range(1, count + 1):
        if number == largest or areas[number] >= nominal_width * nominal_height * .01:
            continue
        ys, xs = np.where(labels == number)
        x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
        w, h = x1 - x0, y1 - y0
        if w < 20 or h > max(10, nominal_height * .04) or w / h < 5:
            continue
        selected = labels == number
        for _ in range(2):
            padded = np.pad(selected, 1)
            near = np.zeros(core.shape, dtype=bool)
            for dy in range(3):
                for dx in range(3):
                    near |= padded[dy:dy + height, dx:dx + width]
            selected |= near & (rgba[:, :, 3] > 0) & (rgba[:, :, 3] <= 32)
        removed |= selected
        details.append({"bbox": [x0, y0, x1, y1], "corePixels": int(areas[number]),
            "removedPixels": int(selected.sum()), "reason": "Detached projectile; gameplay owns projectile rendering."})
    rgba[removed] = 0
    return Image.fromarray(rgba), {"enabled": True, "alphaThreshold": 32,
        "largestComponentPreserved": largest, "removedPixels": int(removed.sum()),
        "components": details, "policy": "Isolated horizontal component: width>=20, aspect>=5, height<=max(10,cellHeight*.04), area<1%cell; other clips untouched."}


def split_global_equipment(sheet, source, xb, yb, audit_path):
    try:
        from scipy.ndimage import label, find_objects, center_of_mass, distance_transform_edt
    except ImportError as error:
        raise ValueError("preserveCrossCellEquipment requires scipy in the Higgsfield sandbox") from error
    if source.get("backgroundSeeds") and "keyColor" not in source:
        raise ValueError("backgroundSeeds requires an explicit keyColor")
    keyed, key_report = solid_key(sheet, source["keyColor"], source.get("backgroundSeeds")) \
        if "keyColor" in source else chroma_key(sheet)
    rgba = np.array(keyed)
    alpha = rgba[:, :, 3]
    core = alpha > 32
    height, width = core.shape
    columns, rows = len(xb) - 1, len(yb) - 1
    expected = columns * rows
    labels, count = label(core, structure=np.ones((3, 3), dtype=np.uint8))
    areas = np.bincount(labels.ravel(), minlength=count + 1)
    boxes = find_objects(labels)
    centers = center_of_mass(core, labels, list(range(1, count + 1))) if count else []
    component_ids = sorted(range(1, count + 1), key=lambda number: -areas[number])
    body_ids = component_ids[:expected]
    median_area = float(np.median([areas[i] for i in body_ids])) if body_ids else 0
    owner_by_component = np.full(count + 1, -1, dtype=np.int32)
    owners = {}
    errors = []
    report = {"enabled": True, "coreAlpha": 32, "expectedBodies": expected,
        "componentCount": count, "bodyIds": body_ids, "components": [], "errors": errors,
        "key": key_report, "coordinates": "Global source pixels; final roots remain nominal-cell-local."}
    if count < expected:
        errors.append("Fewer connected components than poses: possible merged bodies or missing cell")
    cell_map = np.searchsorted(yb[1:], np.arange(height), side="right")[:, None] * columns + \
        np.searchsorted(xb[1:], np.arange(width), side="right")[None, :]
    for number in body_ids:
        cy, cx = centers[number - 1]
        column = int(np.searchsorted(xb[1:], cx, side="right"))
        row = int(np.searchsorted(yb[1:], cy, side="right"))
        owner = row * columns + column
        if owner in owners:
            errors.append("Two dominant components map to cell %s (ids %s,%s)" % (owner, owners[owner], number))
        owners[owner] = number
        owner_by_component[number] = owner
        if areas[number] < median_area * .25:
            errors.append("Dominant component %s too small for a body; possible missing/fused pose" % number)
        occupancy = np.bincount(cell_map[labels == number], minlength=expected)
        second = np.sort(occupancy)[-2] if expected > 1 else 0
        if second > median_area * .35:
            errors.append("Component %s contains substantial bodies in multiple cells; possible fusion" % number)
    missing = sorted(set(range(expected)) - set(owners))
    if missing:
        errors.append("Cells without a unique dominant body: " + str(missing))
    if errors:
        report["bodyCandidates"] = [{"id": n, "area": int(areas[n]),
            "centroid": [float(centers[n-1][1]), float(centers[n-1][0])]} for n in body_ids]
        write_json(audit_path, report)
        raise ValueError(source["key"] + ": " + "; ".join(errors))
    seed_owners = np.zeros(core.shape, dtype=np.int32)
    for number in body_ids:
        seed_owners[labels == number] = owner_by_component[number] + 1
    _, nearest = distance_transform_edt(seed_owners == 0, return_indices=True)
    nearest_body = seed_owners[nearest[0], nearest[1]] - 1
    del nearest, seed_owners
    overrides = source.get("componentOwners", {})
    if not isinstance(overrides, dict):
        raise ValueError("componentOwners must map component ids to nominal cell indices")
    for key, value in overrides.items():
        if not str(key).isdigit() or int(key) not in component_ids or isinstance(value, bool) or \
                not isinstance(value, int) or not 0 <= value < expected or int(key) in body_ids:
            raise ValueError("Invalid secondary component owner override: " + str(key))
    for number in component_ids:
        region = boxes[number - 1]
        bbox = [region[1].start, region[0].start, region[1].stop, region[0].stop]
        cy, cx = centers[number - 1]
        confidence = 1.0
        method = "dominant-body-centroid"
        if number not in body_ids:
            votes = np.bincount(nearest_body[labels == number], minlength=expected)
            owner = int(np.argmax(votes))
            confidence = float(votes[owner] / areas[number])
            method = "nearest-body-majority"
            override = overrides.get(str(number), overrides.get(number))
            if override is not None:
                owner, confidence, method = override, 1.0, "explicit-owner-override"
            elif confidence < .60:
                errors.append("Ambiguous secondary component %s bbox%s (nearest-body share %.3f); inspect and set componentOwners" % (number, bbox, confidence))
            owner_by_component[number] = owner
        report["components"].append({"id": number, "corePixels": int(areas[number]), "bbox": bbox,
            "centroid": [float(cx), float(cy)], "owner": int(owner_by_component[number]),
            "assignment": method, "confidence": confidence})
    if errors:
        write_json(audit_path, report)
        raise ValueError(source["key"] + ": " + "; ".join(errors))
    del nearest_body, cell_map
    distances, nearest = distance_transform_edt(labels == 0, return_indices=True)
    nearest_component = labels[nearest[0], nearest[1]]
    pixel_owners = owner_by_component[nearest_component]
    pixel_owners[alpha == 0] = -1
    report["softPixelsBeyondTwoPixelFringeRetained"] = int(((alpha > 0) & ~core & (distances > 2)).sum())
    del nearest, nearest_component, distances, labels
    result = []
    alpha_sum = 0
    for index in range(expected):
        owned = (pixel_owners == index) & (alpha > 0)
        ys, xs = np.where(owned)
        if not len(xs):
            raise ValueError("Empty assigned global pose: " + str(index))
        x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1
        cropped = rgba[y0:y1, x0:x1].copy()
        cropped[~owned[y0:y1, x0:x1]] = 0
        column, row = index % columns, index // columns
        nominal = [xb[column], yb[row], xb[column + 1], yb[row + 1]]
        measurement_y = [min(nominal[1], y0), max(nominal[3], y1)]
        measured = rgba[measurement_y[0]:measurement_y[1], nominal[0]:nominal[2]].copy()
        measured[~owned[measurement_y[0]:measurement_y[1], nominal[0]:nominal[2]]] = 0
        crop_alpha = int(cropped[:, :, 3].astype(np.uint64).sum())
        alpha_sum += crop_alpha
        result.append({"image": Image.fromarray(cropped), "measurementImage": Image.fromarray(measured),
            "measurementOrigin": [0, measurement_y[0] - nominal[1]],
            "cropRect": [x0, y0, x1, y1], "cropOrigin": [x0 - nominal[0], y0 - nominal[1]],
            "assignedComponentIds": [int(n) for n in component_ids if owner_by_component[n] == index],
            "assignedAlphaSum": crop_alpha})
    report["sourceAlphaSum"] = int(alpha.astype(np.uint64).sum())
    report["assignedAlphaSum"] = alpha_sum
    report["unassignedCorePixels"] = int((core & (pixel_owners < 0)).sum())
    if alpha_sum != report["sourceAlphaSum"] or report["unassignedCorePixels"]:
        errors.append("Global assignment lost or duplicated source alpha")
    write_json(audit_path, report)
    if errors:
        raise ValueError(source["key"] + ": " + "; ".join(errors))
    return result, report


def measure(cell):
    rgba = np.array(cell)
    alpha = rgba[:, :, 3]
    mask = alpha > 48
    height, width = mask.shape
    ys, xs = np.where(mask)
    if not len(xs):
        raise ValueError("Empty pose after keying")
    left, right = round(width * .34), round(width * .66)
    corridor = mask[:, left:right]
    row_width = corridor.sum(axis=1)
    rows = np.flatnonzero(row_width >= max(3, round(width * .018)))
    if not len(rows):
        raise ValueError("No central body contact; explicit roots are required")
    floor = int(rows[-1])
    top = int(rows[0])
    y0, y1 = round(top + (floor - top) * .48), round(top + (floor - top) * .72)
    rgb = rgba[y0:y1, left:right, :3].astype(np.float32)
    cloth = (rgb[:, :, 2] > rgb[:, :, 0] * 1.1) & (rgb[:, :, 1] > rgb[:, :, 0] * 1.1) & \
        (rgb[:, :, 1] < 100) & (rgb[:, :, 2] < 120) & (alpha[y0:y1, left:right] > 96)
    _, cloth_x = np.where(cloth)
    suggested_x = float(np.median(cloth_x) + left) if len(cloth_x) >= 16 else width / 2
    return [width / 2, floor], {"bodyHeightEstimate": max(1, floor - top + 1),
        "rootMeasured": [width / 2, floor], "rootSuggested": [suggested_x, floor],
        "pelvisSuggestion": {"status": "REVIEW_REQUIRED" if len(cloth_x) >= 16 else "NO_RELIABLE_CLOTH",
            "blueClothPixels": int(len(cloth_x)), "searchBand": [left, y0, right, y1], "appliedToX": False},
        "bodyCorridor": [left, top, right, floor + 1],
        "bbox": [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1],
        "sourceTouchesEdge": bool(xs.min() == 0 or ys.min() == 0 or
            xs.max() == width - 1 or ys.max() == height - 1)}


def pack(cell, scale, root, crop_origin=(0, 0)):
    size = (max(1, round(cell.width * scale)), max(1, round(cell.height * scale)))
    resized = cell.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")
    offset = tuple(round(ANCHOR[i] - (root[i] - crop_origin[i]) * scale) for i in range(2))
    bounds = resized.getbbox()
    if bounds is None:
        raise ValueError("Empty pose after scaling")
    placed = [bounds[0] + offset[0], bounds[1] + offset[1], bounds[2] + offset[0], bounds[3] + offset[1]]
    outside = placed[0] < 0 or placed[1] < 0 or placed[2] > CANVAS[0] or placed[3] > CANVAS[1]
    result = Image.new("RGBA", CANVAS)
    result.alpha_composite(resized, offset)
    input_alpha = int(np.asarray(resized)[:, :, 3].astype(np.uint64).sum())
    output_alpha = int(np.asarray(result)[:, :, 3].astype(np.uint64).sum())
    return result, {"root": root, "offset": list(offset), "placedBbox": placed,
        "clipped": outside, "alphaSumBeforePlacement": input_alpha,
        "alphaSumAfterPlacement": output_alpha, "alphaLoss": input_alpha - output_alpha}


def contact(images, labels, columns=4, size=(256, 192), anchor=False):
    rows = math.ceil(len(images) / columns)
    board = Image.new("RGB", (columns * size[0], rows * (size[1] + 24)), "#263742")
    draw = ImageDraw.Draw(board)
    for index, (im, label) in enumerate(zip(images, labels)):
        x, y = index % columns * size[0], index // columns * (size[1] + 24)
        preview = im.copy()
        preview.thumbnail(size, Image.Resampling.LANCZOS)
        dx, dy = x + (size[0] - preview.width) // 2, y + (size[1] - preview.height) // 2
        board.paste(preview, (dx, dy), preview)
        draw.text((x + 5, y + size[1] + 4), label, fill="white")
        if anchor and im.size == CANVAS:
            ax, ay = dx + ANCHOR[0] * preview.width / im.width, dy + ANCHOR[1] * preview.height / im.height
            draw.line((ax - 4, ay, ax + 4, ay), fill="#70ddd0")
            draw.line((ax, ay - 4, ax, ay + 4), fill="#70ddd0")
    return board


def clip_delays(stem, count):
    if stem == "dash":
        return [50, 50, 480, 80]
    release_frame = 3
    if stem in RELEASES:
        before = RELEASES[stem] * 1000 / release_frame
        after = (DURATIONS[stem] - RELEASES[stem]) * 1000 / (count - release_frame)
        return [round(before)] * release_frame + [round(after)] * (count - release_frame)
    return [round(DURATIONS[stem] * 1000 / count)] * count


def save_gif(path, frames, stem):
    pictures = []
    for frame in frames:
        background = Image.new("RGB", CANVAS, "#263742")
        background.paste(frame, (0, 0), frame)
        pictures.append(background)
    delays = clip_delays(stem, len(frames))
    options = {"save_all": True, "append_images": pictures[1:], "duration": delays,
        "disposal": 2, "optimize": False}
    if stem in {"idle", "walk"}:
        options["loop"] = 0
    pictures[0].save(path, **options)
    return delays


def sprite_frames_resource(clips):
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(clips) + sum(len(c["frames"]) for c in clips) + 1} format=3]', ""]
    for number, clip in enumerate(clips, 1):
        lines.append(f'[ext_resource type="Texture2D" path="{ASSET_PATH}atlases/{clip["name"]}.png" id="{number}"]')
    lines.append("")
    for number, clip in enumerate(clips, 1):
        for frame in range(len(clip["frames"])):
            x, y = frame % 4 * CANVAS[0], frame // 4 * CANVAS[1]
            lines.extend([f'[sub_resource type="AtlasTexture" id="{clip["name"]}_{frame}"]',
                f'atlas = ExtResource("{number}")', f'region = Rect2({x}, {y}, {CANVAS[0]}, {CANVAS[1]})', ""])
    lines.extend(["[resource]", "animations = ["])
    for number, clip in enumerate(clips):
        lines.append('{"frames": [')
        for index in range(len(clip["frames"])):
            comma = "," if index + 1 < len(clip["frames"]) else ""
            lines.append('{"duration": 1.0, "texture": SubResource("%s_%s")}%s' % (clip["name"], index, comma))
        loop = "true" if clip["stem"] in {"idle", "walk"} else "false"
        speed = 20.0 if clip["stem"] == "dash" else len(clip["frames"]) / DURATIONS[clip["stem"]]
        lines.append('], "loop": %s, "name": &"%s", "speed": %.12g}%s' %
            (loop, clip["name"], speed, "," if number + 1 < len(clips) else ""))
    lines.append("]\n")
    return "\n".join(lines)


def run(config, inspect_only=False):
    out = Path(config["outDir"])
    for folder in ["sources", "atlases", "frames", "contacts", "previews"]:
        (out / folder).mkdir(parents=True, exist_ok=True)
    expected = {f"{group}_{direction}" for group in GROUPS for direction in DIRECTIONS}
    seen, all_frames, reports = set(), {}, []
    failures = []
    for source in config["sources"]:
        key = source["key"]
        if key not in expected or key in seen or not re.fullmatch(r"(locomotion|base|extra)_[NESW]", key):
            raise ValueError("Invalid or duplicate source key: " + key)
        seen.add(key)
        group, direction = key.rsplit("_", 1)
        if not isinstance(source.get("removeDetachedProjectiles", False), bool):
            raise ValueError("removeDetachedProjectiles must be boolean: " + key)
        if not isinstance(source.get("preserveCrossCellEquipment", False), bool):
            raise ValueError("preserveCrossCellEquipment must be boolean: " + key)
        columns, rows = int(source.get("columns", 4)), int(source.get("rows", GROUPS[group]["rows"]))
        if columns != 4 or rows != GROUPS[group]["rows"]:
            raise ValueError("Source layout mismatch: " + key)
        raw = download(source["url"])
        decoded = Image.open(io.BytesIO(raw))
        extension = {"PNG": ".png", "JPEG": ".jpg", "WEBP": ".webp"}.get(decoded.format, ".bin")
        raw_path = out / "sources" / (key + extension)
        raw_path.write_bytes(raw)
        sheet = decoded.convert("RGBA")
        if source.get("backgroundSeeds") and "keyColor" not in source:
            raise ValueError("backgroundSeeds requires an explicit keyColor: " + key)
        seed_audit = validate_background_seeds(np.array(sheet), source["keyColor"], source.get("backgroundSeeds")) \
            if "backgroundSeeds" in source and "keyColor" in source else []
        xb = [round(i * sheet.width / columns) for i in range(columns + 1)]
        yb = [round(i * sheet.height / rows) for i in range(rows + 1)]
        global_cells, global_report = None, None
        if source.get("preserveCrossCellEquipment", False):
            global_cells, global_report = split_global_equipment(sheet, source, xb, yb,
                out / "sources" / (key + "_segmentation.json"))
        manual_roots = source.get("roots")
        if manual_roots is not None and (len(manual_roots) != columns * rows or
                any(len(root) != 2 for root in manual_roots)):
            raise ValueError("Explicit roots must contain one xy pair per source cell: " + key)
        cells, entries = [], []
        for index in range(columns * rows):
            c, r = index % columns, index // columns
            rect = (xb[c], yb[r], xb[c + 1], yb[r + 1])
            nominal_size = (rect[2] - rect[0], rect[3] - rect[1])
            crop_origin = [0, 0]
            measurement_origin = [0, 0]
            crop_rect = list(rect)
            assignment = None
            if global_cells is not None:
                assignment = global_cells[index]
                cell, measurement_cell = assignment["image"], assignment["measurementImage"]
                crop_origin, crop_rect = assignment["cropOrigin"], assignment["cropRect"]
                measurement_origin = assignment["measurementOrigin"]
                key_report = {"keyType": global_report["key"]["keyType"],
                    "keyColor": global_report["key"]["keyColor"], "scope": "sheet",
                    "audit": "sources/" + key + "_segmentation.json"}
            else:
                original_cell = sheet.crop(rect)
                local_seeds = [[item["point"][0] - rect[0], item["point"][1] - rect[1]] for item in seed_audit
                    if rect[0] <= item["point"][0] < rect[2] and rect[1] <= item["point"][1] < rect[3]]
                cell, key_report = solid_key(original_cell, source["keyColor"], local_seeds) \
                    if "keyColor" in source else chroma_key(original_cell)
                measurement_cell = cell
            projectile_report = {"enabled": False, "removedPixels": 0, "components": []}
            if source.get("removeDetachedProjectiles", False) and group in ("base", "extra") and 4 <= index <= 7:
                cell, projectile_report = remove_detached_projectiles(cell, nominal_size)
                projectile_report["cropOriginInCell"] = crop_origin
                measurement_cell = cell.crop((-crop_origin[0], measurement_origin[1] - crop_origin[1],
                    nominal_size[0] - crop_origin[0],
                    measurement_origin[1] - crop_origin[1] + measurement_cell.height))
            try:
                root, measurement = measure(measurement_cell)
                root[1] += measurement_origin[1]
                for field in ("rootMeasured", "rootSuggested"):
                    measurement[field][1] += measurement_origin[1]
                for field in ("bodyCorridor", "bbox"):
                    measurement[field][1] += measurement_origin[1]
                    measurement[field][3] += measurement_origin[1]
                measurement["pelvisSuggestion"]["searchBand"][1] += measurement_origin[1]
                measurement["pelvisSuggestion"]["searchBand"][3] += measurement_origin[1]
            except ValueError:
                if manual_roots is None:
                    raise
                bounds = cell.getbbox()
                if bounds is None:
                    raise ValueError("Empty pose cannot be rescued by manual roots: %s/%s" % (key, index))
                root = list(map(float, manual_roots[index]))
                measurement = {"rootMeasured": None, "rootSuggested": root.copy(),
                    "measurementStatus": "MANUAL_ROOT_NO_CENTRAL_ESTIMATE", "bodyHeightEstimate": bounds[3] - bounds[1],
                    "bodyCorridor": None, "bbox": [bounds[i] + crop_origin[i % 2] for i in range(4)],
                    "sourceTouchesEdge": bounds[0] == 0 or bounds[1] == 0 or bounds[2] == cell.width or bounds[3] == cell.height}
            if global_cells is not None:
                ys, xs = np.where(np.array(cell)[:, :, 3] > 32)
                if not len(xs):
                    raise ValueError("Empty pose after global assignment and projectile removal: %s/%s" % (key, index))
                bounds = [int(xs.min()) + crop_rect[0], int(ys.min()) + crop_rect[1],
                    int(xs.max()) + crop_rect[0] + 1, int(ys.max()) + crop_rect[1] + 1]
                measurement["sourceTouchesEdge"] = bounds[0] == 0 or bounds[1] == 0 or \
                    bounds[2] == sheet.width or bounds[3] == sheet.height
                measurement["crossesNominalCell"] = bounds[0] < rect[0] or bounds[1] < rect[1] or \
                    bounds[2] > rect[2] or bounds[3] > rect[3]
                measurement["sourcePreservedCoreBbox"] = bounds
                measurement["assignedComponentIds"] = assignment["assignedComponentIds"]
            cells.append(cell)
            entries.append({"index": index, "cellRect": rect, "cellSize": nominal_size,
                "cropOrigin": crop_origin, "cropRect": crop_rect, "cropSize": cell.size,
                "autoRoot": root, "key": key_report, "projectileRemoval": projectile_report, **measurement})
        for stem, indices in GROUPS[group]["clips"].items():
            planted = [0, 1, 3] if stem == "dash" else indices
            common_y = float(np.median([(entries[i]["rootMeasured"] or entries[i]["autoRoot"])[1] for i in planted]))
            for index in indices:
                entries[index]["autoRoot"][1] = common_y
                entries[index]["rootSuggested"][1] = common_y
                entries[index]["floorSourceIndices"] = planted
        estimate = float(np.percentile([entry["bodyHeightEstimate"] for entry in entries], 90))
        scale = float(source.get("scale", float(config.get("targetBodyHeight", 270)) / estimate))
        if not math.isfinite(scale) or scale <= 0 or scale > 4:
            raise ValueError("Scale must be finite and within (0,4]: " + key)
        packed = []
        for index, (cell, entry) in enumerate(zip(cells, entries)):
            root = list(map(float, manual_roots[index] if manual_roots is not None else entry["autoRoot"]))
            global_root = [root[0] + entry["cellRect"][0], root[1] + entry["cellRect"][1]]
            root_in_bounds = (0 <= global_root[0] <= sheet.width and 0 <= global_root[1] <= sheet.height) \
                if global_cells is not None else (0 <= root[0] <= entry["cellSize"][0] and 0 <= root[1] <= entry["cellSize"][1])
            if not all(math.isfinite(v) for v in root) or not root_in_bounds:
                raise ValueError("Root outside source cell: %s/%s" % (key, index))
            frame, placement = pack(cell, scale, root, entry["cropOrigin"])
            entry.update(placement)
            entry["rootMode"] = "manual" if manual_roots is not None else "PROVISIONAL_AUTO"
            if placement["clipped"] or placement["alphaLoss"]:
                failures.append("Clipped %s/%s: lower sheet scale or fix roots" % (key, index))
            if entry["sourceTouchesEdge"]:
                failures.append("Source touches %s edge: %s/%s" % ("sheet" if global_cells is not None else "cell", key, index))
            packed.append(frame)
        all_frames[key] = packed
        labels = ["%s / %02d" % (key, index) for index in range(len(cells))]
        contact(cells, labels).save(out / "contacts" / (key + "_source.png"))
        contact(packed, labels, anchor=True).save(out / "contacts" / (key + "_packed.png"))
        reports.append({"key": key, "url": source["url"], "rawPath": str(raw_path.relative_to(out)),
            "sha256": hashlib.sha256(raw).hexdigest(), "size": list(sheet.size),
            "keyType": entries[0]["key"]["keyType"], "keyColor": entries[0]["key"]["keyColor"],
            "backgroundSeeds": seed_audit, "seedCoordinateSpace": "global-source-pixels",
            "globalSegmentation": global_report,
            "cellSize": entries[0]["cellSize"] if len({e["cellSize"] for e in entries}) == 1 else None,
            "gridBounds": {"x": xb, "y": yb}, "scale": scale,
            "scaleMode": "manual" if "scale" in source else "PROVISIONAL_AUTO",
            "roots": [entry["root"] for entry in entries], "frames": entries})
        print(json.dumps({"source": key, "size": sheet.size, "scale": scale,
            "roots": [entry["root"] for entry in entries], "failures": len(failures)}), flush=True)
    if not inspect_only and seen != expected:
        failures.append("Missing sheets: " + ", ".join(sorted(expected - seen)))
    manifest = {"schemaVersion": 1, "character": "achilles", "visualVariant": "painted_g",
        "canvas": list(CANVAS), "footAnchor": list(ANCHOR), "suggestedDisplayScale": .35,
        "directionMapping": {"N": "grid up / screen upper right", "E": "grid right / screen lower right",
            "S": "grid down / screen lower left", "W": "grid left / screen upper left"},
        "processing": "Chroma key/despill, per-sheet scale, translation. No mirrors/redrawing.",
        "artisticValidationPerformed": False, "calibrationProvisional": any(
            report["scaleMode"] != "manual" or any(f["rootMode"] != "manual" for f in report["frames"]) for report in reports),
        "sources": reports, "errors": failures, "clips": [], "runtimeReady": False}
    write_json(out / "manifest.json", manifest)
    if inspect_only:
        return manifest
    if failures:
        raise ValueError("Packing rejected; inspect manifest.json: " + "; ".join(failures[:8]))
    clips = []
    for direction in DIRECTIONS:
        idle = all_frames["locomotion_" + direction][0]
        for group, spec in GROUPS.items():
            for stem, indices in spec["clips"].items():
                name = stem + "_" + direction
                frames = [all_frames[group + "_" + direction][index] for index in indices]
                provenance = [{"source": group + "_" + direction, "index": index} for index in indices]
                if stem in BOOKENDS:
                    frames = [idle] + frames + [idle]
                    rest = {"source": "locomotion_" + direction, "index": 0}
                    provenance = [rest] + provenance + [rest]
                clip_dir = out / "frames" / name
                clip_dir.mkdir(parents=True, exist_ok=True)
                atlas = Image.new("RGBA", (CANVAS[0] * 4, CANVAS[1] * math.ceil(len(frames) / 4)))
                for index, frame in enumerate(frames):
                    frame.save(clip_dir / ("%02d.png" % index))
                    atlas.alpha_composite(frame, (index % 4 * CANVAS[0], index // 4 * CANVAS[1]))
                atlas.save(out / "atlases" / (name + ".png"))
                contact(frames, [name + " / " + str(i) for i in range(len(frames))], anchor=True).save(out / "contacts" / (name + ".png"))
                delays = save_gif(out / "previews" / (name + ".gif"), frames, stem)
                clips.append({"name": name, "stem": stem, "frames": frames})
                manifest["clips"].append({"name": name, "count": len(frames), "frames": provenance,
                    "atlas": "atlases/" + name + ".png", "loop": stem in {"idle", "walk"},
                    "durationSeconds": DURATIONS[stem], "releaseSeconds": RELEASES.get(stem),
                    "releaseFrame": (2 if stem == "dash" else 3) if stem in RELEASES else None,
                    "previewDurationsMs": delays,
                    "runtimeSampling": "idle holds frame zero" if stem == "idle" else
                        "distance-driven half cycle per cell" if stem == "walk" else
                        "hold frame 2 until Battle arrival; frame 3 is 0.08s reception" if stem == "dash" else "marker-aligned shared backend clock"})
    (out / "achilles_sprite_frames.tres").write_text(sprite_frames_resource(clips), encoding="utf-8")
    manifest["runtimeReady"] = True
    write_json(out / "manifest.json", manifest)
    return manifest


if __name__ == "__main__":
    configuration = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
    result = run(configuration, "--inspect" in sys.argv[2:])
    print(json.dumps({"output": configuration["outDir"], "runtimeReady": result["runtimeReady"],
        "clips": len(result["clips"]), "errors": result["errors"]}), flush=True)
