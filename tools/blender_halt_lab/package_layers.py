"""Package manually selected, unchanged painting pixels as editable OpenRaster.

No image generation, inpainting or colour correction happens here. Reconstruction
comes exclusively from the separately generated clean plate. Opaque floor patches
retain painted shadows exactly; they are deliberately not advertised as light masks.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_bytes(image: Image.Image) -> bytes:
    stream = io.BytesIO()
    image.save(stream, format="PNG")
    return stream.getvalue()


def polygon_mask(size: tuple[int, int], polygons: list) -> np.ndarray:
    mask = Image.new("L", size)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        if len(polygon) < 3:
            raise ValueError("A selection must have at least three points")
        points = []
        for x, y in polygon:
            if not (0 <= x < size[0] and 0 <= y < size[1]):
                raise ValueError(f"Selection point {(x, y)} is outside {size}")
            points.append((int(x), int(y)))
        draw.polygon(points, fill=255)
    return np.asarray(mask) > 0


def extract(original: np.ndarray, mask: np.ndarray) -> Image.Image:
    pixels = np.zeros_like(original)
    pixels[mask] = original[mask]
    pixels[:, :, 3] = mask.astype(np.uint8) * 255
    return Image.fromarray(pixels)


def write_layer(archive: zipfile.ZipFile, parent: ET.Element, image: Image.Image,
                identifier: str, name: str, visible: bool = True) -> None:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError(f"Empty layer: {name}")
    source = f"data/{identifier}.png"
    archive.writestr(source, png_bytes(image.crop(bbox)))
    ET.SubElement(parent, "layer", {
        "name": name, "src": source, "x": str(bbox[0]), "y": str(bbox[1]),
        "opacity": "1.0", "visibility": "visible" if visible else "hidden",
        "composite-op": "svg:src-over",
    })


def render_ora(path: Path, hidden_groups: set[str] | None = None) -> Image.Image:
    """Read persisted layer bytes and hierarchy independently of the construction."""
    with zipfile.ZipFile(path) as archive:
        root = ET.fromstring(archive.read("stack.xml"))
        size = int(root.attrib["w"]), int(root.attrib["h"])

        def render(element: ET.Element) -> Image.Image:
            result = Image.new("RGBA", size)
            if element.get("visibility") == "hidden":
                return result
            if hidden_groups and element.get("name") in hidden_groups:
                return result
            if element.tag == "layer":
                image = Image.open(io.BytesIO(archive.read(element.attrib["src"])))
                result.alpha_composite(image.convert("RGBA"),
                                       (int(element.get("x", "0")), int(element.get("y", "0"))))
            else:
                for child in reversed(list(element)):
                    result.alpha_composite(render(child))
            return result

        return render(root.find("stack"))


def compare(a: Image.Image, b: Image.Image) -> dict:
    aa, bb = np.asarray(a.convert("RGBA")), np.asarray(b.convert("RGBA"))
    if aa.shape != bb.shape:
        return {"identical": False, "size_a": list(a.size), "size_b": list(b.size)}
    difference = np.abs(aa.astype(np.int16) - bb.astype(np.int16))
    return {"identical": bool(np.array_equal(aa, bb)),
            "changed_pixels": int(np.count_nonzero(np.any(difference, axis=2))),
            "max_channel_delta": int(difference.max())}


def package(source: Path) -> dict:
    selections_path = source / "layer_selections.json"
    selections = json.loads(selections_path.read_text(encoding="utf-8"))
    document_title = selections.get("title", "Atelier")
    original_path = source / selections["painting"]
    clean_path = source / selections["clean_plate"]
    original = Image.open(original_path).convert("RGBA")
    clean = Image.open(clean_path).convert("RGBA")
    size = original.size
    if clean.size != size or list(size) != selections["image_size"]:
        raise ValueError("Native source and clean plate dimensions must match the selections")
    original_array = np.asarray(original)
    clean_array = np.asarray(clean)
    layer_dir, mask_dir = source / "painted_layers", source / "layer_masks"
    layer_dir.mkdir(exist_ok=True)
    mask_dir.mkdir(exist_ok=True)

    # Front-to-back order partitions any overlap; no pixel belongs to two props.
    claimed = np.zeros((size[1], size[0]), dtype=bool)
    masks = {}
    for prop in selections["props"]:
        mask = polygon_mask(size, prop["silhouette_polygons"])
        mask &= ~polygon_mask(size, prop.get("holes", []))
        mask &= ~claimed
        masks[prop["id"]] = mask
        claimed |= mask
    all_props = claimed.copy()
    core_union = all_props.copy()
    raw_patches = {}
    weight = np.zeros((size[1], size[0]), dtype=np.uint8)
    for prop in selections["props"]:
        identifier = prop["id"]
        core = polygon_mask(size, prop["floor_patch_polygons"]) | masks[identifier]
        core_union |= core
        # A small transition outside the authored region avoids hard clean-plate
        # seams. Its original RGB is also retained by the named floor patch.
        weight_image = Image.fromarray(core.astype(np.uint8) * 255)
        weight_image = weight_image.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(4))
        local_weight = np.asarray(weight_image).copy()
        local_weight[core] = 255
        weight = np.maximum(weight, local_weight)
        raw_patches[identifier] = local_weight > 0
    patches = {}
    for prop in selections["props"]:
        identifier = prop["id"]
        patch = raw_patches[identifier] & ~claimed
        patches[identifier] = patch
        claimed |= patch

    blend = weight.astype(np.float32)[:, :, None] / 255.0
    reconstructed = np.rint(clean_array * blend + original_array * (1.0 - blend)).astype(np.uint8)
    background = Image.fromarray(reconstructed)
    background.save(layer_dir / "background_reconstructed.png")
    layers = {}
    layer_report = []
    for prop in selections["props"]:
        identifier = prop["id"]
        prop_image = extract(original_array, masks[identifier])
        patch_image = extract(original_array, patches[identifier])
        layers[identifier] = prop_image, patch_image
        prop_image.save(layer_dir / f"{identifier}.png")
        patch_image.save(layer_dir / f"{identifier}_floor_patch.png")
        Image.fromarray(masks[identifier].astype(np.uint8) * 255).save(mask_dir / f"{identifier}.png")
        Image.fromarray(patches[identifier].astype(np.uint8) * 255).save(mask_dir / f"{identifier}_floor_patch.png")
        layer_report.append({
            "id": identifier, "name": prop["name"],
            "prop_pixels": int(masks[identifier].sum()),
            "floor_patch_pixels": int(patches[identifier].sum()),
            "prop_bbox_xyxy": list(prop_image.getchannel("A").getbbox()),
            "anchor_image_px": prop["anchor_image_px"],
            "anchor_normalized": [prop["anchor_image_px"][0] / size[0],
                                  prop["anchor_image_px"][1] / size[1]],
            "source_pixels_unchanged": bool(np.array_equal(
                np.asarray(prop_image)[masks[identifier]], original_array[masks[identifier]])),
            "alpha_values": [0, 255],
            "occluded_geometry_reconstructed": False,
        })

    ora_path = source / selections.get("output", "bronze_workshop_layers.ora")
    xml_root = ET.Element("image", {"version": "0.0.6", "w": str(size[0]),
                                   "h": str(size[1]), "name": f"{document_title} — peinture décomposée"})
    stack = ET.SubElement(xml_root, "stack")
    guide_sources = []
    with zipfile.ZipFile(ora_path, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("mimetype", b"image/openraster", compress_type=zipfile.ZIP_STORED)
        guides = ET.SubElement(stack, "stack", {"name": "GUIDES — masqués, hors peinture",
                                                 "visibility": "hidden", "isolation": "isolate"})
        for identifier, filename, name in [
            ("guide_blockout", "blockout.png", "Guide géométrique avant peinture — à recaler — Maquette"),
            ("guide_scale", "scale_guide.png", "Guide géométrique avant peinture — à recaler — Échelle Achille"),
            ("guide_depth", "depth.png", "Guide géométrique avant peinture — à recaler — Profondeur aperçu 8 bits"),
            ("guide_painted_scale", "painted_scale_review.png", "Guide peint — Achille et positions recalées"),
        ]:
            guide_path = source / filename
            if not guide_path.is_file():
                continue
            guide = Image.open(guide_path)
            guide_sources.append({"file": filename, "native_size": list(guide.size),
                                  "reference_size": list(size), "name": name})
            if identifier == "guide_depth":
                values = np.asarray(guide).astype(np.uint16)
                guide = Image.fromarray((values / 257).astype(np.uint8)).convert("RGBA")
            else:
                guide = guide.convert("RGBA")
            guide = guide.resize(size, Image.Resampling.NEAREST)
            write_layer(archive, guides, guide, identifier, name)
        for prop in selections["props"]:
            identifier = prop["id"]
            group = ET.SubElement(stack, "stack", {"name": prop["name"],
                                                    "visibility": "visible", "isolation": "isolate"})
            prop_image, patch_image = layers[identifier]
            write_layer(archive, group, prop_image, identifier, prop["name"] + " — pixels originaux")
            write_layer(archive, group, patch_image, identifier + "_floor_patch",
                        "Raccord de sol + ombre — patch opaque original — " + prop["name"])
        write_layer(archive, stack, background, "background",
                    "Fond — original conservé, clean plate sous objets et raccords")
        archive.writestr("stack.xml", ET.tostring(xml_root, encoding="utf-8", xml_declaration=True))
        archive.writestr("mergedimage.png", png_bytes(original))
        thumbnail = original.copy()
        thumbnail.thumbnail((256, 256))
        archive.writestr("Thumbnails/thumbnail.png", png_bytes(thumbnail))

    flattened = render_ora(ora_path)
    flattened.save(source / "layers_flattened_check.png")
    hidden = render_ora(ora_path, {prop["name"] for prop in selections["props"]})
    hidden.save(source / "props_hidden_check.png")
    overlay = original.copy()
    draw = ImageDraw.Draw(overlay)
    for index, prop in enumerate(selections["props"]):
        color = ["#ff7bc4", "#ffff55", "#62f7ff"][index % 3]
        for polygon in prop["silhouette_polygons"]:
            draw.line([tuple(point) for point in polygon + [polygon[0]]], fill=color, width=2)
        for polygon in prop["floor_patch_polygons"]:
            draw.line([tuple(point) for point in polygon + [polygon[0]]], fill=color, width=1)
        x, y = prop["anchor_image_px"]
        draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=color)
        draw.text((x + 7, y), prop["id"], fill=color)
    overlay.save(source / "layer_selections_review.png")
    tiles = []
    for prop in selections["props"]:
        image = layers[prop["id"]][0]
        image = image.crop(image.getchannel("A").getbbox())
        factor = 4 if prop["id"] == "bucket" else 2
        tiles.append((prop["id"], image.resize((image.width * factor, image.height * factor),
                                              Image.Resampling.NEAREST)))
    sheet = Image.new("RGB", (sum(image.width for _, image in tiles) + 40 * len(tiles),
                              max(image.height for _, image in tiles) + 80), (35, 40, 43))
    sheet_draw = ImageDraw.Draw(sheet)
    at_x = 20
    for identifier, image in tiles:
        sheet_draw.text((at_x, 20), identifier, fill="white")
        for at_y in range(0, image.height, 12):
            for tile_x in range(0, image.width, 12):
                shade = (95, 101, 106) if ((tile_x // 12 + at_y // 12) % 2) else (150, 156, 161)
                sheet_draw.rectangle((at_x + tile_x, 50 + at_y,
                                      at_x + min(tile_x + 11, image.width - 1),
                                      50 + min(at_y + 11, image.height - 1)), fill=shade)
        sheet.paste(image, (at_x, 50), image)
        at_x += image.width + 40
    sheet.save(source / "layer_alpha_review.png")
    hidden_array = np.asarray(hidden)
    flattened_comparison = compare(original, flattened)
    with zipfile.ZipFile(ora_path) as archive:
        merged = Image.open(io.BytesIO(archive.read("mergedimage.png"))).convert("RGBA")
        merged_comparison = compare(original, merged)
        stored_order = [element.get("name") for element in ET.fromstring(archive.read("stack.xml")).find("stack")]
    report = {
        "passed": flattened_comparison["identical"] and merged_comparison["identical"],
        "painting_sha256": sha256(original_path), "clean_plate_sha256": sha256(clean_path),
        "selections_sha256": sha256(selections_path), "ora_sha256": sha256(ora_path),
        "ora": ora_path.name, "image_size": list(size), "rgba_composite": flattened_comparison,
        "ora_mergedimage": merged_comparison, "top_to_bottom_groups": stored_order,
        "layers": layer_report, "reconstructed_pixels": int(claimed.sum()),
        "reconstruction_core_pixels": int(core_union.sum()),
        "reconstruction_transition_pixels": int((claimed & ~core_union).sum()),
        "hidden_props_changed_pixels": compare(original, hidden)["changed_pixels"],
        "hidden_props_equal_clean_plate_inside_reconstruction": bool(np.array_equal(
            hidden_array[core_union], clean_array[core_union])),
        "original_unchanged_outside_reconstruction": bool(np.array_equal(
            hidden_array[~claimed], original_array[~claimed])),
        "props_masks_non_overlapping": int(sum(mask.sum() for mask in masks.values())) == int(all_props.sum()),
        "title": document_title,
        "guides": "Hidden and rescaled only as visual references; geometric sources retain their native dimensions.",
        "guide_sources": guide_sources,
        "limitations": selections["limitations"],
        "krita_export": "Not yet checked; see separate batch report when available.",
    }
    report["passed"] = bool(report["passed"] and all(
        report[key] for key in ["hidden_props_equal_clean_plate_inside_reconstruction",
                               "original_unchanged_outside_reconstruction", "props_masks_non_overlapping"]))
    (source / "layer_packaging_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (source / "LAYER_EDITING.md").write_text(
        f"# {document_title} — calques éditables\n\n"
        f"Ouvrir `{ora_path.name}` dans Krita. Masquer un groupe enlève à la fois "
        "son objet et son raccord de sol. Chaque groupe sépare la silhouette et le patch "
        "qui contient son ombre. Les pixels colorés viennent strictement de l’original.\n\n"
        "Le fond utilise le clean plate imagegen uniquement dans les zones de reconstruction. "
        "Une transition douce de quelques pixels raccorde la texture aux bords de ces zones. "
        "Hors des zones et de leur transition, le fond reste identique à la peinture originale. "
        f"`props_hidden_check.png` montre le résultat sans les {len(selections['props'])} groupes.\n\n"
        "Les ombres sont des patches RGB opaques sur alpha binaire, pas une ombre physique "
        "translucide ou un calque Multiply. Déplacer un objet nécessite de retoucher son "
        "ombre et son raccord : le patch transporte aussi la texture de dalle. Les contours "
        "sont mesurés à la main sur la peinture. Ils ne reconstituent pas les surfaces des "
        "objets qui étaient cachées dans la peinture. La limite des sélections garde des pixels de bord "
        "déjà mélangés au décor par la peinture d’origine.\n\n"
        "Les guides géométriques restent masqués, marqués « avant peinture — à recaler », "
        f"et sont simplement redimensionnés vers {size[0]}×{size[1]}. "
        "Leurs dimensions natives sont consignées par fichier dans `guide_sources` du rapport. "
        "Le guide de profondeur est un aperçu 8 bits ; les données 16 bits originales restent "
        "dans `depth.png`. Ils ne constituent pas une recalibration de la peinture.\n\n"
        "Reconstruction reproductible : `package_layers.py --source " + source.as_posix() + "`. "
        "`layer_packaging_report.json` compare les pixels de la composition relue depuis "
        "les calques de l’archive et ceux de son mergedimage, séparément.\n", encoding="utf-8")
    if not report["passed"]:
        raise RuntimeError("OpenRaster reconstruction failed its exact pixel checks")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()
    result = package(args.source)
    print(json.dumps({key: result[key] for key in ["passed", "ora", "rgba_composite", "ora_mergedimage", "reconstructed_pixels"]}, indent=2))
