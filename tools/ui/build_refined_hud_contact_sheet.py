from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
CAPTURES = ROOT / "artifacts" / "hud_refined_characters" / "captures"
OUTPUT = CAPTURES / "hud_refined_characters_contact_sheet.png"
CHARACTERS = [
    ("Elfe", "elf"),
    ("Mage", "mage"),
    ("Gardien", "guardian"),
    ("Guerrier", "warrior"),
    ("Druide", "druid"),
    ("Assassin", "assassin"),
    ("Nécromant", "necromancer"),
    ("Hoplite", "hoplite"),
]


def main() -> None:
    cell_width = 1200
    crop_top = 720
    label_height = 54
    source_crop_height = 1080 - crop_top
    cell_image_height = round(source_crop_height * cell_width / 1920)
    cell_height = label_height + cell_image_height
    sheet = Image.new("RGB", (cell_width * 2, cell_height * 4), (11, 15, 19))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", size=28)

    for index, (display_name, slug) in enumerate(CHARACTERS):
        path = CAPTURES / f"hud_refined_{slug}_selected_1920x1080.png"
        with Image.open(path) as source:
            crop = source.convert("RGB").crop((0, crop_top, 1920, 1080))
            crop = crop.resize((cell_width, cell_image_height), Image.Resampling.LANCZOS)
        column = index % 2
        row = index // 2
        x = column * cell_width
        y = row * cell_height
        accent = (186, 150, 62)
        draw.rectangle((x, y, x + cell_width - 1, y + cell_height - 1), outline=(54, 61, 58), width=2)
        draw.text((x + 22, y + 12), display_name, font=font, fill=(236, 230, 207))
        draw.line((x, y + label_height - 1, x + cell_width, y + label_height - 1), fill=accent, width=2)
        sheet.paste(crop, (x, y + label_height))

    sheet.save(OUTPUT, optimize=True)
    print(OUTPUT)


if __name__ == "__main__":
    main()
