class_name CatabaseMonsterSpriteProfile
extends Resource

## All poses use the same authored canvas and ground pivot. UnitView owns translation.
const CLIP_COUNTS := {"idle": 8, "walk": 12, "attack": 8, "cast": 8, "hit": 4, "death": 8}
const DIRECTIONS := ["N", "E", "S", "W"]

@export var profile_id: StringName
@export_file("*.tres") var sprite_frames_path := ""
@export var frames: SpriteFrames
@export var frame_canvas_size := Vector2i(512, 384)
@export var foot_anchor := Vector2(256.0, 320.0)
@export_range(0.05, 2.0, 0.01) var display_scale := 0.35
@export_enum("biped", "quadruped", "slither") var locomotion := "biped"
## Half-cycle per cell alternates biped foot contacts. Quadrupeds cover one gait cycle.
## Serpents sample the continuous authored coil cycle, with no synthetic foot snapping.
@export_range(0.05, 2.0, 0.05) var stride_cycles_per_cell := 0.5
@export_range(1.0, 512.0, 1.0) var external_stride_distance_pixels := 128.0
@export_range(0.05, 1.0, 0.01) var movement_segment_duration_seconds := 0.30
@export_range(0.2, 5.0, 0.05) var idle_cycle_seconds := 1.6
@export var primary_spell_ids: Array[StringName] = []
@export var action_durations: Dictionary = {"attack": 0.64, "cast": 0.80}
@export_range(0, 7, 1) var release_frame := 4
@export_range(0.05, 1.0, 0.01) var hit_duration_seconds := 0.20
@export_range(0.05, 2.0, 0.01) var death_duration_seconds := 0.64
@export_range(0.01, 1.0, 0.01) var death_fade_seconds := 0.16
@export var cast_origins: Dictionary = {
	"N": Vector2(12.0, -52.0), "E": Vector2(30.0, -42.0),
	"S": Vector2(-12.0, -40.0), "W": Vector2(-30.0, -50.0),
}


func validation_error(candidate: SpriteFrames) -> StringName:
	if candidate == null:
		return &"SPRITE_FRAMES_MISSING"
	if not is_finite(display_scale) or display_scale <= 0.0 \
			or frame_canvas_size.x <= 0 or frame_canvas_size.y <= 0 \
			or not foot_anchor.is_finite() or foot_anchor.x < 0.0 or foot_anchor.y < 0.0 \
			or foot_anchor.x > frame_canvas_size.x or foot_anchor.y > frame_canvas_size.y:
		return &"SPRITE_GEOMETRY_INVALID"
	for timing: float in [idle_cycle_seconds, movement_segment_duration_seconds, stride_cycles_per_cell,
			external_stride_distance_pixels, hit_duration_seconds,
			death_duration_seconds, death_fade_seconds]:
		if not is_finite(timing) or timing <= 0.0:
			return &"SPRITE_TIMING_INVALID"
	if locomotion not in ["biped", "quadruped", "slither"]:
		return &"SPRITE_LOCOMOTION_INVALID"
	if release_frame < 0 or release_frame >= CLIP_COUNTS.attack:
		return &"SPRITE_RELEASE_MARKER_INVALID"
	for stem: String in ["attack", "cast"]:
		var timing := float(action_durations.get(stem, 0.0))
		if not is_finite(timing) or timing <= 0.0:
			return &"SPRITE_ACTION_TIMING_INVALID"
	for direction: String in DIRECTIONS:
		for stem: String in CLIP_COUNTS:
			var clip := StringName(stem + "_" + direction)
			if not candidate.has_animation(clip):
				return &"SPRITE_DIRECTION_CLIP_MISSING"
			if candidate.get_frame_count(clip) != CLIP_COUNTS[stem]:
				return &"SPRITE_FRAME_COUNT_INVALID"
			if candidate.get_animation_speed(clip) <= 0.0:
				return &"SPRITE_CLIP_SPEED_INVALID"
			if candidate.get_animation_loop(clip) != (stem in ["idle", "walk"]):
				return &"SPRITE_CLIP_LOOP_INVALID"
			for index in candidate.get_frame_count(clip):
				var texture := candidate.get_frame_texture(clip, index)
				if texture == null or texture.get_size() != Vector2(frame_canvas_size):
					return &"SPRITE_FRAME_TEXTURE_INVALID"
				var weight := candidate.get_frame_duration(clip, index)
				if not is_finite(weight) or weight <= 0.0:
					return &"SPRITE_FRAME_DURATION_INVALID"
	return &""


func duration_for(stem: String) -> float:
	return float(action_durations.get(stem, 0.64))


func spell_animation_stem(spell: Spell) -> String:
	if spell != null and spell.get_effective_spell_id() in primary_spell_ids:
		return "attack"
	return "cast"
