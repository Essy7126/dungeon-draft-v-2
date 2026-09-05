class_name AchillesSpriteVisualProfile
extends Resource

## Pure 2D presentation metadata. Grid position and combat rules stay outside.
@export var profile_id: StringName = &"achilles_cour_des_sources_sprites_v1"
@export_file("*.tres") var sprite_frames_path := "res://assets/characters/Achilles/sprites_cour_des_sources_v1/achilles_sprite_frames.tres"
@export var frames: SpriteFrames
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
# tween can last 0.48 s after the 0.10 s release; keep the loop alive beyond
# that bound so a long advance cannot finish and restart walk mid-travel.
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
	for direction: String in ["N", "E", "S", "W"]:
		for stem: String in ["idle", "walk", "attack"]:
			var clip := StringName(stem + "_" + direction)
			if not candidate.has_animation(clip) or candidate.get_frame_count(clip) < 1:
				return &"SPRITE_DIRECTION_CLIP_MISSING"
			if candidate.get_animation_speed(clip) <= 0.0:
				return &"SPRITE_CLIP_SPEED_INVALID"
			if candidate.get_animation_loop(clip) != (stem != "attack"):
				return &"SPRITE_CLIP_LOOP_INVALID"
			if stem == "attack" and (attack_release_frame < 0 \
					or attack_release_frame >= candidate.get_frame_count(clip)):
				return &"SPRITE_ATTACK_MARKER_INVALID"
			for frame_index in candidate.get_frame_count(clip):
				var texture := candidate.get_frame_texture(clip, frame_index)
				if texture == null or texture.get_size() != Vector2(frame_canvas_size):
					return &"SPRITE_FRAME_TEXTURE_INVALID"
	return &""
