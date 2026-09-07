"""Run in the Higgsfield sandbox. Exported bundle contains media and metadata only."""
from pathlib import Path
from urllib.request import urlretrieve
import hashlib, json, zipfile
import numpy as np
from scipy import ndimage
from PIL import Image, ImageOps, ImageDraw

ROOT = Path("/home/user/catabase_pilot/bundle")
SOURCE = ROOT / "art/source/catabase/painted"
RUNTIME = ROOT / "assets/catabase/painted"
REVIEW = ROOT / "artifacts/catabase_painted_art"
for folder in [SOURCE / "generations", SOURCE / "references", RUNTIME / "icons", RUNTIME / "halts", REVIEW]:
    folder.mkdir(parents=True, exist_ok=True)
(SOURCE / ".gdignore").write_text("")
(REVIEW / ".gdignore").write_text("")
BASE = "https://d8j0ntlcm91z4.cloudfront.net/user_3Ixm0qCahpQeob0xcZCb9tdKY43/"
INPUTS = {
    "icons": ("hf_20260907_142922_10757605-4fba-4fe8-8af9-ac4c98ee28b0.png", SOURCE / "generations/icons_martial_sheet.png"),
    "camp": ("hf_20260907_142922_71aaec1c-eabf-45a3-a23e-327eedc9cfe9.png", SOURCE / "generations/camp_compagnons.png"),
    "library": ("hf_20260907_113139_2bf07a34-7aa1-4c05-9c90-969d0bf3fb14.png", SOURCE / "references/bibliotheque_engloutie.png"),
    "original_icons": ("hf_20260907_113139_e4a45c02-674a-4f7d-b4b2-9ba80ec6448d.png", SOURCE / "references/inventory_icons.png"),
}
for key, (filename, target) in INPUTS.items():
    urlretrieve(BASE + filename, target)
KEYS = ["peleid_strike", "fulminant_dash", "pelion_shot", "bronze_guard",
        "crochet", "fauchage", "entaille", "moisson",
        "rupture", "marque", "feinte", "contretemps",
        "heurt", "posture", "souffle", "marche"]
rgb = np.asarray(Image.open(INPUTS["icons"][1]).convert("RGB"))
assert rgb.shape == (2048, 2048, 3), "Re-review segmentation when the source changes"
assert hashlib.sha256(INPUTS["icons"][1].read_bytes()).hexdigest() == "764ac30f348904d17ff09dff19cf8344fbe7dd31fc58eafbb35c7f3860087e0e"
background = np.array([20, 29, 46])
foreground = np.max(np.abs(rgb.astype(float) - background), axis=2) > 25
labels, count = ndimage.label(foreground)
centers_x = np.array([280, 775, 1280, 1768])
centers_y = np.array([275, 775, 1274, 1770])
owners = np.zeros(labels.shape, dtype=np.int16)
# Assign complete connected painted marks, so the irregular last row is not
# guillotined by a mechanically even atlas grid. Retain detached action shards.
for label, bounds in enumerate(ndimage.find_objects(labels), 1):
    if bounds is None:
        continue
    yy, xx = bounds
    center_x = (xx.start + xx.stop) / 2
    center_y = (yy.start + yy.stop) / 2
    col = int(np.argmin(abs(centers_x - center_x)))
    row = int(np.argmin(abs(centers_y - center_y)))
    owners[bounds][labels[bounds] == label] = row * 4 + col + 1
# Reviewed exception: the counterstrike highlight touches the recovery gem.
# Separate them in the empty visual seam; preserve the upper blade and lower gem.
joined = (labels == 133)
assert joined.sum() > 100000
owners[joined & (np.indices(labels.shape)[0] < 1460)] = 12
owners[joined & (np.indices(labels.shape)[0] >= 1460)] = 16
# Carry the original antialiasing and soft glows into a modest background apron.
distance, nearest = ndimage.distance_transform_edt(~foreground, return_indices=True)
nearest_owner = owners[nearest[0], nearest[1]]
alpha = np.exp(-np.maximum(distance - 4, 0) ** 2 / (2 * 10 ** 2))
alpha[distance > 36] = 0
records = []
exports = []
for index, key in enumerate(KEYS, 1):
    solid = owners == index
    ys, xs = np.where(solid)
    assert len(xs) > 10000, key
    x0, y0 = max(0, xs.min()-36), max(0, ys.min()-36)
    x1, y1 = min(2048, xs.max()+37), min(2048, ys.max()+37)
    a = alpha[y0:y1, x0:x1] * (nearest_owner[y0:y1, x0:x1] == index)
    colors = rgb[y0:y1, x0:x1].astype(float)
    isolated = np.uint8(np.clip(colors * a[:,:,None] + background * (1-a[:,:,None]), 0, 255))
    crop = Image.fromarray(isolated, "RGB")
    fitted = ImageOps.contain(crop, (228, 228), Image.Resampling.LANCZOS)
    output = Image.new("RGB", (256, 256), tuple(background))
    output.paste(fitted, ((256-fitted.width)//2, (256-fitted.height)//2))
    path = RUNTIME / "icons" / (key + ".png")
    output.save(path, optimize=True)
    exports.append(output)
    records.append({"id": key, "source": "generations/icons_martial_sheet.png", "source_box": [int(x0),int(y0),int(x1),int(y1)], "path": str(path.relative_to(ROOT)), "dimensions":[256,256], "sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
for key, dest in [("camp", "camp_compagnons"), ("library", "bibliotheque_engloutie")]:
    source = Image.open(INPUTS[key][1]).convert("RGB")
    output = ImageOps.fit(source, (1920, 1200), Image.Resampling.LANCZOS, centering=(0.5,0.5))
    path = RUNTIME / "halts" / (dest + ".png")
    output.save(path, optimize=True)
    records.append({"id": dest, "source": str(INPUTS[key][1].relative_to(SOURCE)), "source_dimensions":list(source.size), "transform":"uniform scale + central crop, no anisotropic distortion", "path":str(path.relative_to(ROOT)), "dimensions":[1920,1200], "sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
# Review contact sheet is a sandbox export, not runtime artwork.
review = Image.new("RGB", (1120, 960), (16,24,36))
draw = ImageDraw.Draw(review)
for i, (key, icon) in enumerate(zip(KEYS,exports)):
    x, y = (i%4)*280, (i//4)*240
    review.paste(icon.resize((176,176),Image.Resampling.LANCZOS),(x+4,y+8))
    for j, size in enumerate([64,48]):
        review.paste(icon.resize((size,size),Image.Resampling.LANCZOS),(x+195,y+20+j*86))
    draw.text((x+8,y+196),key,fill=(223,203,156))
    draw.text((x+195,y+174),"64 / 48 px",fill=(180,185,190))
review.save(REVIEW / "icon_review.png")
meta = {"schema_version":1,"provider":"Higgsfield","pipeline":"tools/catabase_art_pipeline/build_pilot.py","creative_generation_jobs":["10757605-4fba-4fe8-8af9-ac4c98ee28b0","71aaec1c-eabf-45a3-a23e-327eedc9cfe9"],"source_hashes":{k:hashlib.sha256(p.read_bytes()).hexdigest() for k,(_,p) in INPUTS.items()},"processing":"Higgsfield sandbox only; connected-mark extraction, uniform resampling, central crop. No model generation outside Higgsfield.","exports":records,"review":{"style":"inspected against approved references","small_icons":"pending local review","runtime":"pending"}}
(SOURCE / "pilot_exports.json").write_text(json.dumps(meta,indent=2),encoding="utf-8")
with zipfile.ZipFile("/home/user/catabase_pilot/catabase_pilot.zip","w",zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(ROOT.rglob("*")):
        if path.is_file():
            assert path.suffix.lower() in [".png",".json",".gdignore"] or path.name == ".gdignore"
            archive.write(path,str(path.relative_to(ROOT)))
print(json.dumps({"export_count":len(records),"bundle_bytes":Path("/home/user/catabase_pilot/catabase_pilot.zip").stat().st_size,"exports":records}))
