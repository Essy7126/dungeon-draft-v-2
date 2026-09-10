"""Author technical polygons/masks for the reviewed stylized threshold painting.

Original imagegen pixels are copied unchanged. This script draws only technical
selections and density data; it does not paint, retouch or generate artwork.
"""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/source/halts/underworld_threshold_v1"
BUILD = ROOT / "asset/map/painted/halts/underworld_threshold_v1"
W, H = 1672, 941


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def norm(point):
    return [round(point[0] / W, 7), round(point[1] / H, 7)]


def polygon(points):
    return [norm(p) for p in points]


def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    painting = SOURCE / "painting_stylized_original.png"
    with Image.open(painting) as image:
        assert image.size == (W, H)
    original = painting.read_bytes()
    digest = hashlib.sha256(original).hexdigest()
    target = BUILD / "threshold.png"
    if target.exists() and target.read_bytes() != original:
        raise ValueError("Runtime painting already differs: version the source")
    target.write_bytes(original)
    # Hand-traced on the final native 1672x941 painting, not rescaled blockout IDs.
    left = [[568,99],[582,104],[591,120],[588,136],[601,144],[609,156],
            [607,190],[599,217],[609,297],[636,300],[643,308],[640,342],
            [603,374],[587,390],[540,376],[499,357],[496,321],[507,309],
            [528,294],[533,227],[533,201],[522,214],[515,211],[505,197],
            [501,178],[499,161],[499,150],[505,146],[513,150],[513,174],
            [523,181],[532,162],[537,149],[548,141],[547,122],[554,107]]
    staff = [[507,83],[512,94],[511,106],[511,143],[510,150],[510,310],
             [503,315],[503,168],[501,163],[503,142],[503,106],[503,95]]
    rear = [[880,134],[892,139],[902,151],[902,164],[895,178],[914,186],
            [922,196],[922,218],[916,252],[916,316],[924,333],[948,341],
            [951,350],[948,374],[898,403],[814,373],[814,345],[833,327],
            [839,281],[841,247],[830,239],[832,226],[838,214],[844,195],
            [856,183],[868,177],[865,162],[868,146]]
    front = [[1024,407],[1039,411],[1052,426],[1056,442],[1051,457],
             [1047,466],[1065,477],[1075,487],[1076,510],[1068,548],
             [1070,602],[1079,620],[1104,615],[1112,624],[1114,655],
             [1097,682],[1040,716],[1026,719],[954,681],[949,642],
             [962,628],[979,612],[984,558],[978,549],[975,531],[981,520],
             [976,508],[980,476],[991,460],[1009,453],[1004,435],[1010,419]]
    props = [
        {"id":"statue_right", "name":"Gardienne du serment", "anchor_image_px":[1034,706],
         "silhouette_polygons":[front], "floor_patch_polygons":[[[918,631],[1002,598],[1130,612],[1147,680],[1050,752],[925,698]]]},
        {"id":"statue_left", "name":"Gardien des noms", "anchor_image_px":[582,378],
         "silhouette_polygons":[left,staff], "floor_patch_polygons":[[[483,304],[543,287],[651,307],[667,367],[586,418],[486,376]]]},
        {"id":"statue_rear", "name":"Gardienne des ombres", "anchor_image_px":[891,390],
         "silhouette_polygons":[rear], "floor_patch_polygons":[[[801,337],[853,318],[960,335],[972,396],[887,433],[801,391]]]},
    ]
    write(SOURCE / "layer_selections.json", {
        "title":"Le Seuil des Ombres — peinture décomposée", "painting":painting.name,
        "clean_plate":"clean_plate_stylized_original.png", "image_size":[W,H],
        "output":"underworld_threshold_layers.ora", "props":props,
        "limitations":["Contours manuels de la peinture finale, sans reconstruction des faces cachées.",
                        "Les ombres sont conservées dans des raccords RGB opaques ; déplacement à retoucher.",
                        "La génération a déplacé proportions et silhouettes : guides Blender préalables, non recalés automatiquement."]})
    points = {"spawn":[445,554], "statue_memory":[617,429], "fallen_oath":[905,701],
              "threshold_gate":[1157,508], "central":[724,558],
              "statue_right_behind":[1024,595], "statue_right_front":[1045,761],
              "statue_left_behind":[564,283], "right_side":[1175,633]}
    outline = [[286,493],[511,264],[637,263],[1280,489],[1310,549],
               [1143,726],[1100,801],[932,790],[375,581]]
    obstacles = [
        [[497,351],[582,399],[651,344],[573,305]],
        [[806,376],[892,417],[958,365],[873,334]],
        [[949,679],[1034,729],[1123,664],[1045,623]],
        [[975,416],[1023,440],[1060,407],[1011,384]],
        [[1251,518],[1301,543],[1339,504],[1284,481]],
        [[1028,407],[1256,511],[1300,468],[1067,365]],
    ]
    manifest = {
        "schema_version":1, "id":"underworld_threshold_v1", "title":"Le Seuil des Ombres",
        "subtitle":"BRUME · PIERRE ANCIENNE · MÉMOIRE", "kind":"lore", "stage":"playable_study",
        "style":"res://data/halts/styles/roots_bronze_v1.json",
        "source":{"image":"res://asset/map/painted/halts/underworld_threshold_v1/threshold.png",
            "size":[W,H], "sha256":digest, "provider":"image_gen", "generated_on":"2026-09-10",
            "prompt":"res://art/source/halts/underworld_threshold_v1/generation_stylized_prompt.txt",
            "reference":"res://asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png",
            "references":["res://art/source/halts/underworld_threshold_v1/blockout.png",
                "res://art/source/halts/underworld_threshold_v1/scale_guide.png",
                "res://asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png"]},
        "build_dir":"res://asset/map/painted/halts/underworld_threshold_v1",
        "world":{"width":2200, "speed":195, "foot_clearance":20,
                 "spawn":norm(points["spawn"]), "player_height_ratio":0.186},
        "navigation":{"outline":polygon(outline), "obstacles":[polygon(p) for p in obstacles]},
        "landmarks":[
            {"id":"statue_memory", "title":"Le gardien des noms", "action":"dialogue",
             "point":norm(points["statue_memory"]), "focus":norm([562,250]), "radius":0.044,
             "description":"Les vivants gravaient leurs noms pour résister à l’oubli. Ici, la pierre les retient encore. Achille pose la main sur le bronze froid. Le sien n’a pas disparu."},
            {"id":"fallen_oath", "title":"La gardienne du serment", "action":"dialogue",
             "point":norm(points["fallen_oath"]), "focus":norm([1024,535]), "radius":0.044,
             "description":"Sur la tablette, quelques mots ont survécu : « Ce que la mort a pris, la volonté peut encore le chercher. » Au-delà de la porte, les ombres attendent."},
            {"id":"threshold_gate", "title":"La porte des Ombres", "action":"exit",
             "point":norm(points["threshold_gate"]), "focus":norm([1195,313]), "radius":0.05,
             "description":"La brume s’écarte entre les battants. Franchir ce seuil, c’est commencer la descente d’Achille vers les Enfers."}],
        "water":{"tint":"#48d896", "polygons":[], "exclusions":[]},
        "cascades":[], "foliage":[], "bounce":[], "mist":[],
        "torches":[{"id":"gate_left", "point":norm([1020,305]), "radius":[0.017,0.048],
                    "phase":0.4,"smoke_strength":0.10,"flame_strength":0.75,"light_strength":0.48},
                   {"id":"gate_right", "point":norm([1301,418]), "radius":[0.017,0.048],
                    "phase":2.1,"smoke_strength":0.08,"flame_strength":0.75,"light_strength":0.48}],
        "foreground":[{"id":prop["id"]+str(i), "anchor":norm(prop["anchor_image_px"]),
                       "polygon":polygon(shape)} for prop in props for i,shape in enumerate(prop["silhouette_polygons"])],
        "threshold_fog":{"density_mask":"res://asset/map/painted/halts/underworld_threshold_v1/fog_density.png",
                         "opacity":0.28,"color":"#65b5b2","drift":[-0.0011,0.00004],"scale":1.1,"seed":31},
        "ambience":{"footsteps":"stone", "sources":[
            {"id":"gate_left","kind":"fire","point":norm([1020,305]),"radius":0.26,"gain_db":-22},
            {"id":"gate_right","kind":"fire","point":norm([1301,418]),"radius":0.26,"gain_db":-22}]},
        "review":{"dry":True,"stable_pixel":norm([694,554]),"fire_pixel":norm([1020,305]),
                  "forbidden_points":[norm([578,362]),norm([880,374]),norm([1040,678]),norm([1189,417]),norm([186,632])],
                  "loop_waypoints":[norm(points[k]) for k in ["statue_memory","central","statue_right_behind","right_side","statue_right_front","fallen_oath"]],
                  "occlusion_points":{k:norm(points[k]) for k in ["statue_right_behind","statue_right_front","statue_left_behind"]}},
    }
    write(ROOT / "data/halts/underworld_threshold_v1.json", manifest)
    # Fog data: soft banks at the edges, statue feet, and surrounding abyss.
    yy, xx = np.mgrid[0:H,0:W]
    density = np.full((H,W), 0.85, dtype=np.float64)
    floor = Image.new("L", (W,H))
    ImageDraw.Draw(floor).polygon(outline, fill=255)
    floor = np.asarray(floor.filter(ImageFilter.GaussianBlur(24))) / 255.0
    density *= 1 - floor * .76
    for x,y,sx,sy,a in [(510,403,150,48,.40),(884,402,118,44,.34),(1019,711,180,48,.55)]:
        density += a * np.exp(-(((xx-x)/sx)**2+((yy-y)/sy)**2)/2)
    lane = Image.new("L",(W,H))
    d=ImageDraw.Draw(lane)
    d.line([tuple(points[k]) for k in ["spawn","central","threshold_gate"]],fill=255,width=130)
    for k in ["spawn","central","threshold_gate"]:
        x,y=points[k]; d.ellipse([x-64,y-64,x+64,y+64],fill=255)
    clear=np.asarray(lane.filter(ImageFilter.GaussianBlur(20)))/255.0
    density *= 1-clear
    Image.fromarray(np.rint(np.clip(density,0,1)*255).astype(np.uint8)).save(BUILD/"fog_density.png")
    write(SOURCE/"registration.json", {
        "painting":painting.name,"sha256":digest,"image_size":[W,H],
        "style":"roots_bronze_v1", "style_reference":manifest["source"]["reference"],
        "theme_reference_only":"res://assets/catabase/title/underworld_gate_v1.png",
        "discarded_style_candidate":"painting_original.png (réalisme écarté à la demande utilisateur)",
        "geometry_registration":"Manual native-pixel landmarks, obstacle footprints and silhouettes. No affine registration assumed.",
        "metric_blockout_body_height_ratio":0.1258181,"runtime_player_height_ratio":0.186,
        "painted_body_height_pixels":round(.186*H*202/257,2),
        "scale_review":"Statues plus socles ~280–305px, corps Achille ~138px ; architecture monumentale intentionnelle. Revue runtime à compléter.",
        "authored_points_px":points, "fog_density_sha256":hashlib.sha256((BUILD/"fog_density.png").read_bytes()).hexdigest()})
    sys.path.insert(0,str(ROOT/"tools/halt_workshop"))
    import halt_workshop
    report=halt_workshop.prepare(ROOT/"data/halts/underworld_threshold_v1.json",ROOT)
    print(json.dumps({"passed":True,"id":report["id"],"source_sha256":digest,"foreground_parts":len(manifest["foreground"])}))


if __name__ == "__main__":
    main()
