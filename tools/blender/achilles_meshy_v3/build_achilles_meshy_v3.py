"""Build and validate the direct Meshy Achilles V3 animation pool.

This script is designed for Blender 5.1+ in background mode.  It imports the
immutable Meshy merged-animation GLB, validates that all actions target the
same 24-bone rig, removes every non-character scene object in memory, exports
only the skinned character, then re-imports the result for structural QA.

No .blend file is saved and the source file is never modified.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
import sys
from pathlib import Path

import bpy


SCRIPT_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SCRIPT_DIR.parents[2]

DEFAULT_SOURCE = Path(
    r"C:\Users\paolo\Downloads\Meshy_AI_Meshy_Merged_Animations (4).glb"
)
DEFAULT_OUTPUT = (
    REPOSITORY_ROOT
    / "assets"
    / "characters"
    / "Achilles"
    / "3d"
    / "achilles_meshy_animation_pool_v3.glb"
)
DEFAULT_MANIFEST = DEFAULT_OUTPUT.with_name(
    "achilles_meshy_animation_pool_v3_manifest.json"
)
DEFAULT_INSPECTION = DEFAULT_OUTPUT.with_name(
    "achilles_meshy_animation_pool_v3_inspection.json"
)

SOURCE_SHA256 = (
    "21DAD4EE17146F3A1430A684C7EFD14544701100307C233D4E5B27812EF58770"
)
EXPECTED_SOURCE_BYTES = 9_191_236
EXPECTED_ARMATURE_OBJECT = "Armature"
EXPECTED_MESH_OBJECT = "char1"
EXPECTED_TEXTURE_SIZE = [2048, 2048]

EXPECTED_BONES = [
    "Hips",
    "LeftUpLeg",
    "LeftLeg",
    "LeftFoot",
    "LeftToeBase",
    "RightUpLeg",
    "RightLeg",
    "RightFoot",
    "RightToeBase",
    "Spine02",
    "Spine01",
    "Spine",
    "LeftShoulder",
    "LeftArm",
    "LeftForeArm",
    "LeftHand",
    "RightShoulder",
    "RightArm",
    "RightForeArm",
    "RightHand",
    "neck",
    "Head",
    "head_end",
    "headfront",
]

EXPECTED_ACTIONS = [
    "Alert",
    "Archery_Shot_3",
    "Basic_Jump",
    "Charged_Spell_Cast",
    "Charged_Upward_Slash",
    "Chest_Pound_Taunt",
    "Double_Combo_Attack",
    "Draw_and_Shoot_from_Back_2",
    "Electrocution_Reaction",
    "Hit_Reaction_1",
    "Idle_11",
    "Left_Slash",
    "mage_soell_cast_7",
    "run_fast_3_inplace",
    "Running",
    "Simple_Kick",
    "Sword_Judgment",
    "Sword_Parry_Backward_2",
    "Triple_Combo_Attack",
    "Walking",
]

LOOP_ACTIONS = {
    "Alert",
    "Idle_11",
    "run_fast_3_inplace",
    "Running",
    "Walking",
}

ROOT_HEAVY_ACTIONS = {
    "Basic_Jump",
    "Double_Combo_Attack",
    "Simple_Kick",
    "Sword_Judgment",
    "Sword_Parry_Backward_2",
    "Triple_Combo_Attack",
}

ROLE_BY_ACTION = {
    "Alert": "alert",
    "Archery_Shot_3": "ranged_release",
    "Basic_Jump": "jump",
    "Charged_Spell_Cast": "charged_spell",
    "Charged_Upward_Slash": "heavy_attack",
    "Chest_Pound_Taunt": "taunt_buff",
    "Double_Combo_Attack": "combo_two",
    "Draw_and_Shoot_from_Back_2": "bow_draw_release",
    "Electrocution_Reaction": "status_reaction",
    "Hit_Reaction_1": "hit",
    "Idle_11": "idle",
    "Left_Slash": "slash",
    "mage_soell_cast_7": "spell_cast",
    "run_fast_3_inplace": "run_fast",
    "Running": "alternate_run",
    "Simple_Kick": "kick",
    "Sword_Judgment": "ultimate",
    "Sword_Parry_Backward_2": "guard_parry",
    "Triple_Combo_Attack": "combo_three",
    "Walking": "walk",
}

POSE_CURVE_PATTERN = re.compile(
    r'^pose\.bones\["((?:\\.|[^"\\])*)"\]\.([A-Za-z_][A-Za-z0-9_]*)$'
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def parse_arguments() -> argparse.Namespace:
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--inspection", type=Path, default=DEFAULT_INSPECTION)
    return parser.parse_args(arguments)


def iter_action_fcurves(action: bpy.types.Action):
    found_layered = False
    if hasattr(action, "layers"):
        for layer in action.layers:
            for strip in layer.strips:
                if not hasattr(strip, "channelbags"):
                    continue
                for channelbag in strip.channelbags:
                    found_layered = True
                    yield from channelbag.fcurves
    if not found_layered and hasattr(action, "fcurves"):
        yield from action.fcurves


def decode_bone_name(raw_name: str) -> str:
    try:
        return json.loads('"' + raw_name + '"')
    except Exception:
        return raw_name


def action_audit(action: bpy.types.Action, bone_names: set[str], fps: float) -> dict:
    curves = list(iter_action_fcurves(action))
    referenced_bones: set[str] = set()
    properties_by_bone: dict[str, set[str]] = {}
    direct_paths: set[str] = set()
    keyframe_count = 0

    for curve in curves:
        keyframe_count += len(curve.keyframe_points)
        match = POSE_CURVE_PATTERN.match(curve.data_path)
        if match is None:
            direct_paths.add(curve.data_path)
            continue
        bone_name = decode_bone_name(match.group(1))
        property_name = match.group(2)
        referenced_bones.add(bone_name)
        properties_by_bone.setdefault(bone_name, set()).add(property_name)

        for keyframe in curve.keyframe_points:
            require(
                all(math.isfinite(float(value)) for value in keyframe.co),
                f"Valeur non finie dans {action.name}: {curve.data_path}",
            )

    first_frame = float(action.frame_range[0])
    last_frame = float(action.frame_range[1])
    hips_delta = [0.0, 0.0, 0.0]
    for curve in curves:
        if curve.data_path != 'pose.bones["Hips"].location':
            continue
        if 0 <= curve.array_index < 3:
            hips_delta[curve.array_index] = float(curve.evaluate(last_frame)) - float(
                curve.evaluate(first_frame)
            )

    expected_properties = {"location", "rotation_quaternion", "scale"}
    property_contract_ok = all(
        properties_by_bone.get(bone_name, set()) == expected_properties
        for bone_name in bone_names
    )

    return {
        "name": action.name,
        "frame_range": [round(first_frame, 6), round(last_frame, 6)],
        "duration_seconds": round((last_frame - first_frame) / fps, 6),
        "fcurve_count": len(curves),
        "keyframe_count": keyframe_count,
        "animated_bone_count": len(referenced_bones),
        "missing_bones": sorted(referenced_bones - bone_names),
        "unanimated_bones": sorted(bone_names - referenced_bones),
        "direct_paths": sorted(direct_paths),
        "location_quaternion_scale_on_every_bone": property_contract_ok,
        "hips_location_delta_raw": [round(value, 7) for value in hips_delta],
        "hips_location_delta_raw_length": round(
            math.sqrt(sum(value * value for value in hips_delta)), 7
        ),
        "loop_candidate": action.name in LOOP_ACTIONS,
        "root_motion_review_required": action.name in ROOT_HEAVY_ACTIONS,
        "role": ROLE_BY_ACTION[action.name],
    }


def is_blender_import_helper(obj: bpy.types.Object) -> bool:
    return any(collection.name == "glTF_not_exported" for collection in obj.users_collection)


def audit_character(label: str) -> dict:
    import_helpers = [obj for obj in bpy.data.objects if is_blender_import_helper(obj)]
    character_objects = [obj for obj in bpy.data.objects if obj not in import_helpers]
    armature_objects = [obj for obj in character_objects if obj.type == "ARMATURE"]
    mesh_objects = [obj for obj in character_objects if obj.type == "MESH"]
    camera_objects = [obj for obj in character_objects if obj.type == "CAMERA"]
    light_objects = [obj for obj in character_objects if obj.type == "LIGHT"]

    require(len(armature_objects) == 1, f"{label}: nombre d'armatures inattendu")
    require(len(mesh_objects) == 1, f"{label}: nombre de meshes inattendu")
    require(not camera_objects, f"{label}: caméra exportée par erreur")
    require(not light_objects, f"{label}: lumière exportée par erreur")

    rig = armature_objects[0]
    mesh = mesh_objects[0]
    require(rig.name == EXPECTED_ARMATURE_OBJECT, f"{label}: rig inattendu {rig.name}")
    require(mesh.name == EXPECTED_MESH_OBJECT, f"{label}: mesh inattendu {mesh.name}")
    require(mesh.parent is rig, f"{label}: le mesh n'est pas enfant du rig")

    armature_modifiers = [modifier for modifier in mesh.modifiers if modifier.type == "ARMATURE"]
    require(
        len(armature_modifiers) == 1 and armature_modifiers[0].object is rig,
        f"{label}: modificateur d'armature invalide",
    )

    bone_names = [bone.name for bone in rig.data.bones]
    require(bone_names == EXPECTED_BONES, f"{label}: ordre ou noms d'os inattendus")
    skeleton_json = json.dumps(bone_names, separators=(",", ":"))
    skeleton_signature = hashlib.sha256(skeleton_json.encode("utf-8")).hexdigest().upper()

    action_names = sorted(action.name for action in bpy.data.actions)
    require(action_names == sorted(EXPECTED_ACTIONS), f"{label}: pool d'actions inattendu")
    fps = float(bpy.context.scene.render.fps) / float(
        bpy.context.scene.render.fps_base
    )
    action_rows = [
        action_audit(bpy.data.actions[name], set(bone_names), fps)
        for name in EXPECTED_ACTIONS
    ]
    for action in action_rows:
        require(action["fcurve_count"] == 240, f"{label}: {action['name']} n'a pas 240 courbes")
        require(not action["missing_bones"], f"{label}: os absent dans {action['name']}")
        require(not action["unanimated_bones"], f"{label}: os non animé dans {action['name']}")
        require(not action["direct_paths"], f"{label}: piste non-pose dans {action['name']}")
        require(
            action["location_quaternion_scale_on_every_bone"],
            f"{label}: contrat loc/quat/scale incomplet dans {action['name']}",
        )

    mesh_data = mesh.data
    material_names = [
        material.name if material is not None else None for material in mesh_data.materials
    ]
    require(len(material_names) == 1, f"{label}: nombre de matériaux inattendu")

    texture_images = []
    for material in mesh_data.materials:
        if material is None or material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            if node.type != "TEX_IMAGE" or node.image is None:
                continue
            if node.image.name not in [entry["name"] for entry in texture_images]:
                texture_images.append(
                    {
                        "name": node.image.name,
                        "size": list(node.image.size),
                        "packed": bool(node.image.packed_file),
                        "colorspace": node.image.colorspace_settings.name,
                    }
                )
    require(len(texture_images) == 1, f"{label}: texture unique attendue")
    require(
        texture_images[0]["size"] == EXPECTED_TEXTURE_SIZE,
        f"{label}: taille de texture inattendue",
    )

    return {
        "object_names": sorted(obj.name for obj in character_objects),
        "object_count": len(character_objects),
        "blender_import_helper_objects": sorted(obj.name for obj in import_helpers),
        "armature_object": rig.name,
        "armature_scale": [round(float(value), 6) for value in rig.scale],
        "mesh_object": mesh.name,
        "mesh_parent": mesh.parent.name if mesh.parent else None,
        "mesh_world_dimensions": [round(float(value), 6) for value in mesh.dimensions],
        "mesh": {
            "vertices": len(mesh_data.vertices),
            "edges": len(mesh_data.edges),
            "polygons": len(mesh_data.polygons),
            "loops": len(mesh_data.loops),
            "uv_layers": [layer.name for layer in mesh_data.uv_layers],
            "vertex_groups": [group.name for group in mesh.vertex_groups],
            "materials": material_names,
        },
        "textures": texture_images,
        "bone_count": len(bone_names),
        "bones": bone_names,
        "skeleton_signature_sha256": skeleton_signature,
        "animation_count": len(action_rows),
        "animations": action_rows,
        "fps": fps,
        "camera_count": len(camera_objects),
        "light_count": len(light_objects),
    }


def inspect_raw_glb(path: Path) -> dict:
    with path.open("rb") as handle:
        magic, version, declared_length = struct.unpack("<4sII", handle.read(12))
        require(magic == b"glTF", "GLB V3: en-tête glTF invalide")
        require(version == 2, "GLB V3: version glTF inattendue")
        require(declared_length == path.stat().st_size, "GLB V3: taille déclarée invalide")
        json_length, json_type = struct.unpack("<II", handle.read(8))
        require(json_type == 0x4E4F534A, "GLB V3: chunk JSON absent")
        payload = json.loads(
            handle.read(json_length).decode("utf-8").rstrip("\x00 \t\r\n")
        )

    nodes = payload.get("nodes", [])
    node_names = [node.get("name", "") for node in nodes]
    meshes = payload.get("meshes", [])
    animations = payload.get("animations", [])
    cameras = payload.get("cameras", [])
    skins = payload.get("skins", [])
    lights = (
        payload.get("extensions", {})
        .get("KHR_lights_punctual", {})
        .get("lights", [])
    )

    require(len(meshes) == 1, "GLB V3 brut: un seul mesh attendu")
    require(meshes[0].get("name") == EXPECTED_MESH_OBJECT, "GLB V3 brut: mesh inattendu")
    require(len(skins) == 1, "GLB V3 brut: un seul skin attendu")
    require(len(skins[0].get("joints", [])) == len(EXPECTED_BONES), "GLB V3 brut: skin 24 os attendu")
    require(len(cameras) == 0, "GLB V3 brut: caméra exportée")
    require(len(lights) == 0, "GLB V3 brut: lumière exportée")
    require("Icosphere" not in node_names, "GLB V3 brut: helper Icosphere exporté")
    require("Cube" not in node_names, "GLB V3 brut: helper Cube exporté")
    require(
        sorted(animation.get("name", "") for animation in animations)
        == sorted(EXPECTED_ACTIONS),
        "GLB V3 brut: pool d'animations inattendu",
    )
    expected_nodes = sorted(EXPECTED_BONES + [EXPECTED_MESH_OBJECT, EXPECTED_ARMATURE_OBJECT])
    require(sorted(node_names) == expected_nodes, "GLB V3 brut: nœuds étrangers présents")

    return {
        "declared_bytes": declared_length,
        "scene_count": len(payload.get("scenes", [])),
        "node_count": len(nodes),
        "node_names": node_names,
        "mesh_count": len(meshes),
        "mesh_names": [mesh.get("name", "") for mesh in meshes],
        "skin_count": len(skins),
        "skin_joint_count": len(skins[0].get("joints", [])),
        "animation_count": len(animations),
        "animation_names": [animation.get("name", "") for animation in animations],
        "material_count": len(payload.get("materials", [])),
        "image_count": len(payload.get("images", [])),
        "texture_count": len(payload.get("textures", [])),
        "camera_count": len(cameras),
        "light_count": len(lights),
        "extensions_used": payload.get("extensionsUsed", []),
        "asset": payload.get("asset", {}),
    }


def source_preflight() -> tuple[bpy.types.Object, bpy.types.Object, dict]:
    armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    require(len(armatures) == 1, "Source: une seule armature est attendue")
    rig = armatures[0]
    require(rig.name == EXPECTED_ARMATURE_OBJECT, "Source: objet Armature absent")

    mesh = bpy.data.objects.get(EXPECTED_MESH_OBJECT)
    require(mesh is not None and mesh.type == "MESH", "Source: mesh char1 absent")
    require(mesh.parent is rig, "Source: char1 n'est pas parenté à Armature")

    bone_names = [bone.name for bone in rig.data.bones]
    require(bone_names == EXPECTED_BONES, "Source: squelette Meshy inattendu")
    action_names = sorted(action.name for action in bpy.data.actions)
    require(action_names == sorted(EXPECTED_ACTIONS), "Source: les 20 actions attendues sont absentes")

    fps = float(bpy.context.scene.render.fps) / float(
        bpy.context.scene.render.fps_base
    )
    actions = [
        action_audit(bpy.data.actions[name], set(bone_names), fps)
        for name in EXPECTED_ACTIONS
    ]
    for action in actions:
        require(action["fcurve_count"] == 240, f"Source: {action['name']} n'a pas 240 courbes")
        require(not action["missing_bones"], f"Source: os absent dans {action['name']}")
        require(not action["unanimated_bones"], f"Source: os non animé dans {action['name']}")
        require(not action["direct_paths"], f"Source: piste directe dans {action['name']}")
        require(
            action["location_quaternion_scale_on_every_bone"],
            f"Source: contrat loc/quat/scale incomplet dans {action['name']}",
        )

    audit = {
        "objects": [
            {
                "name": obj.name,
                "type": obj.type,
                "parent": obj.parent.name if obj.parent else None,
            }
            for obj in sorted(bpy.data.objects, key=lambda item: item.name)
        ],
        "animations": actions,
        "bone_count": len(bone_names),
        "bones": bone_names,
        "fps": fps,
    }
    return rig, mesh, audit


def remove_non_character_objects(
    rig: bpy.types.Object, mesh: bpy.types.Object
) -> list[dict]:
    keep = {rig, mesh}
    removed = []
    for obj in sorted(list(bpy.data.objects), key=lambda item: item.name):
        if obj in keep:
            continue
        removed.append({"name": obj.name, "type": obj.type})
        bpy.data.objects.remove(obj, do_unlink=True)

    require(set(bpy.data.objects) == keep, "Nettoyage: objets résiduels inattendus")
    require(
        sorted(entry["name"] for entry in removed)
        == ["Icosphere"],
        f"Nettoyage: liste d'helpers source inattendue: {removed}",
    )
    return removed


def export_glb(output: Path, rig: bpy.types.Object, mesh: bpy.types.Object) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.name in {"achilles_rig_v1.glb", "achilles_rig_animation_pool_v2.glb"}:
        raise RuntimeError("Refus absolu d'écraser un asset Achilles V1/V2")

    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig

    result = bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        use_visible=False,
        use_active_collection=False,
        export_cameras=False,
        export_lights=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_unused_images=False,
        export_texcoords=True,
        export_normals=True,
        export_tangents=False,
        export_yup=True,
        export_apply=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_frame_range=False,
        export_frame_step=1,
        export_force_sampling=False,
        export_optimize_animation_size=False,
        export_optimize_animation_keep_anim_armature=True,
        export_def_bones=False,
        export_leaf_bone=False,
        export_armature_object_remove=False,
        export_skins=True,
        export_all_influences=False,
        export_anim_single_armature=True,
        export_reset_pose_bones=True,
        export_rest_position_armature=True,
        export_current_frame=False,
        export_negative_frame="SLIDE",
        export_anim_slide_to_zero=False,
        export_merge_animation="ACTION",
        export_extra_animations=False,
        export_nla_strips=True,
        export_extras=False,
        export_loglevel=-1,
    )
    require("FINISHED" in result, f"Échec de l'export GLB: {result}")
    require(output.is_file() and output.stat().st_size > 0, "GLB V3 absent après export")


def build_manifest(
    source: Path,
    output: Path,
    verified: dict,
    raw_glb: dict,
    removed: list[dict],
) -> dict:
    clip_rows = []
    for action in verified["animations"]:
        review_status = "POOL_READY_UNASSIGNED"
        if action["name"] in {"Idle_11", "Walking", "run_fast_3_inplace", "Hit_Reaction_1"}:
            review_status = "POOL_READY_ASSIGNED"
        if action["role"] in {
            "ranged_release",
            "bow_draw_release",
            "heavy_attack",
            "slash",
            "ultimate",
            "guard_parry",
            "combo_two",
            "combo_three",
        }:
            review_status = "NEEDS_EQUIPMENT_CONTACT_REVIEW"
        if action["name"] in ROOT_HEAVY_ACTIONS:
            review_status = "NEEDS_ROOT_MOTION_REVIEW"
        clip_rows.append(
            {
                "name": action["name"],
                "duration_seconds": action["duration_seconds"],
                "loop_candidate": action["loop_candidate"],
                "role": action["role"],
                "root_motion_review_required": action[
                    "root_motion_review_required"
                ],
                "review_status": review_status,
            }
        )

    return {
        "schema_version": 1,
        "manifest_id": "achilles_meshy_animation_pool_v3",
        "status": "DIRECT_MESHY_POOL_VALIDATED",
        "generated_date": "2026-08-23",
        "assets": {
            "meshy_animation_source": {
                "filename": source.name,
                "bytes": source.stat().st_size,
                "sha256": file_sha256(source),
                "immutable": True,
                "bundled_in_repository": False,
            },
            "animation_pool_v3": {
                "path": "res://assets/characters/Achilles/3d/achilles_meshy_animation_pool_v3.glb",
                "bytes": output.stat().st_size,
                "sha256": file_sha256(output),
            },
        },
        "model": {
            "source_type": "DIRECT_MESHY_SKIN",
            "retargeted": False,
            "armature_object": verified["armature_object"],
            "mesh_object": verified["mesh_object"],
            "mesh_count": 1,
            "material_count": len(verified["mesh"]["materials"]),
            "texture_count": len(verified["textures"]),
            "texture_size": verified["textures"][0]["size"],
            "vertices": verified["mesh"]["vertices"],
            "polygons": verified["mesh"]["polygons"],
            "uv_layers": verified["mesh"]["uv_layers"],
            "embedded_equipment": False,
        },
        "rig": {
            "bone_count": verified["bone_count"],
            "bones": verified["bones"],
            "hips_bone": "Hips",
            "skeleton_signature_sha256": verified[
                "skeleton_signature_sha256"
            ],
        },
        "animation_counts": {
            "total": verified["animation_count"],
            "direct_meshy": verified["animation_count"],
            "retargeted": 0,
        },
        "clips": clip_rows,
        "recommended_runtime_bindings": {
            "idle": "Idle_11",
            "walk": "Walking",
            "run": "run_fast_3_inplace",
            "alternate_run": "Running",
            "hit": "Hit_Reaction_1",
            "generic_cast": "mage_soell_cast_7",
        },
        "cleanup": {
            "exported_objects": verified["object_names"],
            "removed_source_objects": removed,
            "raw_glb_node_names": raw_glb["node_names"],
            "raw_glb_camera_count": raw_glb["camera_count"],
            "raw_glb_light_count": raw_glb["light_count"],
        },
        "quality": {
            "blender_reimport_status": "PASS",
            "all_actions_share_exact_rig": True,
            "all_actions_finite": True,
            "all_actions_have_24_bone_loc_quat_scale_tracks": True,
            "no_death_clip": True,
            "death_fallback": "ADAPTER_FADE",
            "root_heavy_clips": sorted(ROOT_HEAVY_ACTIONS),
            "equipment_contact_note": (
                "The direct Meshy mesh has no sword, shield or bow; equipment "
                "contacts remain a later socket/equipment pass."
            ),
        },
        "reproduction": {
            "blender_version_validated": bpy.app.version_string,
            "script": "tools/blender/achilles_meshy_v3/build_achilles_meshy_v3.py",
            "source_sha256_required": SOURCE_SHA256,
            "exports_only": [EXPECTED_ARMATURE_OBJECT, EXPECTED_MESH_OBJECT],
            "never_overwrite": [
                "achilles_rig_v1.glb",
                "achilles_rig_animation_pool_v2.glb",
            ],
        },
    }


def main() -> None:
    arguments = parse_arguments()
    source = arguments.source.resolve()
    output = arguments.output.resolve()
    manifest = arguments.manifest.resolve()
    inspection = arguments.inspection.resolve()

    require(source.is_file(), f"Source Meshy absente: {source}")
    require(source != output, "La source Meshy ne peut jamais être la sortie V3")
    require(source.stat().st_size == EXPECTED_SOURCE_BYTES, "Taille source Meshy inattendue")
    require(file_sha256(source) == SOURCE_SHA256, "SHA-256 source Meshy inattendu")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    import_result = bpy.ops.import_scene.gltf(filepath=str(source))
    require("FINISHED" in import_result, f"Échec import source Meshy: {import_result}")

    rig, mesh, source_audit = source_preflight()
    removed_objects = remove_non_character_objects(rig, mesh)
    source_hash_before_export = file_sha256(source)
    export_glb(output, rig, mesh)
    require(
        file_sha256(source) == source_hash_before_export == SOURCE_SHA256,
        "La source immuable a changé pendant l'export",
    )
    raw_glb = inspect_raw_glb(output)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    reimport_result = bpy.ops.import_scene.gltf(filepath=str(output))
    require("FINISHED" in reimport_result, f"Échec réimport V3: {reimport_result}")
    verified = audit_character("V3 réimporté")

    source_animation_by_name = {
        action["name"]: action for action in source_audit["animations"]
    }
    verified_animation_by_name = {
        action["name"]: action for action in verified["animations"]
    }
    for action_name in EXPECTED_ACTIONS:
        source_action = source_animation_by_name[action_name]
        verified_action = verified_animation_by_name[action_name]
        require(
            verified_action["duration_seconds"] == source_action["duration_seconds"],
            f"Durée modifiée après export: {action_name}",
        )
        require(
            verified_action["frame_range"] == source_action["frame_range"],
            f"Plage de frames modifiée après export: {action_name}",
        )
        require(
            verified_action["fcurve_count"] == source_action["fcurve_count"],
            f"Nombre de courbes modifié après export: {action_name}",
        )
        require(
            verified_action["keyframe_count"] == source_action["keyframe_count"],
            f"Nombre de clés modifié après export: {action_name}",
        )

    inspection_payload = {
        "schema_version": 1,
        "inspection_id": "achilles_meshy_animation_pool_v3_reimport",
        "status": "PASS",
        "blender_version": bpy.app.version_string,
        "source": {
            "filename": source.name,
            "bytes": source.stat().st_size,
            "sha256": file_sha256(source),
            "source_scene_objects": source_audit["objects"],
        },
        "output": {
            "path": "res://assets/characters/Achilles/3d/achilles_meshy_animation_pool_v3.glb",
            "bytes": output.stat().st_size,
            "sha256": file_sha256(output),
        },
        "removed_source_objects": removed_objects,
        "raw_glb": raw_glb,
        "reimport": verified,
        "validation": {
            "exactly_one_armature": True,
            "exactly_one_skinned_mesh": True,
            "exactly_one_material": True,
            "exactly_one_embedded_texture": True,
            "exactly_twenty_actions": True,
            "zero_cameras": True,
            "zero_lights": True,
            "zero_helper_meshes": True,
            "source_immutable_hash_preserved": True,
            "durations_preserved": True,
            "frame_ranges_preserved": True,
            "fcurve_counts_preserved": True,
            "keyframe_counts_preserved": True,
            "retarget_used": False,
        },
    }
    manifest_payload = build_manifest(
        source, output, verified, raw_glb, removed_objects
    )
    write_json(inspection, inspection_payload)
    write_json(manifest, manifest_payload)

    print(
        "ACHILLES_MESHY_V3_BUILD_OK "
        + json.dumps(
            {
                "output": str(output),
                "bytes": output.stat().st_size,
                "sha256": file_sha256(output),
                "bone_count": verified["bone_count"],
                "skeleton_signature": verified["skeleton_signature_sha256"],
                "mesh_count": 1,
                "animation_count": verified["animation_count"],
                "removed_objects": [entry["name"] for entry in removed_objects],
                "validation": "PASS",
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
