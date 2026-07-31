from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "asset" / "ui" / "dungeon_draft" / "arbre_compétences" / "cadenas.jpg"
OUTPUT = SOURCE.parent / "generated" / "lock_refined.png"


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    rgba = Image.new("RGBA", source.size)
    output_pixels = rgba.load()
    source_pixels = source.load()
    for y in range(source.height):
        for x in range(source.width):
            red, green, blue = source_pixels[x, y]
            distance_from_white = max(255 - red, 255 - green, 255 - blue)
            alpha = max(0, min(255, (distance_from_white - 7) * 14))
            output_pixels[x, y] = (red, green, blue, alpha)

    bounds = rgba.getbbox()
    if bounds is None:
        raise RuntimeError("Le cadenas source ne contient aucun pixel exploitable.")
    cropped = rgba.crop(bounds)
    side = max(cropped.width, cropped.height) + 36
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(
        cropped,
        ((side - cropped.width) // 2, (side - cropped.height) // 2),
    )
    refined = square.resize((256, 256), Image.Resampling.LANCZOS)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    refined.save(OUTPUT, optimize=True)
    print(
        f"Generated {OUTPUT} from {source.size[0]}x{source.size[1]} "
        f"JPEG; output={refined.size[0]}x{refined.size[1]} RGBA"
    )


if __name__ == "__main__":
    main()
