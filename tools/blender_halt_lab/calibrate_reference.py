"""Technical comparison sheet; never changes the authored painting."""
import argparse
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/source/halts/bronze_workshop_pilot_v1"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-directory", type=Path, default=OUT,
                        help="Source directory containing projection.json and the default blockout")
    parser.add_argument("--points", nargs="+", default=["spawn", "bench_approach", "door_approach"],
                        help="Projection point names used when --manifest is absent")
    parser.add_argument("--image", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    source_directory = (ROOT / args.source_directory).resolve()
    image_path = args.image if args.image is not None else source_directory / "blockout.png"
    output_path = args.output if args.output is not None else source_directory / "scale_guide.png"
    projection = json.loads((source_directory / "projection.json").read_text(encoding="utf-8"))
    if not args.manifest:
        missing = [name for name in args.points if name not in projection["points"]]
        if missing:
            parser.error("Unknown projection points: " + ", ".join(missing))
    atlas = ROOT / "assets/characters/Achilles/sprites_cour_des_sources_v1/atlas_S.png"
    frame = Image.open(atlas).convert("RGBA").crop((0, 0, 512, 384))
    frame.save(source_directory / "achilles_idle_S_reference.png")
    canvas = Image.open(image_path).convert("RGBA")
    width, height = canvas.size
    if args.manifest:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        scale = manifest["world"]["player_height_ratio"] * height / 257
        exit_landmark = next((entry for entry in manifest["landmarks"] if entry.get("action") == "exit"), manifest["landmarks"][-1])
        positions = [manifest["world"]["spawn"], manifest["landmarks"][0]["point"], exit_landmark["point"]]
    else:
        scale = projection["body_height_ratio"] * height / 202
        positions = [projection["points"][name] for name in args.points]
    sprite = frame.resize((round(512 * scale), round(384 * scale)), Image.Resampling.LANCZOS)
    for x, y in positions:
        canvas.alpha_composite(sprite, (round(x * width - 256 * scale), round(y * height - 320 * scale)))
    canvas.save(output_path)
    projection["achilles_reference"] = {
        "profile": "res://data/visuals/achilles/achilles_kit_sprite_profile_v2.tres",
        "frame": "idle_S first frame", "feet_anchor": [256, 320],
        "body_top_y": 118, "body_height_px": 202, "total_height_px": 257,
        "body_top_uncertainty_px": 2,
        "body_convention": "pieds à la calotte du casque, sans plume ni lance",
        "player_height_ratio": round(projection["body_height_ratio"] * 257 / 202, 8),
    }
    (source_directory / "projection.json").write_text(json.dumps(projection, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(output_path), "ratio": round(scale * 257 / height, 8)}))


if __name__ == "__main__":
    main()
