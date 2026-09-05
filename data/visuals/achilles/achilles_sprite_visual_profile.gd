class_name AchillesSpriteVisualProfile
extends Resource

## Pure 2D presentation metadata. Grid position and combat rules stay outside.
@export var profile_id: StringName = &"achilles_cour_des_sources_sprites_v1"
@export_file("*.tres") var sprite_frames_path := "res://assets/characters/Achilles/sprites_cour_des_sources_v1/achilles_sprite_frames.tres"
@export var frames: SpriteFrames
@export var expanded_kit_enabled := false
@export_range(0.05, 2.0, 0.01) var attack_duration_seconds := 0.60
@export_range(0.0, 1.0, 0.01) var attack_release_seconds := 0.30
@export_range(0.05, 2.0, 0.01) var shot_duration_seconds := 0.72
@export_range(0.0, 1.0, 0.01) var shot_release_seconds := 0.36
@export_range(0.05, 2.0, 0.01) var sweep_duration_seconds := 0.72
@export_range(0.0, 1.0, 0.01) var sweep_release_seconds := 0.36
@export_range(0.05, 1.0, 0.01) var hit_duration_seconds := 0.24
@export_range(0.05, 2.0, 0.01) var death_duration_seconds := 0.48
@export_range(0.01, 1.0, 0.01) var death_fade_seconds := 0.12
@export var frame_canvas_size := Vector2i(512, 384)
@export var foot_anchor := Vector2(256.0, 320.0)
@export_range(0.05, 2.0, 0.01) var display_scale := 0.35
@export_range(0, 128, 1) var attack_release_frame := 3
@export_range(1, 99, 1) var run_min_path_cells := 6
@export_range(0.05, 1.0, 0.01) var walk_segment_duration_seconds := 0.28
@export_range(0.05, 1.0, 0.01) var run_segment_duration_seconds := 0.2
@export_range(0.05, 2.0, 0.01) var guard_duration_seconds := 0.34
@export_range(0.0, 1.0, 0.01) var guard_release_seconds := 0.12
# Fallback budget only: Battle ends the action on actual arrival. Its travel
# tween can last 0.48 s after the 0.10 s release; hold airborne dash frame 2
# throughout travel. Planted frame 3 is an interruptible 0.08 s landing only
# after arrival, outside this cast budget; it never publishes another marker.
@export_range(0.05, 2.0, 0.01) var advance_duration_seconds := 0.75
@export_range(0.0, 1.0, 0.01) var advance_release_seconds := 0.1
@export var cast_origins: Dictionary = {
	"N": Vector2(0.0, -62.0), "E": Vector2(30.0, -42.0),
	"S": Vector2(0.0, -38.0), "W": Vector2(-30.0, -42.0),
}


func validation_error(candidate: SpriteFrames) -> StringName:
	if candidate == null:
		return &"SPRITE_FRAMES_MISSING"
	if display_scale <= 0.0 or frame_canvas_size.x <= 0 or frame_canvas_size.y <= 0:
		return &"SPRITE_GEOMETRY_INVALID"
	if walk_segment_duration_seconds <= 0.0 or run_segment_duration_seconds <= 0.0:
		return &"SPRITE_MOVEMENT_TIMING_INVALID"
	if guard_release_seconds < 0.0 or guard_release_seconds >= guard_duration_seconds \
			or advance_release_seconds < 0.0 or advance_release_seconds >= advance_duration_seconds:
		return &"SPRITE_ACTION_TIMING_INVALID"
	if expanded_kit_enabled and (attack_release_seconds < 0.0 or attack_release_seconds >= attack_duration_seconds \
			or shot_release_seconds < 0.0 or shot_release_seconds >= shot_duration_seconds \
			or sweep_release_seconds < 0.0 or sweep_release_seconds >= sweep_duration_seconds \
			or advance_duration_seconds < advance_release_seconds + 0.48 \
			or hit_duration_seconds <= 0.0 or death_duration_seconds <= 0.0 or death_fade_seconds <= 0.0):
		return &"SPRITE_ACTION_TIMING_INVALID"
	var stems: Array[String] = ["idle", "walk", "attack"]
	if expanded_kit_enabled:
		stems.append_array(["dash", "bow", "guard", "sweep", "volley", "hit", "death"])
	for direction: String in ["N", "E", "S", "W"]:
		for stem: String in stems:
			var clip := StringName(stem + "_" + direction)
			if not candidate.has_animation(clip) or candidate.get_frame_count(clip) < 1:
				return &"SPRITE_DIRECTION_CLIP_MISSING"
			var count := candidate.get_frame_count(clip)
			if expanded_kit_enabled:
				var expected_count := 6 if stem in ["bow", "guard", "sweep", "volley"] else 4
				if stem in ["dash", "bow", "guard", "sweep", "volley", "death"] and count != expected_count:
					return &"SPRITE_FRAME_COUNT_INVALID"
				if stem == "hit" and count not in [3, 4]:
					return &"SPRITE_FRAME_COUNT_INVALID"
			if candidate.get_animation_speed(clip) <= 0.0:
				return &"SPRITE_CLIP_SPEED_INVALID"
			# Dash is sampled by the movement owner; its resource loop flag does
			# not determine when the charge returns to idle.
			if stem != "dash" and candidate.get_animation_loop(clip) != (stem in ["idle", "walk"]):
				return &"SPRITE_CLIP_LOOP_INVALID"
			if stem == "attack" and (attack_release_frame < 0 or attack_release_frame >= count):
				return &"SPRITE_ATTACK_MARKER_INVALID"
			for frame_index in count:
				var texture := candidate.get_frame_texture(clip, frame_index)
				if texture == null or texture.get_size() != Vector2(frame_canvas_size):
					return &"SPRITE_FRAME_TEXTURE_INVALID"
				if candidate.get_frame_duration(clip, frame_index) <= 0.0:
					return &"SPRITE_FRAME_DURATION_INVALID"
	return &""
