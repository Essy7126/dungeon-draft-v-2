class_name PasseRiveAutoSpriteProfile
extends AchillesSpriteVisualProfile

const DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const COUNTS := {
	"idle": 25,
	"walk": 11,
	"run": 7,
	"bow": 25,
	"dash": 25,
	"dodge": 25,
	"hit": 25,
	"death": 19,
	"jump": 25,
	"attack": 25,
	"guard": 25,
	"sweep": 25,
	"volley": 25,
	"bow_piercing": 25,
	"bow_death": 25,
	"combat_idle": 1,
	"bow_quick": 6,
	"bow_charged": 8,
	"bow_air": 9,
}

const COMBAT_STEMS := ["combat_idle", "bow_quick", "bow_charged", "bow_air"]
const AIR_ORIGINS := {
	"N": Vector2(17, -110),
	"NE": Vector2(29, -108),
	"E": Vector2(31, -106),
	"SE": Vector2(27, -103),
	"S": Vector2(0, -106),
	"SW": Vector2(-28, -107),
	"W": Vector2(-30, -106),
	"NW": Vector2(-28, -109),
}


func get_cast_origin(stem: String, direction: String) -> Vector2:
	if stem == "bow_air":
		return AIR_ORIGINS.get(direction, Vector2(0, -106))
	if stem == "bow_charged":
		return super.get_cast_origin(stem, direction) + Vector2(0, 15)
	return super.get_cast_origin(stem, direction)


func get_action_clip_settings(stem: String) -> Dictionary:
	if stem == "dash":
		return {
			"frame_count": 25,
			"duration_seconds": advance_duration_seconds,
			"release_seconds": advance_release_seconds,
			"release_frame": 2,
		}
	return super.get_action_clip_settings(stem)


func validation_error(candidate: SpriteFrames) -> StringName:
	if candidate == null:
		return &"SPRITE_FRAMES_MISSING"
	if display_scale <= 0.0 or frame_canvas_size != Vector2i(256, 256):
		return &"SPRITE_GEOMETRY_INVALID"
	var error := _action_settings_validation_error()
	if error != &"":
		return error
	for direction: String in DIRECTIONS:
		for stem: String in COUNTS:
			var clip := StringName(stem + "_" + direction)
			if not candidate.has_animation(clip) or candidate.get_frame_count(clip) != COUNTS[stem]:
				return &"SPRITE_FRAME_COUNT_INVALID"
			if candidate.get_animation_loop(clip) != (stem in ["idle", "walk", "run", "combat_idle"]):
				return &"SPRITE_CLIP_LOOP_INVALID"
			var size := Vector2(384, 384) if stem in COMBAT_STEMS else Vector2(256, 256)
			for index in COUNTS[stem]:
				var texture := candidate.get_frame_texture(clip, index)
				if texture == null or texture.get_size() != size:
					return &"SPRITE_FRAME_TEXTURE_INVALID"
	return &""
