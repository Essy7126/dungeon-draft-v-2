"""Inspect/key four fixed Meshy views; never synthesize or deform animation."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import math
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "output/monster-meshy-deps"))
import numpy as np
from PIL import Image, ImageDraw, ImageOps
from scipy.ndimage import label

SLUGS = ("sentinelle_airain", "rejeton_braise", "molosse_styx", "lamie_lethe")
VIEW_CELLS = {"E": [0, 0], "S": [1, 0], "N": [0, 1], "W": [1, 1]}
TARGET_HEIGHTS = {"sentinelle_airain": 280, "rejeton_braise": 230,
                  "molosse_styx": 185, "lamie_lethe": 280}
REGISTRY = ROOT / "meshy_output/20260908_monster_views_v1/tasks.json"
OVERRIDES = ROOT / "meshy_output/20260908_monster_views_v1/overrides.json"
CANVAS, ANCHOR = (512, 384), (256, 320)
KNOWN_EQUIPMENT_REVIEW = {
    "2ee9d1f259e78d955fc00e5aed2a1fa4950ffa809df5a1b98109020dee8a8c40": {
        "S": "Shield/spear anatomical hands swapped; E/N pilot only until corrected source review."},
    "e457b5dfe11fdfadaed216f0fe4be1ffaeb79eb20ccb9c4537236308593b07f4": {
        "S": "Staff laterality differs from approved anatomical left hand; needs corrected fixed view.",
        "W": "Staff laterality differs from approved anatomical left hand; needs corrected fixed view."},
}
_spec = importlib.util.spec_from_file_location(
    "_tested_painted_key", ROOT / "tools/achilles_painted_g_pipeline/build.py")
_key_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_key_module)


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _measure(image: Image.Image) -> dict:
    mask = np.asarray(image)[:, :, 3] > 32
    ys, xs = np.where(mask)
    if len(xs) < 32:
        raise ValueError("Missing or nearly empty fixed view")
    x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    labels, count = label(mask, structure=np.ones((3, 3), dtype=np.uint8))
    areas = np.bincount(labels.ravel())[1:]
    foot_band = ys >= y1 - max(1, round((y1 - y0) * .15))
    root = [float(np.median(xs[foot_band])), float(y1 - 1)]
    margins = [x0, y0, image.width - x1, image.height - y1]
    return {"bbox": [x0, y0, x1, y1], "margins": margins,
            "height": y1 - y0, "width": x1 - x0, "core_alpha": 32,
            "core_pixels": int(len(xs)), "component_count": int(count),
            "component_areas": sorted([int(v) for v in areas], reverse=True),
            "centroid": [float(xs.mean()), float(ys.mean())],
            "root": root, "root_method": "median_x_of_lowest_15pct_foreground; max_core_y",
            "touches_edge": min(margins) <= 0}


def inspect_slug(slug: str, registry: dict, overrides: dict | None = None) -> tuple[dict, dict]:
    """Return JSON measurements and keyed PIL views without writing files."""
    if overrides is None:
        overrides = json.loads(OVERRIDES.read_text(encoding="utf-8-sig")) if OVERRIDES.exists() else {}
    record = registry.get(slug, {})
    result = {"slug": slug, "status": record.get("status", "missing"),
              "ready": False, "errors": [], "views": {}}
    if record.get("slug") != slug or record.get("status") != "downloaded_pending_review":
        result["errors"].append("Requires this slug's downloaded_pending_review fixed-view task")
        return result, {}
    if record.get("view_cells") != VIEW_CELLS:
        result["errors"].append("Registry must declare the approved E/S/N/W 2x2 layout")
        return result, {}
    source = Path(record.get("source_path", ""))
    if not source.is_file():
        result["errors"].append("Downloaded turnaround source is missing")
        return result, {}
    source_hash = _sha(source.read_bytes())
    if record.get("sha256") != source_hash:
        result["errors"].append("Turnaround source hash does not match registry")
        return result, {}
    master = Path(record.get("reference_path", ""))
    if not master.is_file() or _sha(master.read_bytes()) != record.get("reference_sha256"):
        result["errors"].append("Approved master source/hash does not match registry")
        return result, {}
    image = Image.open(source).convert("RGBA")
    result.update({"task_id": record.get("task_id"), "source_path": str(source),
                   "source_sha256": source_hash, "source_dimensions": list(image.size),
                   "master_path": str(master), "master_sha256": record["reference_sha256"],
                   "equipment_review_flags": dict(KNOWN_EQUIPMENT_REVIEW.get(source_hash, {}))})
    xb, yb = [0, round(image.width / 2), image.width], [0, round(image.height / 2), image.height]
    views = {}
    for direction, (column, row) in VIEW_CELLS.items():
        box = [xb[column], yb[row], xb[column + 1], yb[row + 1]]
        cell = image.crop(box)
        override = overrides.get(slug + "_" + direction)
        override_audit = None
        if override is not None:
            if not isinstance(override, dict) or override.get("status") not in ["downloaded_pending_review", "approved"]:
                result["errors"].append(direction + ": single-view override is not downloaded/approved")
                continue
            override_path = Path(override.get("source_path", ""))
            if not override_path.is_file() or not override.get("task_id") or \
                    _sha(override_path.read_bytes()) != override.get("sha256"):
                result["errors"].append(direction + ": single-view override source/hash/task is invalid")
                continue
            raw_override = Image.open(override_path).convert("RGBA")
            if raw_override.width != raw_override.height or raw_override.width < 32:
                result["errors"].append(direction + ": single-view override must be square")
                continue
            # An authored single view replaces only its named direction. The
            # uniform normalization never mirrors or changes the aspect ratio.
            cell = raw_override.resize((512, 512), Image.Resampling.LANCZOS)
            capture_scale = override.get("capture_scale", 1.0)
            if isinstance(capture_scale, bool) or not isinstance(capture_scale, (int, float)) or \
                    not math.isfinite(capture_scale) or not 0.1 <= capture_scale <= 1.0:
                result["errors"].append(direction + ": capture_scale must be a finite scalar in [0.1,1]")
                continue
            if capture_scale != 1.0:
                side = round(512 * capture_scale)
                reduced = cell.resize((side, side), Image.Resampling.LANCZOS)
                cell = Image.new("RGBA", (512, 512), (255, 0, 255, 255))
                cell.paste(reduced, ((512 - side) // 2, (512 - side) // 2))
            box = [0, 0, 512, 512]
            override_audit = {"task_id": override["task_id"], "source_path": str(override_path),
                "sha256": override["sha256"], "status": override["status"],
                "original_dimensions": list(raw_override.size), "normalized_dimensions": [512, 512],
                "normalization_scale": 512.0 / raw_override.width, "mirrored": False,
                "capture_scale": float(capture_scale),
                "capture_scale_reason": override.get("capture_scale_reason", "")}
            result["equipment_review_flags"].pop(direction, None)
            if override["status"] != "approved":
                result["equipment_review_flags"][direction] = "Single-view replacement awaits anatomical review."
        # Temporary padding permits inspection of a clipped edge; the explicit
        # quadrant guard below still rejects it before any output is written.
        padded = ImageOps.expand(cell, border=2, fill=(255, 0, 255, 255))
        keyed_pad, key_audit = _key_module.chroma_key(padded)
        keyed = keyed_pad.crop((2, 2, 2 + cell.width, 2 + cell.height))
        try:
            measured = _measure(keyed)
        except ValueError as error:
            result["errors"].append(direction + ": " + str(error))
            continue
        rgba, before = np.asarray(keyed), np.asarray(cell)
        key_audit.update({"temporary_padding_pixels": 2,
                          "source_pixels_changed": int(np.any(rgba != before, axis=2).sum()),
                          "source_alpha_changed": int((rgba[:, :, 3] != before[:, :, 3]).sum()),
                          "source_size": list(cell.size)})
        measured.update({"source_cell": box, "source_cell_size": list(cell.size),
                         "source_bbox": measured["bbox"], "key": key_audit,
                         "keyed_rgba_sha256": _sha(keyed.tobytes())})
        if override_audit is not None:
            measured["override"] = override_audit
        result["views"][direction], views[direction] = measured, keyed
        if measured["touches_edge"]:
            result["errors"].append(direction + ": foreground crosses/touches quadrant boundary")
    if len(views) != 4:
        result["errors"].append("Exactly four nonempty fixed views are required")
    if result["errors"]:
        return result, views
    measured_views = list(result["views"].values())
    median_height = float(np.median([m["height"] for m in measured_views]))
    scale = min(TARGET_HEIGHTS[slug] / median_height,
                400.0 / max(m["width"] for m in measured_views))
    # One scalar for all views, capped only to prevent canvas loss around an
    # asymmetric staff/tail and the measured ground root.
    for measured in measured_views:
        x0, y0, x1, y1 = measured["bbox"]
        rx, ry = measured["root"]
        for extent, available in [(rx - x0, 252), (x1 - rx, 252),
                                  (ry - y0, 316), (y1 - ry, 60)]:
            if extent > 0:
                scale = min(scale, available / extent)
    result.update({"common_scale": scale, "median_source_height": median_height,
                   "target_height": TARGET_HEIGHTS[slug], "canvas": list(CANVAS),
                   "anchor": list(ANCHOR), "review_required": True})
    for direction, view in views.items():
        measured = result["views"][direction]
        packed, placement = _key_module.pack(view, scale, measured["root"])
        if placement["clipped"] or placement["alphaLoss"] != 0:
            result["errors"].append(direction + ": pack would crop foreground or lose alpha")
        packed_measure = _measure(packed)
        measured.update({"placement": placement, "packed_bbox": packed_measure["bbox"],
                         "packed_centroid": packed_measure["centroid"],
                         "root_raster_error": [placement["offset"][axis] +
                             measured["root"][axis] * scale - ANCHOR[axis] for axis in range(2)]})
    result["ready"] = not result["errors"]
    return result, views


def prepare_slug(inspection: dict, views: dict, project_root: Path | str = ROOT) -> dict:
    """Persist fixed-view candidates/alignment proposals, no rig or animation."""
    if not inspection.get("ready"):
        raise ValueError("Cannot prepare failed/unavailable source: " + inspection["slug"])
    slug = inspection["slug"]
    directory = Path(project_root) / "art/source/characters/catabase_monsters" / slug
    directory.mkdir(parents=True, exist_ok=True)
    turnaround, master = directory / "turnaround_source.png", directory / "master.png"
    shutil.copyfile(inspection["source_path"], turnaround)
    shutil.copyfile(inspection["master_path"], master)
    if _sha(turnaround.read_bytes()) != inspection["source_sha256"] or \
            _sha(master.read_bytes()) != inspection["master_sha256"]:
        raise ValueError("Original source byte preservation failed")
    result = dict(inspection)
    result.update({"turnaround_copy": str(turnaround), "master_copy": str(master),
                   "alignment_kind": "measured_ground_root_proposal", "rig_authored": False,
                   "artwork_operations": ["crop", "magenta_key", "unmix_edges", "uniform_scale", "pad"]})
    board = Image.new("RGB", (1024, 816), "#263640")
    draw = ImageDraw.Draw(board)
    for index, direction in enumerate(VIEW_CELLS):
        keyed = views[direction]
        override = result["views"][direction].get("override")
        if override:
            original_copy = directory / f"override_source_{direction}.png"
            shutil.copyfile(override["source_path"], original_copy)
            if _sha(original_copy.read_bytes()) != override["sha256"]:
                raise ValueError("Single-view override original bytes were altered")
            override["original_copy"] = str(original_copy)
        keyed_path, base_path = directory / f"source_{direction}.png", directory / f"base_frame_{direction}.png"
        keyed.save(keyed_path, compress_level=9)
        packed, placement = _key_module.pack(keyed, result["common_scale"], result["views"][direction]["root"])
        if placement["clipped"] or placement["alphaLoss"] != 0:
            raise ValueError("Unexpected clipping during preparation")
        packed.save(base_path, compress_level=9)
        reread = Image.open(base_path).convert("RGBA")
        if reread.tobytes() != packed.tobytes():
            raise ValueError("Base frame PNG altered RGBA pixels")
        result["views"][direction].update({"source_file": str(keyed_path),
            "base_frame_file": str(base_path), "source_png_sha256": _sha(keyed_path.read_bytes()),
            "base_frame_png_sha256": _sha(base_path.read_bytes()), "raster_max_error": 0})
        x, y = index % 2 * 512, index // 2 * 408
        board.paste(packed, (x, y), packed)
        draw.text((x + 12, y + 388), f"{slug} {direction} | proposed root (256,320)", fill="white")
        draw.line((x + 250, y + 320, x + 262, y + 320), fill="#65e4cf")
        draw.line((x + 256, y + 314, x + 256, y + 326), fill="#65e4cf")
    preview = directory / "fixed_views_contact.png"
    board.save(preview)
    result["contact_preview"] = str(preview)
    (directory / "alignment.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--inspect", action="store_true", help="Read-only JSON measurements")
    action.add_argument("--prepare", action="store_true", help="Write fixed-view alignment candidates")
    parser.add_argument("--registry", type=Path, default=REGISTRY)
    parser.add_argument("--overrides", type=Path, default=OVERRIDES)
    parser.add_argument("--slug", choices=SLUGS)
    args = parser.parse_args()
    registry = json.loads(args.registry.read_text(encoding="utf-8-sig"))
    overrides = json.loads(args.overrides.read_text(encoding="utf-8-sig")) if args.overrides.exists() else {}
    inspections = [inspect_slug(slug, registry, overrides) for slug in ([args.slug] if args.slug else SLUGS)]
    if args.prepare:
        failures = [report for report, _ in inspections if not report["ready"]]
        if failures:
            print(json.dumps({"prepared": False, "failures": failures}, ensure_ascii=False, indent=2))
            raise SystemExit(1)
        output = [prepare_slug(report, views) for report, views in inspections]
    else:
        output = [report for report, _ in inspections]
    print(json.dumps({"prepared": bool(args.prepare), "monsters": output}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
