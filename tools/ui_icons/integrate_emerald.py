"""Integrate the individually generated paintings; keep all route assets untouched.

Does not generate or edit pixels. Run only after every requested PNG exists.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OLD = "assets/catabase/icons/"
NEW = "assets/catabase/emerald_icons_v2/"
SOURCE = ROOT / "art/source/catabase/emerald_icons_v2"


def main():
    manifest = json.loads((ROOT / OLD / "manifest.json").read_text(encoding="utf-8"))
    before = json.loads((SOURCE / "route_before.json").read_text(encoding="utf-8"))
    for name, digest in before.items():
        assert hashlib.sha256((ROOT / OLD / "route" / name).read_bytes()).hexdigest() == digest, name
    paintings = [entry for entry in manifest["icons"] if entry["group"] != "route"]
    missing = []
    for entry in paintings:
        path = ROOT / NEW / entry["group"] / (entry["id"] + ".png")
        if not path.exists() or path.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
            missing.append(str(path.relative_to(ROOT)))
    if missing:
        raise SystemExit("Missing generated paintings: " + ", ".join(missing))
    for entry in paintings:
        relative = NEW + entry["group"] + "/" + entry["id"] + ".png"
        entry["path"] = relative
        entry["size"] = 256
        entry["medium"] = "hand-painted raster; low detail"
        source = "res://" + relative
        cache = "res://.godot/imported/" + Path(relative).name + "-" + hashlib.md5(source.encode()).hexdigest() + ".ctex"
        settings = '\n'.join([
            '[remap]', 'importer="texture"', 'type="CompressedTexture2D"',
            'path="' + cache + '"', '', '[deps]',
            'source_file="' + source + '"', 'dest_files=["' + cache + '"]',
            '', '[params]', 'compress/mode=0', 'mipmaps/generate=true',
            'process/size_limit=256', 'detect_3d/compress_to=0', '',
        ])
        (ROOT / (relative + ".import")).write_text(settings, encoding="utf-8")
    manifest["style"] = "Catabase · illustrations peintes sobres / Émeraude"
    manifest["provenance"] = "185 individual built-in imagegen paintings; prompts and receipts in art/source/catabase/emerald_icons_v2. The 12 existing route SVGs are unchanged."
    (ROOT / NEW / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    pattern = re.compile(r'res://assets/catabase/icons/((?!route/)[a-z_]+/[a-zA-Z0-9_]+)\.svg')
    changed = []
    for folder in ["ui", "data"]:
        for path in (ROOT / folder).rglob("*"):
            if path.suffix not in {".gd", ".tres"}:
                continue
            old = path.read_text(encoding="utf-8")
            new = pattern.sub(lambda match: "res://" + NEW + match[1] + ".png", old)
            if path.name == "character_hud_theme_data.gd":
                new = new.replace('res://assets/catabase/icons/spells/', 'res://' + NEW + 'spells/')
            if path.name == "catabase_icon_library.gd":
                new = new.replace(
                    '## Shared original vector glyphs. Names are local identifiers, never arbitrary paths.',
                    '## Painted icons for equipment, spells and UI; the map keeps its original symbols.',
                ).replace(
                    'const ROOT := "res://' + OLD + '"',
                    'const ROOT := "res://' + NEW + '"\nconst MAP_ROOT := "res://' + OLD + '"',
                ).replace(
                    'var path := ROOT + group + "/" + id + ".svg"',
                    'var path := (MAP_ROOT if group == "route" else ROOT) + group + "/" + id + (".svg" if group == "route" else ".png")',
                )
            if new != old:
                path.write_text(new, encoding="utf-8")
                changed.append(str(path.relative_to(ROOT)))
    print(json.dumps({"paintings": len(paintings), "unchanged_route_icons": len(before), "updated_files": changed}))


if __name__ == "__main__":
    main()
