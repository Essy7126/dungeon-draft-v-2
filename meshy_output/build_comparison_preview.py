"""Embed reduced, unretouched WebP previews in the task-owned comparison fragment."""
import base64
import io
import json
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
FRAGMENT = Path("C:/Users/p.montebello/.codex/visualizations/2026/09/07/01a07c60-79a0-7d51-aa84-cb75377491a8/meshy-higgsfield-comparison.html")
SOURCES = {
    "library": {
        "higgsfield": "art/source/catabase/painted/references/bibliotheque_engloutie.png",
        "nb2": "meshy_output/20260907_170912_compare-higgsfield-flooded-lib_01a07c6a/image.png",
        "pro": "meshy_output/20260907_171046_compare-higgsfield-flooded-lib_01a07c6b/image.png",
    },
    "icons": {
        "higgsfield": "art/source/catabase/painted/references/inventory_icons.png",
        "nb2": "meshy_output/20260907_170912_compare-higgsfield-inventory-i_01a07c6a/image.png",
        "pro": "meshy_output/20260907_171046_compare-higgsfield-inventory-i_01a07c6b/image.png",
    },
}


def previews(quality):
    result = {}
    for subject, providers in SOURCES.items():
        result[subject] = {}
        for provider, relative_path in providers.items():
            with Image.open(PROJECT / relative_path) as original:
                width, height = original.size
                preview = original.convert("RGBA" if "A" in original.getbands() else "RGB")
                preview.thumbnail((720, 720), Image.Resampling.LANCZOS)
                buffer = io.BytesIO()
                preview.save(buffer, format="WEBP", quality=quality, method=6)
                result[subject][provider] = {
                    "width": width,
                    "height": height,
                    "previewWidth": preview.width,
                    "previewHeight": preview.height,
                    "src": "data:image/webp;base64," + base64.b64encode(buffer.getvalue()).decode("ascii"),
                }
    return result


template = FRAGMENT.read_text(encoding="utf-8")
opening = '<script type="application/json" data-images>'
start = template.index(opening) + len(opening)
end = template.index("</script>", start)
for quality in (82, 76, 70, 64, 58):
    data = previews(quality)
    fragment = template[:start] + json.dumps(data, ensure_ascii=False, separators=(",", ":")) + template[end:]
    encoded = fragment.encode("utf-8")
    if len(encoded) < 1_000_000:
        FRAGMENT.write_bytes(encoded)
        print(json.dumps({"bytes": len(encoded), "webp_quality": quality, "images": {s: {p: [i["width"], i["height"]] for p, i in ps.items()} for s, ps in data.items()}}, ensure_ascii=False))
        break
else:
    raise RuntimeError("Previews do not fit the 1 MB budget")
