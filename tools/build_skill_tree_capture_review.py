from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CAPTURES = ROOT / "artifacts" / "skill_tree_refined" / "captures"
BEFORE = CAPTURES / "skill_tree_before_1920x1080.png"
AFTER = CAPTURES / "skill_tree_after_elf_archer_available_1920x1080.png"


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    try:
        return ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", size)
    except OSError:
        return ImageFont.load_default()


def _fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    background = Image.new("RGB", size, (7, 9, 12))
    position = ((size[0] - copy.width) // 2, (size[1] - copy.height) // 2)
    background.paste(copy, position)
    return background


def build_before_after() -> None:
    tile_size = (960, 540)
    header_height = 54
    canvas = Image.new("RGB", (1920, header_height + tile_size[1]), (10, 12, 16))
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 13), "AVANT · navigation horizontale", font=_font(23), fill=(210, 214, 220))
    draw.text((984, 13), "APRÈS · quatre zones stables", font=_font(23), fill=(226, 189, 72))
    with Image.open(BEFORE).convert("RGB") as before:
        canvas.paste(_fit(before, tile_size), (0, header_height))
    with Image.open(AFTER).convert("RGB") as after:
        canvas.paste(_fit(after, tile_size), (960, header_height))
    canvas.save(CAPTURES / "skill_tree_before_after_comparison.png")


def build_blurred_reduced() -> None:
    with Image.open(AFTER).convert("RGB") as after:
        blurred = after.filter(ImageFilter.GaussianBlur(radius=12))
        blurred.thumbnail((640, 360), Image.Resampling.LANCZOS)
        blurred.save(CAPTURES / "skill_tree_after_blurred_reduced.png")


def build_contact_sheet() -> None:
    entries = [
        ("AVANT", "skill_tree_before_1920x1080.png"),
        ("ARCHER · DISPONIBLE", "skill_tree_after_elf_archer_available_1920x1080.png"),
        ("ARCHER · ACQUIS", "skill_tree_after_elf_archer_acquired_1920x1080.png"),
        ("ARCHER · XP REQUISE", "skill_tree_after_elf_archer_locked_1920x1080.png"),
        ("ARCHER · EXCLUSIF", "skill_tree_after_elf_archer_exclusive_1920x1080.png"),
        ("ARCHER · SPÉCIALISATION", "skill_tree_after_elf_archer_specialization_1920x1080.png"),
        ("ARCHER · MAX", "skill_tree_after_elf_archer_max_1920x1080.png"),
        ("ELFE · ASSASSIN", "skill_tree_after_elf_assassin_1920x1080.png"),
        ("ELFE · MAGE", "skill_tree_after_elf_mage_1920x1080.png"),
        ("ELFE · SOIGNEUR", "skill_tree_after_elf_healer_1920x1080.png"),
        ("MAGE · 4 BRANCHES", "skill_tree_after_mage_branches_1920x1080.png"),
        ("GARDIEN · NON DÉFINIE", "skill_tree_after_guardian_undefined_1920x1080.png"),
        ("RESPONSIVE · 1280×720", "skill_tree_after_elf_archer_1280x720.png"),
        ("RESPONSIVE · 2560×1440", "skill_tree_after_elf_archer_2560x1440.png"),
    ]
    columns = 2
    tile_size = (720, 405)
    label_height = 42
    rows = (len(entries) + columns - 1) // columns
    canvas = Image.new(
        "RGB",
        (columns * tile_size[0], rows * (tile_size[1] + label_height)),
        (7, 9, 12),
    )
    draw = ImageDraw.Draw(canvas)
    for index, (label, filename) in enumerate(entries):
        column = index % columns
        row = index // columns
        x = column * tile_size[0]
        y = row * (tile_size[1] + label_height)
        draw.text((x + 14, y + 9), label, font=_font(20), fill=(226, 189, 72))
        with Image.open(CAPTURES / filename).convert("RGB") as image:
            canvas.paste(_fit(image, tile_size), (x, y + label_height))
    canvas.save(CAPTURES / "skill_tree_capture_contact_sheet.png")


if __name__ == "__main__":
    build_before_after()
    build_blurred_reduced()
    build_contact_sheet()
    print("Capture review assets generated in", CAPTURES)
