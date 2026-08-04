"""Deterministic normalizer for the three Dynamic Arena wall sources.

The source PNG files are read-only inputs.  Every output shares one canvas,
one alpha bounding box and one bottom-centre ground pivot.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
RAW_DIR = ROOT / "tools/labs/dynamic_arena/assets/raw"
NORMALIZED_DIR = ROOT / "tools/labs/dynamic_arena/assets/normalized"
BOARD_PATH = ROOT / "artifacts/labs/dynamic_arena/walls_final/wall_assets_normalized.png"

CANVAS_SIZE = (512, 704)
USEFUL_BOUNDS = (32, 32, 480, 672)  # x0, y0, x1, y1: 448 x 640
GROUND_PIVOT = (256, 672)
ALPHA_THRESHOLD = 1
NAMES = ("wall_base", "wall_fire", "wall_ice")


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    windows = Path("C:/Windows/Fonts")
    candidate = windows / ("arialbd.ttf" if bold else "arial.ttf")
    if candidate.exists():
        return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def _alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > ALPHA_THRESHOLD else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError("wall source has no useful alpha")
    return bounds


def _normalise(source: Image.Image) -> Image.Image:
    source = source.convert("RGBA")
    alpha = source.getchannel("A").point(
        lambda value: 0 if value <= ALPHA_THRESHOLD else value
    )
    source.putalpha(alpha)
    crop = source.crop(_alpha_bounds(source))
    useful_size = (
        USEFUL_BOUNDS[2] - USEFUL_BOUNDS[0],
        USEFUL_BOUNDS[3] - USEFUL_BOUNDS[1],
    )
    crop = crop.resize(useful_size, Image.Resampling.LANCZOS)
    output = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    output.alpha_composite(crop, (USEFUL_BOUNDS[0], USEFUL_BOUNDS[1]))
    return output


def _silhouette(image: Image.Image, colour: tuple[int, int, int, int]) -> Image.Image:
    result = Image.new("RGBA", image.size, colour)
    result.putalpha(image.getchannel("A").point(lambda value: value * colour[3] // 255))
    return result


def _save_board(images: dict[str, Image.Image]) -> None:
    board = Image.new("RGBA", (1600, 900), (13, 21, 32, 255))
    draw = ImageDraw.Draw(board)
    title_font = _font(34, True)
    heading_font = _font(24, True)
    body_font = _font(18)
    accent = {"wall_base": "#c8a98e", "wall_fire": "#ff693b", "wall_ice": "#9bdcff"}

    draw.text((42, 24), "DYNAMIC WALLS — NORMALISATION TECHNIQUE", fill="#eaf6ff", font=title_font)
    draw.text(
        (42, 66),
        "Canvas commun 512×704 • bbox utile 448×640 • pivot sol (256, 672) • empreinte 1×1",
        fill="#91a8bc",
        font=body_font,
    )

    panel_w = 492
    for index, name in enumerate(NAMES):
        x = 32 + index * 520
        y = 108
        draw.rounded_rectangle((x, y, x + panel_w, y + 566), radius=14, fill="#182637", outline="#36516a", width=2)
        draw.rectangle((x, y, x + panel_w, y + 7), fill=accent[name])
        draw.text((x + 22, y + 22), name, fill="#f4f9fd", font=heading_font)

        thumb = images[name].resize((282, 387), Image.Resampling.LANCZOS)
        tx, ty = x + 105, y + 68
        board.alpha_composite(thumb, (tx, ty))
        sx, sy = 282 / CANVAS_SIZE[0], 387 / CANVAS_SIZE[1]
        bbox = (
            tx + round(USEFUL_BOUNDS[0] * sx),
            ty + round(USEFUL_BOUNDS[1] * sy),
            tx + round(USEFUL_BOUNDS[2] * sx),
            ty + round(USEFUL_BOUNDS[3] * sy),
        )
        draw.rectangle(bbox, outline=accent[name], width=2)
        px = tx + round(GROUND_PIVOT[0] * sx)
        py = ty + round(GROUND_PIVOT[1] * sy)
        draw.line((px - 10, py, px + 10, py), fill="#ffffff", width=2)
        draw.line((px, py - 10, px, py + 10), fill="#ffffff", width=2)
        draw.text((x + 22, y + 475), "bbox: x32 y32 • 448×640", fill="#c9d7e2", font=body_font)
        draw.text((x + 22, y + 503), "pivot: centre bas (256, 672)", fill="#c9d7e2", font=body_font)
        draw.text((x + 22, y + 531), "ancrage racine: centre de cellule", fill="#c9d7e2", font=body_font)

    draw.text((42, 718), "SILHOUETTES SUPERPOSÉES", fill="#f4f9fd", font=heading_font)
    draw.text((42, 753), "Les trois volumes partagent exactement la même boîte utile et le même point au sol.", fill="#91a8bc", font=body_font)
    colours = ((231, 187, 151, 88), (255, 76, 37, 88), (91, 209, 255, 88))
    overlay_pos = (1045, 685)
    for name, colour in zip(NAMES, colours):
        silhouette = _silhouette(images[name], colour).resize((154, 212), Image.Resampling.LANCZOS)
        board.alpha_composite(silhouette, overlay_pos)
    draw.rectangle((1055, 695, 1189, 888), outline="#dcefff", width=2)
    draw.line((1122, 876, 1122, 895), fill="#ffffff", width=2)
    draw.line((1113, 886, 1131, 886), fill="#ffffff", width=2)

    BOARD_PATH.parent.mkdir(parents=True, exist_ok=True)
    board.convert("RGB").save(BOARD_PATH, "PNG")


def main() -> None:
    NORMALIZED_DIR.mkdir(parents=True, exist_ok=True)
    normalised: dict[str, Image.Image] = {}
    for name in NAMES:
        source_path = RAW_DIR / f"{name}.png"
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        output = _normalise(Image.open(source_path))
        output_path = NORMALIZED_DIR / f"{name}.png"
        output.save(output_path, "PNG")
        bounds = _alpha_bounds(output)
        if output.size != CANVAS_SIZE or bounds != USEFUL_BOUNDS:
            raise AssertionError(f"{name}: size={output.size} bbox={bounds}")
        normalised[name] = output
        print(f"NORMALIZED {name}: canvas={output.size} bbox={bounds} pivot={GROUND_PIVOT}")
    _save_board(normalised)
    print(f"BOARD {BOARD_PATH}")


if __name__ == "__main__":
    main()
