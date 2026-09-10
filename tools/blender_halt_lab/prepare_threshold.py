"""Prepare the ashen threshold from immutable art and reviewed technical data."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/source/halts/underworld_threshold_v1/ash"
BUILD = ROOT / "asset/map/painted/halts/underworld_threshold_v1"


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    authored = json.loads((SOURCE / "runtime_definition.json").read_text(encoding="utf-8"))
    source = SOURCE / "painting_original.png"
    original = source.read_bytes()
    width, height = Image.open(source).size
    assert [width, height] == authored["source"]["size"]
    assert hashlib.sha256(original).hexdigest() == authored["source"]["sha256"]
    target = ROOT / authored["source"]["image"].removeprefix("res://")
    if target.exists() and target.read_bytes() != original:
        raise ValueError("Immutable runtime painting changed; use another version")
    BUILD.mkdir(parents=True, exist_ok=True)
    target.write_bytes(original)
    selections = SOURCE / "layer_selections.json"
    if selections.exists():
        data = json.loads(selections.read_text(encoding="utf-8"))
        assert data["image_size"] == [width,height]
        props=data["props"]
        if any(p.get("holes") for p in props):
            raise ValueError("Runtime requires simple polygon components; split alpha holes")
        authored["foreground"] = [
            {"id":p["id"]+str(index),
             "anchor":[p["anchor_image_px"][0]/width,p["anchor_image_px"][1]/height],
             "polygon":[[x/width,y/height] for x,y in shape]}
            for p in props for index,shape in enumerate(p["silhouette_polygons"])]
    # Three local banks of smoke on burned earth. All values are technical data.
    yy, xx = np.mgrid[0:height,0:width]
    density=np.zeros((height,width),dtype=np.float64)
    for x,y,sx,sy,a in [(320,432,180,60,.84),(451,188,155,65,.76),(1352,772,190,90,1.0)]:
        density += a*np.exp(-(((xx-x)/sx)**2+((yy-y)/sy)**2)/2)
    # Preserve the main route and the pedestal faces; smoke stays on the ground.
    clear=Image.new("L",(width,height));d=ImageDraw.Draw(clear)
    centres=[(380,660),(855,532),(1310,411)]
    d.line(centres,fill=255,width=108)
    for x,y in centres:d.ellipse([x-53,y-53,x+53,y+53],fill=255)
    for part in authored["foreground"]:
        d.polygon([(x*width,y*height) for x,y in part["polygon"]],fill=255)
    density *= 1-np.asarray(clear.filter(ImageFilter.GaussianBlur(12)))/255.0
    Image.fromarray(np.rint(np.clip(density,0,1)*255).astype(np.uint8)).save(BUILD/"fog_density.png")
    write(ROOT/"data/halts/underworld_threshold_v1.json",authored)
    sys.path.insert(0,str(ROOT/"tools/halt_workshop"))
    import halt_workshop
    report=halt_workshop.prepare(ROOT/"data/halts/underworld_threshold_v1.json",ROOT)
    print(json.dumps({"passed":True,"id":report["id"],"foreground_parts":len(authored["foreground"]),
                      "source_sha256":authored["source"]["sha256"]}))


if __name__ == "__main__":
    main()
