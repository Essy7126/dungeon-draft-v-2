"""Swap only painted land sampling; preserve all authored combat geometry."""
import hashlib
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PAIRS = [
    ("greek_drawn_courtyard_v1", "greek_courtyard_emerald_v2"),
    ("ashen_hell_courtyard_v1", "ashen_courtyard_emerald_v2"),
    ("silent_judgment_courtyard_v1", "judgment_courtyard_emerald_v2"),
    ("lethe_crossing_v1", "lethe_crossing_emerald_v2"),
    ("black_oath_temple_v1", "oath_temple_emerald_v2"),
]
ART = ROOT / "assets/catabase/combat_da_v1"
BASE = ROOT / "artifacts/dev/combat-da-v1/before"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def geometry(plan):
    result = json.loads(json.dumps(plan))
    result["land"].pop("texture_path", None)
    result["land"].pop("texture_scale", None)
    result.pop("floor_palette", None)
    result.pop("props_palette", None)
    return result


def main():
    records = []
    staged = []
    for arena, name in PAIRS:
        asset = ART / (name + ".png")
        raw = asset.read_bytes()
        assert raw[:8] == b"\x89PNG\r\n\x1a\n"
        width, height = struct.unpack(">II", raw[16:24])
        path = ROOT / "data/arenas" / arena / "terrain_plan.json"
        text = path.read_text(encoding="utf-8-sig")
        old = json.loads(text)
        baseline = json.loads((BASE / (arena + ".terrain_plan.json")).read_text(encoding="utf-8-sig"))
        assert geometry(old) == geometry(baseline), "Concurrent plan change: " + arena
        scale = [old["canvas_size"][0] / width, old["canvas_size"][1] / height]
        new_path = "res://assets/catabase/combat_da_v1/" + asset.name
        block = re.search(r'("land"\s*:\s*\{)(.*?)(\n\s*\})', text, re.S)
        assert block, arena
        body, n = re.subn(r'("texture_path"\s*:\s*)"[^"]*"', lambda m: m[1] + json.dumps(new_path), block[2])
        assert n == 1
        body, n = re.subn(r'("texture_scale"\s*:\s*)\[[^\]]*\]', lambda m: m[1] + json.dumps(scale), body)
        assert n == 1
        new_text = text[:block.start(2)] + body + text[block.end(2):]
        new = json.loads(new_text)
        assert geometry(new) == geometry(baseline), arena
        records.append({
            "arena": arena, "plan": str(path.relative_to(ROOT)),
            "old_texture": baseline["land"]["texture_path"],
            "old_scale": baseline["land"].get("texture_scale", [1, 1]),
            "new_texture": new_path, "new_size": [width, height], "new_scale": scale,
            "sha256": sha(asset), "prompt": str(asset.with_suffix(".prompt.txt").relative_to(ROOT)),
            "geometry_and_other_layers_unchanged": True,
        })
        staged.append((path, new_text))
    # All references and invariants must pass before the first write.
    for path, text in staged:
        path.write_text(text, encoding="utf-8")
    manifest = {
        "reference": "res://asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png",
        "reference_sha256": sha(ROOT / "asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png"),
        "provider": "imagegen built-in", "maps": records,
        "policy": "Original art preserved. Land texture and UV sampling only; native canvas unchanged.",
    }
    (ART / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"maps": len(records), "geometry_unchanged": True}))


if __name__ == "__main__":
    main()
