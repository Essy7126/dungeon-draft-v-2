class_name ParisSpriteVisualProfile
extends PhilosopherSpriteVisualProfile

@export_file("*.tres") var infernal_frames_path := "res://assets/characters/paris/sprites_v1/frames_infernal.tres"
@export_file("*.tres") var transformation_frames_path := "res://assets/characters/paris/sprites_v1/frames_transform.tres"
@export var infernal_frames: SpriteFrames
@export var transformation_frames: SpriteFrames
@export_range(0.1, 3.0, 0.01) var transformation_duration_seconds := 0.90
# Measured on native release poses; see characters/paris/release_origins.md.
@export var infernal_cast_origins: Dictionary = {
	"N": Vector2(46.90, -55.65), "E": Vector2(46.20, -58.45),
	"S": Vector2(-46.20, -58.45), "W": Vector2(-46.90, -55.65),
}
@export var spectral_spell_origins: Dictionary = {
	"N": Vector2(27.30, -25.90), "E": Vector2(-4.90, -48.65),
	"S": Vector2(4.90, -48.65), "W": Vector2(-27.30, -25.90),
}
@export var infernal_spell_origins: Dictionary = {
	"N": Vector2(34.65, -71.05), "E": Vector2(35.00, -52.50),
	"S": Vector2(-35.00, -52.50), "W": Vector2(-34.65, -71.05),
}
@export var infernal_pull_origins: Dictionary = {
	"N": Vector2(-28.00, -35.35), "E": Vector2(-29.05, -41.65),
	"S": Vector2(29.05, -41.65), "W": Vector2(28.00, -35.35),
}


func _init() -> void:
	profile_id = &"paris_sprites_v1"
	sprite_frames_path = "res://assets/characters/paris/sprites_v1/frames_spectral.tres"
	cast_origins = {
		"N": Vector2(38.85, -57.05), "E": Vector2(43.75, -45.50),
		"S": Vector2(-43.75, -45.50), "W": Vector2(-38.85, -57.05),
	}
	action_durations = {"attack": 0.68, "cast": 0.76}
	movement_segment_duration_seconds = 0.30
	hit_duration_seconds = 0.24
	death_duration_seconds = 0.64
	death_fade_seconds = 0.16


func release_origin(form: StringName, direction: String, stem: String, action_id: StringName) -> Vector2:
	var origins := infernal_cast_origins if form == &"infernal" else cast_origins
	if stem == "cast":
		origins = infernal_spell_origins if form == &"infernal" else spectral_spell_origins
		if form == &"infernal" and action_id == &"cast:paris_infernal_pull":
			origins = infernal_pull_origins
	# Profile coordinates were measured at 0.35; keep the same attachment if
	# an intentional sprite display scale changes without moving the root.
	return (origins.get(direction, origins["E"]) as Vector2) * (display_scale / 0.35)


func validation_error(candidate: SpriteFrames) -> StringName:
	if candidate == null:
		return &"SPRITE_FRAMES_MISSING"
	if display_scale <= 0 or frame_canvas_size.x <= 0 or frame_canvas_size.y <= 0 \
			or foot_anchor.x < 0 or foot_anchor.y < 0 \
			or foot_anchor.x > frame_canvas_size.x or foot_anchor.y > frame_canvas_size.y:
		return &"SPRITE_GEOMETRY_INVALID"
	if movement_segment_duration_seconds <= 0 or hit_duration_seconds <= 0 \
			or death_duration_seconds <= 0 or death_fade_seconds <= 0 \
			or transformation_duration_seconds <= 0 or release_ratio <= 0 or release_ratio >= 1:
		return &"SPRITE_TIMING_INVALID"
	for stem: String in ["attack", "cast"]:
		if float(action_durations.get(stem, 0)) <= 0:
			return &"SPRITE_ACTION_TIMING_INVALID"
	for direction: String in ["N", "E", "S", "W"]:
		for stem: String in ["idle", "walk", "attack", "cast", "hit", "death"]:
			var minimum := 1 if stem == "idle" else 4 if stem in ["walk", "attack"] else 3 if stem == "cast" else 2
			var error := _validate_clip(candidate, StringName(stem + "_" + direction), minimum, stem in ["idle", "walk"])
			if error != &"":
				return error
	return &""


func transformation_validation_error(candidate: SpriteFrames) -> StringName:
	if candidate == null:
		return &"TRANSFORMATION_FRAMES_MISSING"
	for direction: String in ["N", "E", "S", "W"]:
		var error := _validate_clip(candidate, StringName("transform_" + direction), 4, false)
		if error != &"":
			return error
	return &""


func _validate_clip(candidate: SpriteFrames, clip: StringName, minimum: int, looped: bool) -> StringName:
	if not candidate.has_animation(clip):
		return &"SPRITE_DIRECTION_CLIP_MISSING"
	var count := candidate.get_frame_count(clip)
	if count < minimum or (String(clip).begins_with("idle_") and count != 1):
		return &"SPRITE_FRAME_COUNT_INVALID"
	if candidate.get_animation_speed(clip) <= 0 or candidate.get_animation_loop(clip) != looped:
		return &"SPRITE_CLIP_TIMING_INVALID"
	for index in count:
		var texture := candidate.get_frame_texture(clip, index)
		if texture == null or texture.get_size() != Vector2(frame_canvas_size):
			return &"SPRITE_FRAME_TEXTURE_INVALID"
		if candidate.get_frame_duration(clip, index) <= 0:
			return &"SPRITE_FRAME_DURATION_INVALID"
	return &""
