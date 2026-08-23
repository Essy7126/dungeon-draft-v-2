class_name AchillesVisualProfile
extends Resource

const RENDERING_VIEWPORT_3D := &"VIEWPORT_3D"
const RENDERING_SUBVIEWPORT := RENDERING_VIEWPORT_3D
const FALLBACK_POLICY_LEGACY_2D_ON_VERIFIED_ERROR := (
	&"LEGACY_2D_ON_VERIFIED_ERROR"
)
const SUPPORTED_VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(256, 256),
	Vector2i(384, 384),
	Vector2i(512, 512),
]

@export var schema_version := 1
@export var profile_id: StringName = &"achilles_character_only_v1"

@export var character_scene: PackedScene
@export_file("*.glb") var character_asset_path := (
	"res://assets/characters/Achilles/3d/achilles_rig_v1.glb"
)
@export var skeleton_signature := (
	"6CC796EE5D708EE1A7F884C028C457CA535A4D7B572A189B36DFE5EBAD62D65D"
)
@export_range(0.1, 4.0, 0.01) var character_scale := 1.0

@export var rendering_mode: StringName = RENDERING_VIEWPORT_3D
@export var fallback_policy: StringName = (
	FALLBACK_POLICY_LEGACY_2D_ON_VERIFIED_ERROR
)
@export var fallback_backend_scene: PackedScene

@export var viewport_size := Vector2i(384, 384)
@export var camera_transform := Transform3D.IDENTITY
@export_range(0.25, 16.0, 0.01) var orthographic_size := 2.6
@export_range(32.0, 192.0, 0.5) var render_display_size := 96.0
@export var character_framing_offset := Vector3.ZERO

@export var directional_yaw_map: Dictionary = {
	"N": 180.0,
	"E": 90.0,
	"S": 0.0,
	"W": -90.0,
}

@export var animation_profile: Dictionary = {
	"IDLE": {
		"mode": "SOURCE_CLIP",
		"godot_name": "Anim_0_004",
		"source_name": "Anim_0.004",
		"root_motion": "LOCAL_XZ_NEUTRALIZED",
		"provenance": "OBSERVED_WEAPONLESS_VISUAL_REVIEW",
	},
	"MOVE": {
		"mode": "SOURCE_CLIP",
		"godot_name": "Anim_0_005",
		"source_name": "Anim_0.005",
		"root_motion": "LOCAL_XZ_NEUTRALIZED",
		"provenance": "OBSERVED_WEAPONLESS_VISUAL_REVIEW",
	},
	"ACTION_FALLBACK": {
		"mode": "SOURCE_CLIP_GENERIC_ACTION",
		"godot_name": "Anim_0_003",
		"source_name": "Anim_0.003",
		"root_motion": "LOCAL_XZ_NEUTRALIZED",
		"provenance": "OBSERVED_WEAPONLESS_VISUAL_REVIEW",
	},
	"DEATH_FALLBACK": {
		"mode": "ADAPTER_FADE",
		"provenance": "NO_CLASSIFIED_DEATH_CLIP",
	},
}

# Presentation-only locomotion rule. The combat path remains authoritative;
# this value merely decides which in-place loop is shown for that path.
@export_range(1, 99, 1) var run_min_path_cells := 6

# Per-clip playback calibration for animation-rich assets. Keys are animation
# names from the GLB. Unknown clips deliberately receive safe defaults so a
# newly imported clip can be previewed before it is artistically calibrated.
@export var clip_runtime: Dictionary = {}

# Deliberately generic: this slice never loads or types an equipment resource.
@export var equipment_enabled := false
@export var weapon_profile: Resource = null


func is_character_only_valid() -> bool:
	return schema_version == 1 \
		and profile_id != &"" \
		and character_scene != null \
		and fallback_backend_scene != null \
		and not character_asset_path.is_empty() \
		and not skeleton_signature.is_empty() \
		and rendering_mode == RENDERING_VIEWPORT_3D \
		and fallback_policy == FALLBACK_POLICY_LEGACY_2D_ON_VERIFIED_ERROR \
		and render_display_size >= 32.0 \
		and render_display_size <= 192.0 \
		and not equipment_enabled \
		and weapon_profile == null


func validated_viewport_size() -> Vector2i:
	if viewport_size in SUPPORTED_VIEWPORT_SIZES:
		return viewport_size
	return Vector2i(384, 384)


func yaw_for_direction(direction: String) -> float:
	return float(directional_yaw_map.get(direction.to_upper(), 0.0))


func runtime_for_clip(clip_name: StringName) -> Dictionary:
	var defaults := {
		"speed_scale": 1.0,
		"release_normalized": 0.5,
		"blend_time": 0.12,
		"root_motion_policy": "LOCAL_XZ_NEUTRALIZED",
	}
	if clip_name == &"":
		return defaults
	var stored: Variant = clip_runtime.get(String(clip_name), {})
	if not stored is Dictionary:
		return defaults
	var result := defaults.duplicate(true)
	result.merge(stored as Dictionary, true)
	result["speed_scale"] = clampf(
		float(result.get("speed_scale", 1.0)), 0.05, 8.0
	)
	result["release_normalized"] = clampf(
		float(result.get("release_normalized", 0.5)), 0.05, 0.95
	)
	result["blend_time"] = clampf(
		float(result.get("blend_time", 0.12)), 0.0, 1.0
	)
	return result
