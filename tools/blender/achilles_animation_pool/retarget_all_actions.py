"""Build an isolated Achilles V2 animation-pool candidate.

Reads the Meshy animation GLB and the immutable Achilles V1 runtime GLB, bakes
all source actions onto a copy of the V1 armature, then writes only below an
explicit output directory. It never saves over either input.

Example (arguments after Blender's ``--`` separator)::

    blender --background --factory-startup --disable-autoexec \
      --python retarget_all_actions.py -- \
      --source "Meshy_Merged_Animations.glb" \
      --canonical "assets/characters/Achilles/3d/achilles_rig_v1.glb" \
      --output-dir "output/achilles_animation_pool_v2"
"""

import argparse
import bpy
import json
import math
import os
import re
import sys
from mathutils import Matrix, Vector


def parse_arguments():
    script_arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="Meshy GLB containing the source actions")
    parser.add_argument("--canonical", required=True, help="immutable Achilles V1 runtime GLB")
    parser.add_argument("--output-dir", required=True, help="distinct directory for generated files")
    return parser.parse_args(script_arguments)


ARGS = parse_arguments()
SOURCE = os.path.abspath(ARGS.source)
CANONICAL = os.path.abspath(ARGS.canonical)
OUT_DIR = os.path.abspath(ARGS.output_dir)
OUT_BLEND = os.path.join(OUT_DIR, "achilles_rig_animation_pool_v2.blend")
OUT_GLB = os.path.join(OUT_DIR, "achilles_rig_animation_pool_v2.glb")
OUT_JSON = os.path.join(OUT_DIR, "retarget_result.json")

if not os.path.isfile(SOURCE) or not os.path.isfile(CANONICAL):
    raise FileNotFoundError("Both --source and --canonical must identify existing GLB files")
if os.path.normcase(SOURCE) == os.path.normcase(CANONICAL):
    raise RuntimeError("Source and canonical inputs must be distinct")
for protected_input in (SOURCE, CANONICAL):
    protected_parent = os.path.dirname(protected_input)
    try:
        common_parent = os.path.commonpath((OUT_DIR, protected_parent))
    except ValueError:
        # Windows raises for paths on different drives. Different drives cannot
        # make the output a descendant of the protected input directory.
        continue
    if os.path.normcase(common_parent) == os.path.normcase(protected_parent):
        raise RuntimeError("--output-dir must not be inside either input directory")

MAPPING = {
    "Hips": "mixamorig:Hips",
    "Spine02": "mixamorig:Spine",
    "Spine01": "mixamorig:Spine1",
    "Spine": "mixamorig:Spine2",
    "neck": "mixamorig:Neck",
    "Head": "mixamorig:Head",
    "LeftShoulder": "mixamorig:LeftShoulder",
    "LeftArm": "mixamorig:LeftArm",
    "LeftForeArm": "mixamorig:LeftForeArm",
    "LeftHand": "mixamorig:LeftHand",
    "RightShoulder": "mixamorig:RightShoulder",
    "RightArm": "mixamorig:RightArm",
    "RightForeArm": "mixamorig:RightForeArm",
    "RightHand": "mixamorig:RightHand",
    "LeftUpLeg": "mixamorig:LeftUpLeg",
    "LeftLeg": "mixamorig:LeftLeg",
    "LeftFoot": "mixamorig:LeftFoot",
    "LeftToeBase": "mixamorig:LeftToeBase",
    "RightUpLeg": "mixamorig:RightUpLeg",
    "RightLeg": "mixamorig:RightLeg",
    "RightFoot": "mixamorig:RightFoot",
    "RightToeBase": "mixamorig:RightToeBase",
}

LOOP_ACTIONS = {"Idle_11", "Walking", "Running", "run_fast_3_inplace", "Alert"}


def find_armature(objects, bone_count):
    matches = [obj for obj in objects if obj.type == "ARMATURE" and len(obj.data.bones) == bone_count]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one {bone_count}-bone armature, found {len(matches)}")
    return matches[0]


def bone_world_matrix(armature, bone_or_pose_bone):
    matrix = bone_or_pose_bone.matrix_local if hasattr(bone_or_pose_bone, "matrix_local") else bone_or_pose_bone.matrix
    return armature.matrix_world @ matrix


def leg_length(armature, hips_name, foot_names):
    hips = bone_world_matrix(armature, armature.data.bones[hips_name]).translation
    feet = [bone_world_matrix(armature, armature.data.bones[name]).translation for name in foot_names]
    foot = sum(feet, Vector()) / len(feet)
    return (hips - foot).length


def safe_action_name(source_name):
    return "achilles_v2__" + re.sub(r"[^A-Za-z0-9_]+", "_", source_name).strip("_")


def set_linear_interpolation(action):
    # Curves created by keyframe_insert are exposed through channel bags in 5.1.
    for layer in action.layers:
        for strip in layer.strips:
            for channelbag in strip.channelbags:
                for curve in channelbag.fcurves:
                    for point in curve.keyframe_points:
                        point.interpolation = "LINEAR"


def action_curve_stats(action):
    curves = []
    for layer in action.layers:
        for strip in layer.strips:
            for channelbag in strip.channelbags:
                curves.extend(channelbag.fcurves)
    values = [point.co.y for curve in curves for point in curve.keyframe_points]
    return {
        "fcurves": len(curves),
        "keyframes": sum(len(curve.keyframe_points) for curve in curves),
        "all_values_finite": all(math.isfinite(value) for value in values),
    }


def pose_root_world(armature, action, frame, root_name):
    armature.animation_data.action = action
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    return bone_world_matrix(armature, armature.pose.bones[root_name]).translation.copy()


os.makedirs(OUT_DIR, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
scene.render.fps_base = 1.0

# Import source and retain exact Action objects before importing the canonical GLB.
bpy.ops.import_scene.gltf(filepath=SOURCE, import_shading="NORMALS")
source_objects = set(scene.objects)
source_armature = find_armature(source_objects, 24)
source_actions = list(bpy.data.actions)
source_action_names = {action: action.name for action in source_actions}
for action in source_actions:
    action.name = "SRC__" + action.name

before_canonical = set(scene.objects)
bpy.ops.import_scene.gltf(filepath=CANONICAL, import_shading="NORMALS")
canonical_objects = set(scene.objects) - before_canonical
target_armature = find_armature(canonical_objects, 52)
target_armature.name = "AchillesV2_Retargeted"
target_armature.data.name = "AchillesV2_Rig52"
target_actions_original = [action for action in bpy.data.actions if action not in source_actions]

missing_source = sorted(name for name in MAPPING if name not in source_armature.data.bones)
missing_target = sorted(name for name in MAPPING.values() if name not in target_armature.data.bones)
if missing_source or missing_target:
    raise RuntimeError(f"Mapping invalid: missing source={missing_source}, target={missing_target}")

scale_ratio = leg_length(
    target_armature,
    "mixamorig:Hips",
    ["mixamorig:LeftFoot", "mixamorig:RightFoot"],
) / leg_length(source_armature, "Hips", ["LeftFoot", "RightFoot"])

source_rest_world = {
    src: bone_world_matrix(source_armature, source_armature.data.bones[src]).copy()
    for src in MAPPING
}
target_rest_world = {
    dst: bone_world_matrix(target_armature, target_armature.data.bones[dst]).copy()
    for dst in MAPPING.values()
}
target_calibrated_rest_rotation = {}
for source_bone_name, target_bone_name in MAPPING.items():
    source_rest = source_rest_world[source_bone_name]
    target_rest = target_rest_world[target_bone_name]
    source_direction = (source_rest.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
    target_direction = (target_rest.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
    rest_pose_swing = target_direction.rotation_difference(source_direction)
    target_calibrated_rest_rotation[target_bone_name] = (
        rest_pose_swing @ target_rest.to_quaternion()
    )
target_rest_armature = {
    dst: target_armature.data.bones[dst].matrix_local.copy()
    for dst in MAPPING.values()
}
target_inverse_world = target_armature.matrix_world.inverted()
target_world_rotation_inverse = target_armature.matrix_world.to_quaternion().inverted()

# Parent-first ordering guarantees that target heads follow the already posed parent.
target_depth = {}
for bone in target_armature.data.bones:
    depth = 0
    parent = bone.parent
    while parent:
        depth += 1
        parent = parent.parent
    target_depth[bone.name] = depth
ordered_pairs = sorted(MAPPING.items(), key=lambda pair: target_depth[pair[1]])

if target_armature.animation_data is None:
    target_armature.animation_data_create()
if source_armature.animation_data is None:
    source_armature.animation_data_create()

results = []
retarget_actions = []
for source_action in sorted(source_actions, key=lambda item: source_action_names[item].casefold()):
    source_name = source_action_names[source_action]
    frame_start = int(math.floor(source_action.frame_range[0]))
    frame_end = int(math.ceil(source_action.frame_range[1]))
    source_armature.animation_data.action = source_action
    scene.frame_set(frame_start)
    bpy.context.view_layer.update()
    source_root_start_world = bone_world_matrix(source_armature, source_armature.pose.bones["Hips"]).translation.copy()

    target_action = bpy.data.actions.new(safe_action_name(source_name))
    target_action["achilles_pool_source"] = source_name
    target_action["achilles_pool_loop_candidate"] = source_name in LOOP_ACTIONS
    target_action["achilles_pool_root_motion_policy"] = "preserved_scaled"
    target_action["achilles_pool_retarget_scale"] = scale_ratio
    target_armature.animation_data.action = target_action

    for frame in range(frame_start, frame_end + 1):
        source_armature.animation_data.action = source_action
        scene.frame_set(frame)
        bpy.context.view_layer.update()

        # Clear all target bones so unmapped fingers remain in their canonical rest pose.
        for pose_bone in target_armature.pose.bones:
            pose_bone.matrix_basis.identity()
        bpy.context.view_layer.update()

        source_root_now_world = bone_world_matrix(source_armature, source_armature.pose.bones["Hips"]).translation
        root_delta_world = (source_root_now_world - source_root_start_world) * scale_ratio

        for source_bone_name, target_bone_name in ordered_pairs:
            source_pose_world = bone_world_matrix(source_armature, source_armature.pose.bones[source_bone_name])
            source_delta_rotation = (
                source_pose_world.to_quaternion()
                @ source_rest_world[source_bone_name].to_quaternion().inverted()
            )
            desired_world_rotation = (
                source_delta_rotation
                @ target_calibrated_rest_rotation[target_bone_name]
            )
            desired_armature_rotation = target_world_rotation_inverse @ desired_world_rotation

            target_pose_bone = target_armature.pose.bones[target_bone_name]
            if target_pose_bone.parent is None:
                rest_head_world = target_rest_world[target_bone_name].translation
                desired_head_armature = target_inverse_world @ (rest_head_world + root_delta_world)
            else:
                parent_rest = target_pose_bone.parent.bone.matrix_local
                child_rest = target_rest_armature[target_bone_name]
                child_rest_relative = parent_rest.inverted() @ child_rest
                desired_head_armature = target_pose_bone.parent.matrix @ child_rest_relative.translation

            desired_matrix = Matrix.Translation(desired_head_armature) @ desired_armature_rotation.to_matrix().to_4x4()
            target_pose_bone.matrix = desired_matrix

        target_armature.animation_data.action = target_action
        for _, target_bone_name in ordered_pairs:
            pose_bone = target_armature.pose.bones[target_bone_name]
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.keyframe_insert("location", frame=frame, group=target_bone_name)
            pose_bone.keyframe_insert("rotation_quaternion", frame=frame, group=target_bone_name)
            pose_bone.keyframe_insert("scale", frame=frame, group=target_bone_name)

    set_linear_interpolation(target_action)
    target_action.use_frame_range = True
    target_action.frame_start = frame_start
    target_action.frame_end = frame_end
    retarget_actions.append(target_action)

    target_root_start = pose_root_world(target_armature, target_action, frame_start, "mixamorig:Hips")
    target_root_end = pose_root_world(target_armature, target_action, frame_end, "mixamorig:Hips")
    source_root_end = pose_root_world(source_armature, source_action, frame_end, "Hips")
    source_delta = source_root_end - source_root_start_world
    target_delta = target_root_end - target_root_start
    expected_delta = source_delta * scale_ratio
    error = target_delta - expected_delta
    results.append({
        "source_action": source_name,
        "retarget_action": target_action.name,
        "frame_start": frame_start,
        "frame_end": frame_end,
        "duration_seconds": round((frame_end - frame_start) / 30.0, 6),
        "loop_candidate": source_name in LOOP_ACTIONS,
        "source_root_delta_world": [round(v, 7) for v in source_delta],
        "target_root_delta_world": [round(v, 7) for v in target_delta],
        "expected_target_delta_world": [round(v, 7) for v in expected_delta],
        "root_delta_error": round(error.length, 9),
        **action_curve_stats(target_action),
    })

# Keep only the canonical model plus its native and retargeted action library.
target_armature.animation_data.action = retarget_actions[0] if retarget_actions else None
for obj in list(source_objects):
    if obj.name in scene.objects:
        bpy.data.objects.remove(obj, do_unlink=True)
for action in source_actions:
    bpy.data.actions.remove(action)

# Remove any isolated source-only objects accidentally left by importer bookkeeping.
for obj in list(scene.objects):
    if obj not in canonical_objects:
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, check_existing=False)

# Export only the copied V1 armature/mesh and all compatible actions.
bpy.ops.object.select_all(action="DESELECT")
for obj in canonical_objects:
    if obj.name in scene.objects:
        obj.select_set(True)
target_armature.select_set(True)
bpy.context.view_layer.objects.active = target_armature
bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_skins=True,
    export_morph=False,
)

report = {
    "status": "PASS" if all(item["all_values_finite"] and item["root_delta_error"] < 1e-5 for item in results) else "FAIL",
    "blender_version": bpy.app.version_string,
    "source": SOURCE,
    "canonical_input_immutable": CANONICAL,
    "output_blend": OUT_BLEND,
    "output_glb": OUT_GLB,
    "mapping": MAPPING,
    "mapped_source_bones": len(MAPPING),
    "canonical_unanimated_bones": sorted(set(bone.name for bone in target_armature.data.bones) - set(MAPPING.values())),
    "retarget_scale_leg_ratio": round(scale_ratio, 9),
    "source_action_count": len(source_action_names),
    "retarget_action_count": len(retarget_actions),
    "native_canonical_action_count": len(target_actions_original),
    "actions": results,
    "output_sizes": {
        "blend_bytes": os.path.getsize(OUT_BLEND),
        "glb_bytes": os.path.getsize(OUT_GLB),
    },
}
with open(OUT_JSON, "w", encoding="utf-8") as handle:
    json.dump(report, handle, ensure_ascii=False, indent=2)

print("RETARGET_STATUS", report["status"])
print("RETARGETED", len(retarget_actions), "actions")
print("SCALE_RATIO", scale_ratio)
print("BLEND", OUT_BLEND)
print("GLB", OUT_GLB)
