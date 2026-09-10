"""Prepare the approved grounded composition from authored data and exact sources."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/source/halts/underworld_threshold_v1/grounded"
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
    BUILD.mkdir(parents=True, exist_ok=True)
    target = BUILD / "threshold_grounded.png"
    if target.exists() and target.read_bytes() != original:
        raise ValueError("Immutable runtime source changed; use another version")
    target.write_bytes(original)
    selections = SOURCE / "layer_selections.json"
    if selections.exists():
        props = json.loads(selections.read_text(encoding="utf-8"))["props"]
        authored["foreground"] = [
            {"id":p["id"]+str(index),
             "anchor":[p["anchor_image_px"][0]/width,p["anchor_image_px"][1]/height],
             "polygon":[[x/width,y/height] for x,y in shape]}
            for p in props for index,shape in enumerate(p["silhouette_polygons"])]
    yy, xx = np.mgrid[0:height,0:width]
    density = np.full((height,width),.9,dtype=np.float64)
    lane = Image.new("L",(width,height))
    path = [[round(x*width),round(y*height)] for x,y in authored["navigation"]["outline"]]
    ImageDraw.Draw(lane).polygon(path,fill=255)
    road = np.asarray(lane.filter(ImageFilter.GaussianBlur(28)))/255.0
    density *= 1-road*.80
    for x,y,sx,sy,a in [(521,545,120,48,.30),(696,402,92,38,.34),(1004,742,155,45,.5)]:
        density += a*np.exp(-(((xx-x)/sx)**2+((yy-y)/sy)**2)/2)
    clear = Image.new("L",(width,height));d=ImageDraw.Draw(clear)
    centres=[(423,779),(599,658),(741,533),(1056,445),(1257,450)]
    d.line(centres,fill=255,width=112)
    for x,y in centres: d.ellipse([x-55,y-55,x+55,y+55],fill=255)
    density *= 1-np.asarray(clear.filter(ImageFilter.GaussianBlur(22)))/255.0
    Image.fromarray(np.rint(np.clip(density,0,1)*255).astype(np.uint8)).save(BUILD/"fog_density.png")
    write(ROOT/"data/halts/underworld_threshold_v1.json",authored)
    sys.path.insert(0,str(ROOT/"tools/halt_workshop"))
    import halt_workshop
    report=halt_workshop.prepare(ROOT/"data/halts/underworld_threshold_v1.json",ROOT)
    print(json.dumps({"passed":True,"id":report["id"],"foreground_parts":len(authored["foreground"]),
                      "source_sha256":authored["source"]["sha256"]}))


if __name__ == "__main__":
    main()
