class_name PhilosopherSpriteVisualProfile
extends Resource

## Authored canvases share one ground pivot; the battle alone translates it.
@export var profile_id: StringName = &"philosopher_mage_sprites_v1"
@export_file("*.tres") var sprite_frames_path := "res://assets/characters/philosopher_mage/sprites_v1/philosopher_sprite_frames.tres"
@export var frames: SpriteFrames
@export var frame_canvas_size := Vector2i(512, 384)
@export var foot_anchor := Vector2(256.0, 320.0)
@export_range(0.05, 2.0, 0.01) var display_scale := 0.35
@export_range(0.05, 1.0, 0.01) var movement_segment_duration_seconds := 0.30
@export var action_durations: Dictionary = {
	"attack": 0.64, "heal": 0.80, "control": 0.72, "shield": 0.64,
}
@export_range(0.0, 1.0, 0.01) var release_ratio := 0.5
@export_range(0.05, 1.0, 0.01) var hit_duration_seconds := 0.24
@export_range(0.05, 2.0, 0.01) var death_duration_seconds := 0.52
@export_range(0.01, 1.0, 0.01) var death_fade_seconds := 0.12
@export var cast_origins: Dictionary = {
	"N": Vector2(10.0, -58.0), "E": Vector2(29.0, -50.0),
	"S": Vector2(-10.0, -42.0), "W": Vector2(-29.0, -50.0),
}


func validation_error(candidate: SpriteFrames) -> StringName:
	if candidate == null:
		return &"SPRITE_FRAMES_MISSING"
	if display_scale <= 0.0 or frame_canvas_size.x <= 0 or frame_canvas_size.y <= 0 \
			or foot_anchor.x < 0.0 or foot_anchor.y < 0.0 \
			or foot_anchor.x > frame_canvas_size.x or foot_anchor.y > frame_canvas_size.y:
		return &"SPRITE_GEOMETRY_INVALID"
	if movement_segment_duration_seconds <= 0.0 or hit_duration_seconds <= 0.0 \
			or death_duration_seconds <= 0.0 or death_fade_seconds <= 0.0 \
			or release_ratio <= 0.0 or release_ratio >= 1.0:
		return &"SPRITE_TIMING_INVALID"
	for stem: String in ["attack", "heal", "control", "shield"]:
		if float(action_durations.get(stem, 0.0)) <= 0.0:
			return &"SPRITE_ACTION_TIMING_INVALID"
	for direction: String in ["N", "E", "S", "W"]:
		for stem: String in ["idle", "walk", "attack", "heal", "control", "shield", "hit", "death"]:
			var clip := StringName(stem + "_" + direction)
			if not candidate.has_animation(clip):
				return &"SPRITE_DIRECTION_CLIP_MISSING"
			var count := candidate.get_frame_count(clip)
			if (stem == "idle" and count != 1) or (stem != "idle" and count < 4):
				return &"SPRITE_FRAME_COUNT_INVALID"
			if candidate.get_animation_speed(clip) <= 0.0:
				return &"SPRITE_CLIP_SPEED_INVALID"
			if candidate.get_animation_loop(clip) != (stem in ["idle", "walk"]):
				return &"SPRITE_CLIP_LOOP_INVALID"
			for index in count:
				var texture := candidate.get_frame_texture(clip, index)
				if texture == null or texture.get_size() != Vector2(frame_canvas_size):
					return &"SPRITE_FRAME_TEXTURE_INVALID"
				if candidate.get_frame_duration(clip, index) <= 0.0:
					return &"SPRITE_FRAME_DURATION_INVALID"
	return &""


func duration_for(stem: String) -> float:
	return float(action_durations.get(stem, 0.64))
