"""Export geometric guides from the private workshop lab; run inside Blender.

No render settings, objects, materials, images or .blend files are changed.
Orthographic evaluated triangles are rasterized at pixel centers with a z-buffer.
PNG data is encoded directly, avoiding Blender display transforms on numeric maps.
"""
import hashlib
import io
import json
import math
import os
import re
import shutil
import struct
import time
import uuid
import zlib
from pathlib import Path

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ROOT = Path(bpy.data.filepath).resolve().parents[4]
DEFAULT_OUTPUT_DIRECTORY = "art/source/halts/bronze_workshop_pilot_v1"
DEFAULT_COLLECTION = "Workshop pilot generated"
DEFAULT_REQUIRED_GROUPS = ("pillar", "bucket", "workbench")
OUT = ROOT / DEFAULT_OUTPUT_DIRECTORY
COLLECTION = DEFAULT_COLLECTION


def export_configuration(scene):
    """Read lab-local scene properties before any guide output is created."""
    directory = scene.get("halt_export_directory", DEFAULT_OUTPUT_DIRECTORY)
    if not isinstance(directory, str) or not directory.strip():
        raise RuntimeError("halt_export_directory must be a non-empty path string")
    halt_root = (ROOT / "art/source/halts").resolve()
    output = (ROOT / directory).resolve()
    if output == halt_root or not output.is_relative_to(halt_root):
        raise RuntimeError("Guide output must resolve below ROOT/art/source/halts")
    if output.exists() and not output.is_dir():
        raise RuntimeError("Guide output is not a directory: " + str(output))

    collection_name = scene.get("halt_export_collection", DEFAULT_COLLECTION)
    if not isinstance(collection_name, str) or not collection_name.strip():
        raise RuntimeError("halt_export_collection must be a non-empty collection name")
    collection = bpy.data.collections.get(collection_name)
    if collection is None or collection.hide_render:
        raise RuntimeError("Visible generated collection missing: " + collection_name)

    configured_groups = scene.get("halt_required_groups", DEFAULT_REQUIRED_GROUPS)
    if isinstance(configured_groups, (str, bytes, dict)):
        raise RuntimeError("halt_required_groups must be a sequence of layer names")
    try:
        required_groups = tuple(configured_groups)
    except TypeError as error:
        raise RuntimeError("halt_required_groups must be a sequence of layer names") from error
    if any(not isinstance(group, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", group)
           for group in required_groups):
        raise RuntimeError("halt_required_groups contains an unsafe layer name")
    return output, collection, set(required_groups)


def png_bytes(pixels):
    """Lossless PNG: uint8 gray/RGB/RGBA or uint16 gray, top row first."""
    if pixels.dtype == np.uint16 and pixels.ndim == 2:
        bit_depth, color_type = 16, 0
        data = np.ascontiguousarray(pixels.astype(">u2"))
    elif pixels.dtype == np.uint8:
        channels = 1 if pixels.ndim == 2 else pixels.shape[2]
        if channels not in (1, 3, 4):
            raise ValueError("Unsupported PNG channel count")
        bit_depth, color_type = 8, {1: 0, 3: 2, 4: 6}[channels]
        data = np.ascontiguousarray(pixels)
    else:
        raise ValueError("PNG requires uint8 pixels or uint16 grayscale")
    height, width = data.shape[:2]

    def chunk(kind, payload):
        checksum = zlib.crc32(kind + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)

    compressor = zlib.compressobj(6)
    compressed = bytearray()
    for row in data:
        compressed.extend(compressor.compress(b"\0" + row.tobytes()))
    compressed.extend(compressor.flush())
    header = struct.pack(">IIBBBBB", width, height, bit_depth, color_type, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", bytes(compressed)) + chunk(b"IEND", b""))


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")


def object_color(value):
    """Object display RGB is linear; isolated-layer colors are display sRGB."""
    rgb = np.clip(np.asarray(value[:3], dtype=np.float64), 0, 1)
    rgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * rgb ** (1 / 2.4) - 0.055)
    return np.rint(rgb * 255).astype(np.uint8)


def palette_color(identifier):
    # Odd multiplication is a bijection on 24 bits; zero remains background only.
    color = (identifier * 0x9E3779) & 0xFFFFFF
    return [color & 255, (color >> 8) & 255, (color >> 16) & 255]


def frame_geometry(scene, camera):
    if camera is None or camera.data.type != "ORTHO":
        raise RuntimeError("Guides require the current orthographic camera")
    if scene.render.use_border:
        raise RuntimeError("Disable render border before exporting aligned full-frame guides")
    width = max(1, int(scene.render.resolution_x * scene.render.resolution_percentage / 100))
    height = max(1, int(scene.render.resolution_y * scene.render.resolution_percentage / 100))
    if width * height > 4096 * 4096:
        raise RuntimeError("Guide frame exceeds 16 megapixels; choose a smaller render resolution")
    corners = camera.data.view_frame(scene=scene)
    bounds = (min(v.x for v in corners), max(v.x for v in corners),
              min(v.y for v in corners), max(v.y for v in corners))
    if bounds[1] <= bounds[0] or bounds[3] <= bounds[2]:
        raise RuntimeError("Degenerate orthographic camera frame")
    view = camera.matrix_world.normalized().inverted()
    return width, height, bounds, view


def collect_triangles(scene, camera, collection, depsgraph, width, height, bounds, view):
    """Use evaluated meshes, always releasing their temporary to_mesh result."""
    objects = sorted((obj for obj in collection.all_objects
                      if obj.type == "MESH" and not obj.hide_render), key=lambda obj: obj.name)
    if not objects:
        raise RuntimeError("No renderable meshes in the workshop collection")
    originals = {obj.as_pointer() for obj in collection.all_objects}
    for instance in depsgraph.object_instances:
        if instance.is_instance and instance.parent is not None:
            if instance.parent.original.as_pointer() in originals:
                raise RuntimeError("Instanced geometry is not supported by this explicit mesh guide export")
    unsupported = [obj.name for obj in collection.all_objects
                   if obj.type in {"CURVE", "SURFACE", "FONT", "META", "VOLUME"} and not obj.hide_render]
    if unsupported:
        raise RuntimeError("Convert drawable non-mesh objects before export: " + ", ".join(unsupported))
    x_min, x_max, y_min, y_max = bounds
    records, triangles, normals, object_ids, groups = [], [], [], [], {}
    projection_error = 0.0
    for identifier, obj in enumerate(objects, 1):
        group = str(obj.get("layer", "ungrouped"))
        if not re.fullmatch(r"[a-z][a-z0-9_]*", group):
            raise RuntimeError("Unsafe layer name on " + obj.name + ": " + group)
        if obj.name not in bpy.context.view_layer.objects:
            raise RuntimeError("Mesh is excluded from the current evaluated view layer: " + obj.name)
        evaluated = obj.evaluated_get(depsgraph)
        mesh = None
        first_triangle = len(triangles)
        try:
            mesh = evaluated.to_mesh()
            if mesh is None:
                raise RuntimeError("Unable to evaluate mesh: " + obj.name)
            mesh.calc_loop_triangles()
            vertices = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
            mesh.vertices.foreach_get("co", vertices)
            vertices = vertices.reshape((-1, 3))
            transform = np.asarray(view @ evaluated.matrix_world, dtype=np.float64)
            camera_vertices = vertices @ transform[:3, :3].T + transform[:3, 3]
            projected = np.empty_like(camera_vertices)
            projected[:, 0] = (camera_vertices[:, 0] - x_min) / (x_max - x_min) * width
            projected[:, 1] = (y_max - camera_vertices[:, 1]) / (y_max - y_min) * height
            projected[:, 2] = -camera_vertices[:, 2]
            # Cross-check against Blender's own projection helper, including camera shift.
            for vertex_index in range(min(3, len(vertices))):
                world_point = evaluated.matrix_world @ Vector(vertices[vertex_index].tolist())
                expected = world_to_camera_view(scene, camera, world_point)
                actual = projected[vertex_index]
                error = max(abs(actual[0] / width - expected.x),
                            abs(actual[1] / height - (1 - expected.y)))
                projection_error = max(projection_error, float(error))
            for triangle in mesh.loop_triangles:
                indexes = list(triangle.vertices)
                positions = camera_vertices[indexes]
                normal = np.cross(positions[1] - positions[0], positions[2] - positions[0])
                length = float(np.linalg.norm(normal))
                if length < 1e-12:
                    continue
                # Winding normals are deliberate; no face-forward or smooth-normal invention.
                normals.append(normal / length)
                triangles.append(projected[indexes])
                object_ids.append(identifier)
                groups.setdefault(group, []).append(len(triangles) - 1)
        finally:
            if mesh is not None:
                evaluated.to_mesh_clear()
        records.append({"id": identifier, "object": obj.name, "layer": group,
                        "rgb": palette_color(identifier),
                        "display_rgb": object_color(obj.color).tolist(),
                        "triangles": len(triangles) - first_triangle})
    if projection_error > 1e-5:
        raise RuntimeError("Camera projection mismatch: " + str(projection_error))
    if not triangles:
        raise RuntimeError("No evaluated triangles to export")
    return (np.asarray(triangles), np.asarray(normals), np.asarray(object_ids, dtype=np.int32),
            records, groups, projection_error)


def rasterize(triangles, indexes, width, height, near, far):
    """Exact orthographic barycentric depth at pixel centers; no antialiasing."""
    depth = np.full((height, width), np.inf, dtype=np.float32)
    hits = np.zeros((height, width), dtype=np.int32)
    for index in indexes:
        triangle = triangles[index]
        if triangle[:, 2].max() < near or triangle[:, 2].min() > far:
            continue
        x0 = max(0, math.ceil(float(triangle[:, 0].min()) - 0.5))
        x1 = min(width - 1, math.floor(float(triangle[:, 0].max()) - 0.5))
        y0 = max(0, math.ceil(float(triangle[:, 1].min()) - 0.5))
        y1 = min(height - 1, math.floor(float(triangle[:, 1].max()) - 0.5))
        if x1 < x0 or y1 < y0:
            continue
        a, b, c = triangle
        denominator = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(denominator) < 1e-10:
            continue
        x = np.arange(x0, x1 + 1, dtype=np.float64)[None, :] + 0.5
        y = np.arange(y0, y1 + 1, dtype=np.float64)[:, None] + 0.5
        wa = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / denominator
        wb = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / denominator
        wc = 1.0 - wa - wb
        candidate = wa * a[2] + wb * b[2] + wc * c[2]
        target = depth[y0:y1 + 1, x0:x1 + 1]
        inside = ((wa >= -1e-8) & (wb >= -1e-8) & (wc >= -1e-8)
                  & (candidate >= near) & (candidate <= far)
                  & (candidate < target - 1e-6))
        target[inside] = candidate[inside]
        hit_target = hits[y0:y1 + 1, x0:x1 + 1]
        hit_target[inside] = index + 1
    return depth, hits


def install(staging, names):
    """Install metadata last; restore previous guides if any replacement fails."""
    backups, installed = {}, []
    try:
        for name in names:
            target = OUT / name
            if not target.resolve().is_relative_to(OUT.resolve()):
                raise RuntimeError("Guide path escapes output directory")
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                if not target.is_file():
                    raise RuntimeError("Guide destination is not a file: " + str(target))
                backup = staging / "previous" / name
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(target, backup)
                backups[name] = backup
            else:
                backups[name] = None
        for name in names:
            os.replace(staging / "next" / name, OUT / name)
            installed.append(name)
    except Exception:
        errors = []
        for name in reversed(installed):
            try:
                if backups[name] is None:
                    (OUT / name).unlink(missing_ok=True)
                else:
                    os.replace(backups[name], OUT / name)
            except OSError as error:
                errors.append(str(error))
        if errors:
            raise RuntimeError("Guide rollback incomplete; backups retained in " + str(staging)
                               + ": " + "; ".join(errors))
        raise


def main():
    global OUT, COLLECTION
    started = time.monotonic()
    scene = bpy.context.scene
    if scene.get("halt_lab_id") != "dungeon_draft_halt_scale_lab_v1":
        raise RuntimeError("This exporter only accepts the isolated halt lab")
    if not bpy.data.filepath or not (ROOT / "project.godot").is_file():
        raise RuntimeError("Expected the saved lab file below the Godot workspace")
    OUT, collection, required_groups = export_configuration(scene)
    COLLECTION = collection.name
    depsgraph = bpy.context.evaluated_depsgraph_get()
    if scene.camera is None:
        raise RuntimeError("No active scene camera")
    camera = scene.camera.evaluated_get(depsgraph)
    width, height, bounds, view = frame_geometry(scene, camera)
    triangles, normals, owners, objects, groups, error = collect_triangles(
        scene, camera, collection, depsgraph, width, height, bounds, view)
    if not required_groups.issubset(groups):
        raise RuntimeError("Required layers missing from " + COLLECTION + ": "
                           + ", ".join(sorted(required_groups - groups.keys())))
    near, far = float(camera.data.clip_start), float(camera.data.clip_end)
    depth, hits = rasterize(triangles, range(len(triangles)), width, height, near, far)
    valid = hits != 0
    if not valid.any():
        raise RuntimeError("No visible geometry inside the current camera clipping range")
    meter_scale = float(scene.unit_settings.scale_length)
    if not math.isfinite(meter_scale) or meter_scale <= 0:
        raise RuntimeError("Invalid scene unit scale")
    depth *= meter_scale
    minimum, maximum = float(depth[valid].min()), float(depth[valid].max())
    span = max(maximum - minimum, 1e-9)
    encoded_depth = np.zeros((height, width), dtype=np.uint16)
    encoded_depth[valid] = np.rint(65535 - (depth[valid] - minimum) / span * 65534).astype(np.uint16)
    owner_lookup = np.concatenate((np.zeros(1, dtype=np.int32), owners))
    visible_owners = owner_lookup[hits]
    color_lookup = np.asarray([[0, 0, 0]] + [record["rgb"] for record in objects], dtype=np.uint8)
    display_lookup = np.asarray([[0, 0, 0]] + [record["display_rgb"] for record in objects], dtype=np.uint8)
    normal_lookup = np.zeros((len(normals) + 1, 4), dtype=np.uint8)
    normal_lookup[1:, :3] = np.rint((np.clip(normals, -1, 1) * 0.5 + 0.5) * 255).astype(np.uint8)
    normal_lookup[1:, 3] = 255
    OUT.mkdir(parents=True, exist_ok=True)
    staging = OUT / (".guides-" + uuid.uuid4().hex)
    (staging / "next").mkdir(parents=True)
    exported, group_reports = [], []
    keep_staging = False

    def write(name, payload):
        target = staging / "next" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        exported.append({"path": name, "sha256": hashlib.sha256(payload).hexdigest(), "bytes": len(payload)})

    try:
        write("depth.png", png_bytes(encoded_depth))
        raw_depth = depth.copy()
        raw_depth[~valid] = np.nan
        buffer = io.BytesIO()
        np.save(buffer, raw_depth, allow_pickle=False)
        write("depth_metres.npy", buffer.getvalue())
        write("normals.png", png_bytes(normal_lookup[hits]))
        write("object_ids.png", png_bytes(color_lookup[visible_owners]))
        write("coverage.png", png_bytes(valid.astype(np.uint8) * 255))
        write("object_palette.json", json_bytes({"background": [0, 0, 0], "objects": objects}))
        for group, indexes in sorted(groups.items()):
            _, isolated_hits = rasterize(triangles, indexes, width, height, near, far)
            isolated = isolated_hits != 0
            group_ids = [record["id"] for record in objects if record["layer"] == group]
            visible = np.isin(visible_owners, group_ids)
            if group in required_groups and not visible.any():
                raise RuntimeError("Required layer is not visible in this camera: " + group)
            rgba = np.zeros((height, width, 4), dtype=np.uint8)
            rgba[:, :, :3] = display_lookup[owner_lookup[isolated_hits]]
            rgba[:, :, 3] = isolated.astype(np.uint8) * 255
            write("layers/" + group + ".png", png_bytes(rgba))
            write("masks/" + group + "_visible.png", png_bytes(visible.astype(np.uint8) * 255))
            group_reports.append({"layer": group, "object_ids": group_ids,
                                  "isolated_pixels": int(isolated.sum()), "visible_pixels": int(visible.sum())})
        readme = f"""# Guides géométriques de la halte

Ces fichiers proviennent des triangles évalués de la collection {COLLECTION},
projetés avec la caméra orthographique actuelle. Ils ne sont pas déduits de l’illustration.
Toutes les images ont la résolution du rendu courant, origine en haut à gauche.
Échantillonnage au centre du pixel, sans antialiasing ni transformation colorimétrique.

- depth.png : vrai Z caméra en PNG gris 16 bits, proche blanc, loin sombre, fond 0.
  Pour v>0 : mètres = depth_min_m + (65535-v)/65534 × depth_span_m (guides.json).
  depth_metres.npy garde directement les float32 métriques, fond NaN.
- normals.png : RGBA8, RGB = 0.5 × normale + 0.5, alpha=présence de géométrie.
  Repère caméra : +X droite, +Y haut, +Z vers la caméra ; normales géométriques
  des triangles, sans lissage ni retournement des faces arrière.
- object_ids.png : identifiants RGB8 exacts ; palette dans object_palette.json.
  Charger comme données sans filtrage/colorimétrie pour retrouver les identifiants.
- coverage.png : masque visible de toute la géométrie.
- layers/<groupe>.png : groupe isolé avec alpha binaire, autres groupes retirés,
  couleur d’objet sans éclairage convertie en sRGB. Ce sont des guides de découpe,
  pas des calques de l’illustration finale ni le rendu Workbench éclairé.
- masks/<groupe>_visible.png : portion réellement visible dans la scène complète.

Les surfaces cachées dans un groupe restent cachées par ce groupe. Les modificateurs
sont ceux du graphe évalué de la vue courante ; instances/non-mesh sont refusés.
Les contours peuvent différer du rendu Workbench antialiasé d’environ un pixel.
Le script ne modifie aucun objet, réglage, matériau ou image Blender et n’enregistre
pas le .blend. Les maillages temporaires sont libérés même en cas d’erreur.
guides.json est installé en dernier et porte les empreintes du jeu de fichiers.
"""
        write("GUIDES.md", readme.encode("utf-8"))
        metadata = {"schema_version": 1, "collection": COLLECTION, "resolution": [width, height],
                    "source_blend": str(Path(bpy.data.filepath).resolve()),
                    "source_blend_sha256": hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),
                    "evaluated_scene_may_be_unsaved": bool(bpy.data.is_dirty),
                    "frame": scene.frame_current, "camera": camera.name,
                    "camera_matrix_world": [list(row) for row in camera.matrix_world],
                    "camera_frame_bounds": list(bounds), "clip_scene_units": [near, far],
                    "unit_scale_metres": meter_scale, "pixel_aspect": [scene.render.pixel_aspect_x, scene.render.pixel_aspect_y],
                    "projection_error_normalized": error, "projection": "ORTHO_pixel_centers_no_AA",
                    "depth_min_m": minimum, "depth_max_m": maximum, "depth_span_m": span,
                    "depth_png_bits": 16, "depth_background": 0, "depth_near": 65535,
                    "normal_space": "camera +X right +Y up +Z toward camera; geometric winding normals",
                    "projected_triangles_sha256": hashlib.sha256(triangles.astype("<f8").tobytes()).hexdigest(),
                    "objects": len(objects), "triangles": len(triangles), "visible_pixels": int(valid.sum()),
                    "groups": group_reports, "files": list(exported),
                    "elapsed_seconds": round(time.monotonic() - started, 3)}
        write("guides.json", json_bytes(metadata))
        try:
            install(staging, [item["path"] for item in exported])
        except RuntimeError as failure:
            keep_staging = "rollback incomplete" in str(failure)
            raise
    finally:
        if not keep_staging and staging.exists():
            if staging.resolve().parent != OUT.resolve() or not re.fullmatch(r"\.guides-[0-9a-f]{32}", staging.name):
                raise RuntimeError("Refusing unexpected staging cleanup path")
            shutil.rmtree(staging)
    print(json.dumps({"passed": True, "guides": str(OUT / "guides.json"),
                      "resolution": [width, height], "objects": len(objects),
                      "triangles": len(triangles), "groups": group_reports,
                      "elapsed_seconds": round(time.monotonic() - started, 3)}))


main()
