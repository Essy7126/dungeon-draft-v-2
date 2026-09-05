class_name SpectreSpriteVisualProfile
extends Resource

## Authored sprite metadata only. The UnitView owns position and ground shadow.
@export var profile_id: StringName = &"spectre_greatsword_sprites_v1"
@export_file("*.tres") var sprite_frames_path := "res://assets/characters/spectre_greatsword/sprites_v1/spectre_sprite_frames.tres"
@export var frames: SpriteFrames
@export var frame_canvas_size := Vector2i(512, 384)
@export var foot_anchor := Vector2(256.0, 320.0)
@export_range(0.05, 2.0, 0.01) var display_scale := 0.35
@export_range(0.1, 2.0, 0.01) var model_scale := 1.05
@export_range(0.05, 1.0, 0.01) var movement_segment_duration_seconds := 0.28
@export_range(0.05, 3.0, 0.01) var attack_duration_seconds := 0.8
@export_range(0, 7, 1) var attack_release_frame := 3
@export_range(0.05, 2.0, 0.01) var death_duration_seconds := 0.32
@export var cast_origins: Dictionary = {
	"N": Vector2(14.0, -61.0), "E": Vector2(31.0, -42.0),
	"S": Vector2(-14.0, -36.0), "W": Vector2(-31.0, -55.0),
}


func validation_error(candidate: SpriteFrames) -> StringName:
	if candidate == null:
		return &"SPRITE_FRAMES_MISSING"
	if display_scale <= 0.0 or model_scale <= 0.0 \
			or frame_canvas_size.x <= 0 or frame_canvas_size.y <= 0 \
			or foot_anchor.x < 0.0 or foot_anchor.y < 0.0 \
			or foot_anchor.x > frame_canvas_size.x or foot_anchor.y > frame_canvas_size.y:
		return &"SPRITE_GEOMETRY_INVALID"
	if movement_segment_duration_seconds <= 0.0 or attack_duration_seconds <= 0.0 \
			or death_duration_seconds <= 0.0:
		return &"SPRITE_TIMING_INVALID"
	if attack_release_frame < 0 or attack_release_frame >= 8:
		return &"SPRITE_ATTACK_MARKER_INVALID"
	for direction: String in ["N", "E", "S", "W"]:
		for stem: String in ["idle", "walk", "attack"]:
			var clip := StringName(stem + "_" + direction)
			if not candidate.has_animation(clip):
				return &"SPRITE_DIRECTION_CLIP_MISSING"
			var expected_count := 1 if stem == "idle" else 4 if stem == "walk" else 8
			if candidate.get_frame_count(clip) != expected_count:
				return &"SPRITE_FRAME_COUNT_INVALID"
			if candidate.get_animation_speed(clip) <= 0.0:
				return &"SPRITE_CLIP_SPEED_INVALID"
			if candidate.get_animation_loop(clip) != (stem != "attack"):
				return &"SPRITE_CLIP_LOOP_INVALID"
			for frame_index in candidate.get_frame_count(clip):
				var texture := candidate.get_frame_texture(clip, frame_index)
				if texture == null or texture.get_size() != Vector2(frame_canvas_size):
					return &"SPRITE_FRAME_TEXTURE_INVALID"
				if candidate.get_frame_duration(clip, frame_index) <= 0.0:
					return &"SPRITE_FRAME_DURATION_INVALID"
	return &""


func get_display_scale() -> float:
	return display_scale * model_scale
