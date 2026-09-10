"""Initial manual pixel calibration of the immutable 1672 x 941 forge painting.

This records the measured bootstrap, not a geometry detector. Later edits belong
in the Studio; rerunning refuses to overwrite its manifest unless --replace is
explicitly passed. The master image is never modified.
"""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[4]
FOLDER = Path(__file__).resolve().parent
SIZE = (1672, 941)


def point(x, y):
    return [round(x / SIZE[0], 6), round(y / SIZE[1], 6)]


def polygon(*points):
    return [point(*p) for p in points]


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


manifest_path = ROOT / "data/halts/bronze_forge_v1.json"
if manifest_path.exists() and "--replace" not in sys.argv:
    raise SystemExit("Manifest already exists; edit in Studio or explicitly use --replace.")
image = ROOT / "asset/map/painted/halts/bronze_forge_v1/forge.png"
source_hash = hashlib.sha256(image.read_bytes()).hexdigest()
manifest = {
    "schema_version": 1,
    "id": "bronze_forge_v1",
    "title": "La Forge des Racines",
    "subtitle": "BRONZE PATINÉ · PIERRE SÈCHE · BRAISES VIVANTES",
    "kind": "forge",
    "stage": "playable_study",
    "style": "res://data/halts/styles/roots_bronze_v1.json",
    "source": {
        "image": "res://asset/map/painted/halts/bronze_forge_v1/forge.png",
        "size": list(SIZE),
        "sha256": source_hash,
        "provider": "image_gen",
        "generated_on": "2026-09-10",
        "prompt": "res://art/source/halts/bronze_forge_v1/generation_prompt.txt",
        "reference": "res://asset/map/painted/merchant/hall_v1/hall.png",
        "references": ["res://asset/map/painted/merchant/hall_v1/hall.png", "res://art/source/halts/bronze_forge_v1/spatial_plan.png"],
        "spatial_plan": "res://art/source/halts/bronze_forge_v1/spatial_plan.json",
        "provenance": "res://art/source/halts/bronze_forge_v1/provenance.json",
    },
    "build_dir": "res://asset/map/painted/halts/bronze_forge_v1",
    "world": {"width": 2200, "player_scale": 0.52, "speed": 195, "foot_clearance": 12, "spawn": point(310, 759)},
    "navigation": {
        "outline": polygon((10, 927), (10, 875), (154, 764), (166, 713), (261, 667), (352, 622),
                           (277, 581), (228, 552), (232, 518), (286, 479), (351, 467), (444, 413),
                           (559, 378), (657, 355), (803, 326), (866, 325), (958, 360), (1086, 402),
                           (1192, 417), (1265, 409), (1352, 351), (1420, 301), (1490, 266),
                           (1540, 273), (1590, 299), (1582, 350), (1570, 393), (1524, 442),
                           (1480, 478), (1437, 521), (1401, 537), (1433, 568), (1447, 604),
                           (1405, 648), (1354, 685), (1269, 728), (1209, 773), (1146, 815),
                           (994, 841), (831, 843), (690, 821), (647, 799), (645, 757), (626, 718),
                           (611, 689), (567, 676), (516, 697), (455, 729), (444, 790), (437, 824),
                           (358, 866), (248, 932)),
        "obstacles": [polygon((658, 480), (706, 458), (940, 451), (1016, 480), (1071, 529),
                              (1056, 573), (1005, 607), (908, 633), (825, 638), (716, 613),
                              (651, 580), (627, 534), (630, 509))],
    },
    "landmarks": [
        {"id": "forge", "title": "Foyer de bronze", "action": "merchant", "point": point(551, 427),
         "focus": point(469, 282), "radius": 0.075,
         "description": "Le foyer accueille les préparatifs et les échanges avant la prochaine descente."},
        {"id": "lore", "title": "Mémoire des forgerons", "action": "dialogue", "point": point(1120, 445),
         "focus": point(1080, 280), "radius": 0.065,
         "description": "Les outils portent l'empreinte de ceux qui ont préparé les premières descentes. Ici, chaque lame réparée a repris le chemin des profondeurs."},
        {"id": "exit", "title": "Arche des braises", "action": "exit", "point": point(1460, 339),
         "focus": point(1489, 270), "radius": 0.085,
         "description": "Reprendre le chemin de Catabase."},
    ],
    "water": {"tint": "#48d896", "polygons": [], "exclusions": []},
    "cascades": [],
    "torches": [],
    "foliage": [],
    "bounce": [],
    "mist": [{"rect": [0.204, 0.098, 0.193, 0.204], "color": "#a88960", "alpha": 0.035}],
    "foreground": [
        {"id": "anvil_island", "anchor": point(850, 611),
         "polygon": polygon((623, 536), (628, 505), (658, 477), (692, 462), (697, 436), (712, 434),
                            (711, 416), (712, 394), (721, 389), (731, 396), (734, 416), (729, 433),
                            (735, 444), (748, 441), (750, 410), (757, 396), (766, 402), (764, 416),
                            (757, 445), (782, 444), (791, 432), (777, 413), (773, 392), (800, 389),
                            (812, 384), (865, 390), (923, 412), (944, 427), (931, 441), (912, 445),
                            (917, 463), (933, 465), (948, 443), (958, 429), (978, 431), (984, 443),
                            (976, 456), (1003, 462), (1007, 478), (1035, 490), (1061, 510),
                            (1073, 539), (1064, 570), (1024, 599), (984, 614), (904, 635),
                            (822, 638), (711, 611), (651, 579))},
        {"id": "entry_pillar", "anchor": point(548, 897),
         "polygon": polygon((465, 744), (469, 718), (506, 699), (550, 686), (582, 694), (616, 711),
                            (623, 748), (628, 777), (625, 822), (630, 870), (612, 903), (567, 919),
                            (515, 900), (479, 878), (470, 837), (464, 785))},
        {"id": "right_pillar", "anchor": point(1536, 858),
         "polygon": polygon((1490, 646), (1495, 620), (1531, 603), (1570, 606), (1604, 621),
                            (1613, 644), (1603, 665), (1603, 715), (1590, 746), (1589, 790),
                            (1568, 832), (1538, 856), (1487, 842), (1482, 795), (1484, 736), (1487, 681))},
    ],
    "ambience": {"footsteps": "stone", "sources": [
        {"id": "forge_hearth", "kind": "fire", "point": point(469, 282), "radius": 0.40, "gain_db": -16},
        {"id": "coal_basket", "kind": "fire", "point": point(247, 380), "radius": 0.16, "gain_db": -24},
    ]},
    "review": {
        "forbidden_points": polygon((853, 560), (933, 530), (482, 300), (1090, 285), (105, 560), (545, 766)),
        "stable_pixel": point(788, 780),
        "fire_pixel": point(469, 282),
        "loop_waypoints": polygon((412, 539), (574, 424), (835, 384), (1173, 483), (1168, 663), (867, 756), (459, 652)),
        "dry": True,
    },
}
for index, (name, x, y, rx, ry, smoke) in enumerate([
    ("hearth", 469, 277, 56, 43, 0.25),
    ("coal_basket", 247, 380, 25, 12, 0.15),
    ("lantern_left", 310, 231, 8, 18, 0),
    ("lantern_forge", 708, 181, 8, 19, 0),
    ("lantern_lore_left", 960, 191, 8, 18, 0),
    ("lantern_lore_right", 1171, 234, 8, 18, 0),
    ("lantern_exit_left", 1397, 190, 8, 18, 0),
    ("lantern_exit_right", 1628, 220, 8, 18, 0),
    ("lantern_entry", 126, 671, 10, 21, 0),
]):
    manifest["torches"].append({"id": name, "point": point(x, y), "radius": point(rx, ry),
                                "phase": round(index * 1.731, 3), "smoke_strength": smoke,
                                "flame_strength": 0.8 if name.startswith("lantern") else 1.0,
                                "light_strength": 0.55 if name.startswith("lantern") else 1.0})
save(manifest_path, manifest)
prompt = (FOLDER / "generation_prompt.txt").read_text(encoding="utf-8")
save(FOLDER / "request.json", {
    "id": "bronze_forge_v1", "kind": "forge", "stage": "generated", "style": "roots_bronze_v1",
    "references": manifest["source"]["references"], "spatial_plan": manifest["source"]["spatial_plan"],
    "plan_reference": "res://art/source/halts/bronze_forge_v1/spatial_plan.png",
    "brief": "Une forge sèche, une boucle de circulation large, un établi à gauche, un point de lore à droite et une sortie supérieure droite.",
    "prompt": prompt,
})
save(FOLDER / "provenance.json", {
    "schema_version": 1, "provider": "image_gen", "mode": "native_builtin", "generated_on": "2026-09-10",
    "source_image": manifest["source"]["image"], "source_size": list(SIZE), "source_sha256": source_hash,
    "provider_output": "C:/Users/paolo/.codex/generated_images/01a08afe-68e6-7c81-8280-a79c52afae79/exec-5cae8edc-792d-40b6-a930-152a7135fff8.png",
    "master_reference": manifest["source"]["reference"],
    "master_sha256": hashlib.sha256((ROOT / "asset/map/painted/merchant/hall_v1/hall.png").read_bytes()).hexdigest(),
    "spatial_plan": manifest["source"]["spatial_plan"],
    "plan_created_before_generation": True,
    "reference_delivery": "Native tool used the two inspected in-memory JPEG reference previews after direct filesystem reference loading failed with a sandbox ACL helper error.",
    "prompt": manifest["source"]["prompt"],
    "original_preserved_byte_for_byte": True,
    "calibration": "Manually measured on this exact original, recorded in calibrate.py. No sanctuary geometry reused.",
    "generation_count": 1,
})
print(manifest_path)
