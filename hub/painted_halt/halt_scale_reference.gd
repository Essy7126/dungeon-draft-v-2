@tool
@static_unload
extends RefCounted

## One standing pose and foot anchor for authoring and runtime calibration.
## Height is measured from the ground to the top of idle_S, including its spear and plume.
const PROFILE := preload("res://data/visuals/achilles/achilles_kit_sprite_profile_v2.tres")
static var _texture: Texture2D
static var _height := 0.0


static func texture() -> Texture2D:
	if _texture == null:
		var frames := load(PROFILE.sprite_frames_path) as SpriteFrames
		_texture = frames.get_frame_texture(&"idle_S", 0)
	return _texture


static func foot_anchor() -> Vector2:
	return PROFILE.foot_anchor


static func reference_height() -> float:
	if _height <= 0:
		_height = maxf(1, foot_anchor().y - texture().get_image().get_used_rect().position.y)
	return _height


static func world_height(manifest: Dictionary) -> float:
	var source: Array = manifest.get("source", { }).get("size", [1600, 900])
	return float(manifest.world.width) * float(source[1]) / float(source[0])


static func height_ratio(manifest: Dictionary) -> float:
	if manifest.world.has("player_height_ratio"):
		return float(manifest.world.player_height_ratio)
	return reference_height() * float(manifest.world.get("player_scale", 0.52)) / world_height(
		manifest
	)


static func display_scale(manifest: Dictionary) -> float:
	return height_ratio(manifest) * world_height(manifest) / reference_height()


static func texture_rect(manifest: Dictionary, ground: Vector2, image_height: float) -> Rect2:
	var factor := height_ratio(manifest) * image_height / reference_height()
	return Rect2(ground - foot_anchor() * factor, texture().get_size() * factor)
