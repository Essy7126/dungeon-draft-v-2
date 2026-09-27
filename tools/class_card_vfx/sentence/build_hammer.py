"""Editable original cel hammer. Safe in live Blender: creates its own scene.

Run with Blender's Python; never clears the user's scene or registers handlers.
The model is built from authored polygonal parts, with baked transform keys.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "art/source/vfx/sentence_rempart"
RENDERS = ROOT / "artifacts/dev/class_card_vfx/sentence/hammer"
SCENE_NAME = "Sentence du rempart - CEL"
FPS, FRAMES, SIZE, CONTACT_FRAME = 30, 48, 384, 16
PALETTE = [
    ("Ink", "151d2c"), ("Bronze shadow", "652b1e"),
    ("Bronze", "b86625"), ("Gold", "f2a332"),
    ("Edge light", "fff0bf"), ("Obsidian", "203444"),
    ("Obsidian light", "4c7180"), ("Seal", "139f9b"),
    ("Seal light", "94f0db"),
]


def color(value):
    rgb = [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb) + (1,)


def material(name, value):
    mat = bpy.data.materials.new("Sentence_" + name)
    mat.diffuse_color = color(value)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs[0].default_value = color(value)
    emission.inputs[1].default_value = 1
    output = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(emission.outputs[0], output.inputs[0])
    return mat


def build():
    if bpy.data.scenes.get(SCENE_NAME):
        raise RuntimeError("The dedicated scene already exists; preserve it and edit explicitly.")
    original_scene = bpy.context.scene
    scene = bpy.data.scenes.new(SCENE_NAME)
    scene.render.engine = original_scene.render.engine
    bpy.context.window.scene = scene
    mats = [material(n, c) for n, c in PALETTE]
    rig = bpy.data.objects.new("Sentence - animated hammer", None)
    scene.collection.objects.link(rig)
    rig.rotation_mode = "XYZ"

    def mesh(name, verts, faces, indexes, parent=rig):
        data = bpy.data.meshes.new(name)
        data.from_pydata(verts, [], faces)
        data.update()
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.parent = parent
        for mat in mats:
            data.materials.append(mat)
        for face, index in zip(data.polygons, indexes):
            face.material_index = index
        return obj

    def block(name, center, dims, bevel=.06, palette=(1, 2, 3, 4)):
        x, y, z = center
        a, b, c = (v / 2 for v in dims)
        bevel = min(bevel, a * .35, b * .35, c * .35)
        verts = []
        for dz, shrink in [(-c, bevel), (-c + bevel, 0), (c - bevel, 0), (c, bevel)]:
            ax, by = a - shrink, b - shrink
            cut = bevel
            verts += [(x + px, y + py, z + dz) for px, py in [
                (-ax + cut, -by), (ax - cut, -by), (ax, -by + cut),
                (ax, by - cut), (ax - cut, by), (-ax + cut, by),
                (-ax, by - cut), (-ax, -by + cut),
            ]]
        faces, indexes = [tuple(reversed(range(8)))], [palette[0]]
        for level in range(3):
            for side in range(8):
                a0, b0 = level * 8 + side, level * 8 + (side + 1) % 8
                faces.append((a0, b0, b0 + 8, a0 + 8))
                indexes.append(palette[3] if level == 2 else palette[0] if level == 0 else palette[(side // 2) % 3])
        faces.append(tuple(range(24, 32)))
        indexes.append(palette[2])
        return mesh(name, verts, faces, indexes)

    # Heavy striking head; dark rims separate the silhouette from bright effects.
    block("Head - silhouette rim", (0, 0, 0), (1.96, .99, .89), .14, (0, 0, 0, 0))
    block("Head - bronze body", (0, -.015, .015), (1.88, 1.02, .79), .13)
    block("Left striking cheek", (-.84, 0, .015), (.31, 1.08, .86), .065, (1, 2, 3, 4))
    block("Right striking cheek", (.84, 0, .015), (.31, 1.08, .86), .065, (1, 2, 3, 4))
    block("Striking sole", (0, 0, -.405), (1.81, .90, .10), .025, (0, 1, 2, 3))
    for x in [-.55, .55]:
        block("Head reinforcement", (x, -.005, .015), (.13, 1.07, .84), .025, (1, 3, 3, 4))
    block("Socket", (0, 0, .57), (.57, .57, .39), .06)
    block("Handle - dark contour", (0, 0, 1.32), (.28, .31, 1.47), .055, (0, 0, 0, 0))
    block("Handle - basalt", (0, -.02, 1.34), (.23, .28, 1.43), .045, (5, 5, 6, 6))
    for z in [.86, 1.12, 1.38, 1.64]:
        block("Grip band", (0, 0, z), (.33, .35, .075), .022, (1, 2, 3, 4))
    block("Pommel", (0, 0, 2.04), (.48, .47, .26), .085)
    block("Pommel cap", (0, 0, 2.19), (.27, .27, .08), .025, (1, 3, 4, 4))
    # Original shield crest, carved in the front plate (no borrowed iconography).
    outline = [(-.35, .23), (.35, .23), (.30, -.11), (0, -.33), (-.30, -.11)]
    mesh("Crest - inset", [(x, -.551, z + .06) for x, z in outline], [tuple(range(5))], [0])
    mesh("Crest - gold bevel", [(x * .82, -.555, z * .82 + .06) for x, z in outline], [tuple(range(5))], [4])
    mesh("Crest - enamel", [(x * .62, -.558, z * .62 + .06) for x, z in outline], [tuple(range(5))], [7])
    mesh("Crest - split light", [(0, -.561, .19), (.17, -.561, .19), (.13, -.561, -.01), (0, -.561, -.10)], [(0, 1, 2, 3)], [8])
    for x in [-.75, .75]:
        for z in [-.22, .23]:
            block("Bronze rivet", (x, -.563, z), (.075, .045, .075), .012, (1, 3, 4, 4))

    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 1, FRAMES
    # Color management is copied from the live scene; no version-specific enum guessed.
    scene.view_settings.view_transform = original_scene.view_settings.view_transform
    scene.view_settings.look = original_scene.view_settings.look
    scene.view_settings.exposure = original_scene.view_settings.exposure
    camera = bpy.data.objects.new("Sentence - orthographic camera", bpy.data.cameras.new("Sentence camera"))
    scene.collection.objects.link(camera)
    target = Vector((0, 0, 1.90))
    camera.location = target + Vector((3.8, -10, 6.0))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 6.4
    scene.camera = camera

    # Times expressed in frames so the contact has an exact export index.
    keys = [
        (1, (-.72, 0, 2.30), (-8, -31, -7), .08),
        (4, (-.74, 0, 2.33), (-8, -29, -7), .77),
        (8, (-.91, .05, 2.40), (-6, -22, -4), 1.0),
        (11, (-1.03, .07, 2.52), (-4, -12, 0), 1.0),
        (12, (-1.01, .06, 2.51), (-4, -12, 0), 1.0),
        (14, (-.63, .04, 2.15), (-3, -18, 3), 1.0),
        (15, (-.22, .02, 1.52), (-2, -23, 5), 1.0),
        (16, (.04, 0, .88), (0, -28, 6), 1.0),
        (18, (.04, 0, .88), (0, -28, 6), 1.0),
        (21, (-.01, 0, 1.02), (0, -31, 5), 1.0),
        (26, (.04, 0, .89), (0, -28, 6), 1.0),
        (29, (.04, 0, .89), (0, -28, 6), 1.0),
        (36, (.04, 0, .97), (0, -28, 6), .87),
        (43, (.04, 0, 1.13), (0, -28, 6), .23),
        (48, (.04, 0, 1.16), (0, -28, 6), .001),
    ]
    for frame in range(1, FRAMES + 1):
        left, right = keys[0], keys[-1]
        for k in range(len(keys) - 1):
            if keys[k][0] <= frame <= keys[k + 1][0]:
                left, right = keys[k], keys[k + 1]
                break
        u = (frame - left[0]) / max(1, right[0] - left[0])
        if frame < 12 or frame > 18:
            u = u * u * (3 - 2 * u)
        rig.location = Vector(left[1]).lerp(Vector(right[1]), u)
        rig.rotation_euler = [math.radians(a + (b - a) * u) for a, b in zip(left[2], right[2])]
        factor = left[3] + (right[3] - left[3]) * u
        rig.scale = (factor, factor, factor * (.91 if frame in (16, 17) else 1))
        for path in ["location", "rotation_euler", "scale"]:
            rig.keyframe_insert(data_path=path, frame=frame)
    rig["contact_frame"] = CONTACT_FRAME
    rig["intent"] = "Arming, accelerating bronze strike, contact hold, heavy rebound, withdrawal."
    for frame, name in [(1, "APPEAR"), (11, "ARMED"), (16, "CONTACT"), (21, "REBOUND"), (29, "WITHDRAW"), (48, "CLEAR")]:
        scene.timeline_markers.new(name, frame=frame)
    scene.frame_set(11)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_perspective = "CAMERA"
    SOURCE.mkdir(parents=True, exist_ok=True)
    RENDERS.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(RENDERS / "frame_")
    bpy.context.view_layer.update()
    pivot = world_to_camera_view(scene, camera, Vector((0, 0, 0)))
    meta = {
        "version": 1, "authoring": "Original polygonal model and authored animation, Blender Python",
        "blender_version": bpy.app.version_string, "scene": scene.name,
        "fps": FPS, "frames": FRAMES, "size": SIZE, "contact_frame": CONTACT_FRAME,
        "contact_seconds": (CONTACT_FRAME - 1) / FPS,
        "pivot_pixels": [round(pivot.x * SIZE, 4), round((1 - pivot.y) * SIZE, 4)],
        "source_script": "tools/class_card_vfx/sentence/build_hammer.py",
        "palette_revision": "bronze-contact-02",
        "palette_srgb": dict(PALETTE),
        "view_transform": scene.view_settings.view_transform,
        "look": scene.view_settings.look,
    }
    (SOURCE / "manifest.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "sentence_rempart.blend"))
    print(json.dumps(meta))


if __name__ == "__main__":
    build()
