"""Create reusable Godot AtlasTexture resources without modifying painted images."""
from pathlib import Path
import json
import struct

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("manifest.json")


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    count = 0
    for sheet in manifest["atlases"]:
        source = ROOT / sheet["path"].removeprefix("res://")
        header = source.read_bytes()[:24]
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Expected an original PNG atlas: {source}")
        width, height = struct.unpack(">II", header[16:24])
        cell_w, cell_h = width / sheet["columns"], height / sheet["rows"]
        if abs(cell_w - cell_h) > 1:
            raise ValueError(f"Non-square icon cells in {source}: {width} x {height}")
        output = source.parent / "resources"
        output.mkdir(parents=True, exist_ok=True)
        for entry in sheet["entries"]:
            x, y = entry["column"] * cell_w, entry["row"] * cell_h
            text = (
                '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
                f'[ext_resource type="Texture2D" path="{sheet["path"]}" id="sheet"]\n\n'
                '[resource]\natlas = ExtResource("sheet")\n'
                f'region = Rect2({x:.12g}, {y:.12g}, {cell_w:.12g}, {cell_h:.12g})\n'
                'filter_clip = true\n'
            )
            (output / f'{entry["id"]}.tres').write_text(text, encoding="utf-8")
            count += 1
        import_file = source.with_name(source.name + ".import")
        if import_file.exists():
            text = import_file.read_text(encoding="utf-8")
            import_file.write_text(text.replace("mipmaps/generate=false", "mipmaps/generate=true"), encoding="utf-8")
    print(f"Created {count} AtlasTexture resources from {len(manifest['atlases'])} original sheets")


if __name__ == "__main__":
    main()
