class_name AchillesAutoSpriteProfile
extends AchillesSpriteVisualProfile

const DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const CLIP_COUNTS := {
	"idle": 25,
	"walk": 12,
	"run": 7,
	"attack": 25,
	"sweep": 25,
	"bow": 25,
	"hook": 25,
	"bow_piercing": 25,
	"bow_death": 25,
	"volley": 25,
	"dash": 4,
	"guard": 4,
	"hit": 3,
	"death": 4,
}


static func screen_facing(direction: Vector2) -> String:
	return DIRECTIONS[posmod(roundi(direction.angle() / (PI / 4.0)), 8)]


func validation_error(candidate: SpriteFrames) -> StringName:
	if candidate == null:
		return &"SPRITE_FRAMES_MISSING"
	if (
		display_scale <= 0.0 or frame_canvas_size != Vector2i(256, 256)
		or not foot_anchor.is_finite()
	):
		return &"SPRITE_GEOMETRY_INVALID"
	if walk_segment_duration_seconds <= 0.0 or run_segment_duration_seconds <= 0.0:
		return &"SPRITE_MOVEMENT_TIMING_INVALID"
	var settings_error := _action_settings_validation_error()
	if settings_error != &"":
		return settings_error
	for direction: String in DIRECTIONS:
		for stem: String in CLIP_COUNTS:
			var clip := StringName(stem + "_" + direction)
			if not candidate.has_animation(clip):
				return &"SPRITE_DIRECTION_CLIP_MISSING"
			if candidate.get_frame_count(clip) != CLIP_COUNTS[stem]:
				return &"SPRITE_FRAME_COUNT_INVALID"
			if candidate.get_animation_speed(clip) <= 0.0:
				return &"SPRITE_CLIP_SPEED_INVALID"
			if candidate.get_animation_loop(clip) != (stem in ["idle", "walk", "run"]):
				return &"SPRITE_CLIP_LOOP_INVALID"
			for index in candidate.get_frame_count(clip):
				var texture := candidate.get_frame_texture(clip, index)
				if texture == null or texture.get_size() != Vector2(frame_canvas_size):
					return &"SPRITE_FRAME_TEXTURE_INVALID"
				if candidate.get_frame_duration(clip, index) <= 0.0:
					return &"SPRITE_FRAME_DURATION_INVALID"
	return &""
