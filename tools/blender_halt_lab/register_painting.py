"""Register the immutable painting to the metric blockout, then prepare a study.

The floor affine transform is a starting calibration, not a claim that image
generation retained exact geometry. Painted silhouettes are reviewed separately.
"""
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/source/halts/bronze_workshop_pilot_v1"
ASSET = ROOT / "asset/map/painted/halts/bronze_workshop_pilot_v1"
MANIFEST = ROOT / "data/halts/bronze_workshop_pilot_v1.json"


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh-calibration", action="store_true", help="Explicitly replace calibration; Studio edits are preserved by default")
    args = parser.parse_args()
    p = json.loads((OUT / "projection.json").read_text(encoding="utf-8"))
    features = json.loads((OUT / "registration_features.json").read_text())
    image_path = OUT / "painting_original.png"
    size = Image.open(image_path).size
    assert size == (1672, 941), "A new painting needs new visual measurements"
    # Top surface corners, measured on this specific delivered original.
    control = {"floor_fl": [273, 589], "floor_fr": [1025, 899], "floor_br": [1375, 550]}
    a = np.array([features[k] + [1] for k in control])
    b = np.array([np.array(v) / size for v in control.values()])
    affine = np.linalg.solve(a, b)

    def remap(point):
        return [round(float(x), 6) for x in np.array(list(point) + [1]) @ affine]

    def uv(x, y):
        return [round(x / size[0], 6), round(y / size[1], 6)]

    def center(polygon):
        return np.array(polygon).mean(axis=0).tolist()

    landmarks = [
        {"id": "workbench", "title": "L’établi du bronzier", "action": "merchant",
         "point": remap(p["points"]["bench_approach"]), "focus": uv(849, 373), "radius": .045,
         "description": "Préparer son équipement à un établi à hauteur de taille."},
        {"id": "craft_memory", "title": "Le petit seau", "action": "dialogue",
         "point": remap(p["points"]["bucket_approach"]), "focus": uv(695, 453), "radius": .035,
         "description": "Le seau de trempe, les outils et l’établi ont été dimensionnés ensemble, à partir du corps d’Achille. Le bronze conserve les marques des réparations précédentes."},
        {"id": "exit", "title": "La porte de l’atelier", "action": "exit",
         "point": remap(p["points"]["door_approach"]), "focus": uv(1200, 388), "radius": .05,
         "description": "Quitter la visite de l’atelier."},
    ]
    source_uri = "res://asset/map/painted/halts/bronze_workshop_pilot_v1/workshop.png"
    digest = hashlib.sha256(image_path.read_bytes()).hexdigest()
    ASSET.mkdir(parents=True, exist_ok=True)
    target = ASSET / "workshop.png"
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != digest:
        raise RuntimeError("Do not replace an existing painting: create a new version")
    if not target.exists():
        shutil.copyfile(image_path, target)
    # Explicit painted silhouette. This is later refined from the layer selection
    # when available; the generated image is never used as its own collision map.
    pillar = [[896,405],[964,429],[963,451],[951,466],[951,486],[944,498],
              [943,631],[973,645],[970,666],[938,698],[846,675],[846,649],
              [867,631],[866,505],[864,494],[865,473],[854,463],[854,444]]
    selections = OUT / "layer_selections.json"
    pillar_anchor = [907, 677]
    if selections.exists():
        selection = json.loads(selections.read_text(encoding="utf-8"))
        assert selection["image_size"] == list(size), "Layer selection size mismatch"
        painted_pillar = next(prop for prop in selection["props"] if prop["id"] == "pillar")
        assert len(painted_pillar["silhouette_polygons"]) == 1, "Runtime pillar requires one continuous polygon"
        pillar = painted_pillar["silhouette_polygons"][0]
        pillar_anchor = painted_pillar["anchor_image_px"]
    manifest = {
        "schema_version": 1, "id": "bronze_workshop_pilot_v1", "title": "L’Atelier du Bronze",
        "subtitle": "PIERRE · BRONZE · ATELIER À TAILLE HUMAINE", "kind": "forge", "stage": "playable_study",
        "style": "res://data/halts/styles/roots_bronze_v1.json",
        "source": {"image": source_uri, "size": list(size), "sha256": digest,
                   "provider": "image_gen", "generated_on": "2026-09-10",
                   "prompt": "res://art/source/halts/bronze_workshop_pilot_v1/generation_prompt.txt",
                   "reference": "res://asset/map/painted/merchant/hall_v1/hall.png",
                   "references": ["res://art/source/halts/bronze_workshop_pilot_v1/blockout.png",
                                  "res://art/source/halts/bronze_workshop_pilot_v1/scale_guide.png",
                                  "res://asset/map/painted/merchant/hall_v1/hall.png"]},
        "build_dir": "res://asset/map/painted/halts/bronze_workshop_pilot_v1",
        "world": {"width": 2200, "speed": 195, "foot_clearance": 20,
                  "spawn": remap(p["points"]["spawn"]), "player_height_ratio": .212},
        "navigation": {"outline": [remap(v) for v in p["ground_outline"]],
                       "obstacles": [[remap(v) for v in poly] for poly in p["obstacles"].values()]},
        "landmarks": landmarks,
        "water": {"tint": "#48d896", "polygons": [], "exclusions": []},
        "cascades": [], "foliage": [], "bounce": [], "mist": [],
        "torches": [{"id": "hearth", "point": uv(647, 270), "radius": [.025, .048],
                     "phase": .4, "smoke_strength": .15, "flame_strength": 1.0, "light_strength": .75}],
        "foreground": [{"id": "pillar", "anchor": uv(*pillar_anchor), "polygon": [uv(*v) for v in pillar]}],
        "ambience": {"footsteps": "stone", "sources": [
            {"id": "hearth", "kind": "fire", "point": uv(647, 270), "radius": .35, "gain_db": -18}]},
        "review": {"dry": True, "stable_pixel": uv(595, 684), "fire_pixel": uv(647, 270),
                   "forbidden_points": [remap(center(poly)) for poly in p["obstacles"].values()] + [uv(201, 320)],
                   "loop_waypoints": [remap(p["points"][name]) for name in
                                      ["bucket_approach", "bench_approach", "pillar_behind", "pillar_right", "pillar_front", "pillar_left"]]},
    }
    if MANIFEST.exists() and not args.refresh_calibration:
        existing = json.loads(MANIFEST.read_text(encoding="utf-8"))
        if existing != manifest:
            raise RuntimeError("Calibration already exists. Preserve Studio edits or explicitly pass --refresh-calibration.")
    write(MANIFEST, manifest)
    write(OUT / "spatial_plan.json", manifest)
    write(OUT / "registration.json", {
        "painting_size": size, "painting_sha256": digest, "floor_controls_pixels": control,
        "floor_affine_from_blockout_normalized": affine.tolist(),
        "body_reference_px": 202, "body_reference_uncertainty_px": 2, "full_reference_px": 257,
        "blockout_ratio": p["achilles_reference"]["player_height_ratio"],
        "painted_ratio": .212, "painted_body_height_pixels": .212 * size[1] * 202 / 257,
        "status": "navigation and visual proportions require runtime review",
        "note": "The generated composition changed. Coordinates were registered against the delivered image; metric geometry remains an authoring reference, not certified final dimensions."
    })
    sys.path.insert(0, str(ROOT / "tools/halt_workshop"))
    import halt_workshop
    report = halt_workshop.prepare(MANIFEST, ROOT)
    print(json.dumps({"manifest": str(MANIFEST), "prepared": report}, ensure_ascii=False))


if __name__ == "__main__":
    main()
