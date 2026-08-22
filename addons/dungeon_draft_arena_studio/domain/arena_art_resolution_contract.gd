@tool
class_name ArenaArtResolutionContract
extends Resource

const DEFAULT_NATIVE_SIZE := Vector2i(1280, 720)
const DEFAULT_RUNTIME_VIEWPORT := Vector2i(1200, 896)

@export var native_art_size := DEFAULT_NATIVE_SIZE
@export var source_image_size := DEFAULT_NATIVE_SIZE
@export var reference_export_size := DEFAULT_NATIVE_SIZE
@export var preview_logic_size := Vector2i(1280, 720)
@export var preview_art_size := Vector2i(1280, 720)
@export var preview_game_size := Vector2i(1280, 720)
@export var thumbnail_size := Vector2i(512, 288)
@export var runtime_reference_viewport := DEFAULT_RUNTIME_VIEWPORT
@export var scaling_policy: StringName = &"NATIVE_NO_RESAMPLE"
@export var crop_policy: StringName = &"NONE"


static func from_arena(arena: ArenaDefinition) -> ArenaArtResolutionContract:
	var contract := ArenaArtResolutionContract.new()
	var native_size := DEFAULT_NATIVE_SIZE
	if arena != null and not arena.background_path.is_empty() \
			and ResourceLoader.exists(arena.background_path):
		var texture := load(arena.background_path) as Texture2D
		if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
			native_size = Vector2i(texture.get_width(), texture.get_height())
	elif arena != null and arena.source_image_size.x > 0 \
			and arena.source_image_size.y > 0:
		native_size = arena.source_image_size
	contract.native_art_size = native_size
	contract.source_image_size = arena.source_image_size \
		if arena != null and arena.source_image_size.x > 0 \
				and arena.source_image_size.y > 0 else native_size
	contract.reference_export_size = native_size
	return contract


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for entry in [
		native_art_size, source_image_size, reference_export_size,
		preview_logic_size, preview_art_size, preview_game_size,
		thumbnail_size, runtime_reference_viewport,
	]:
		if entry.x <= 0 or entry.y <= 0:
			errors.append("Chaque résolution doit être strictement positive.")
			break
	if scaling_policy != &"NATIVE_NO_RESAMPLE":
		errors.append("Le kit natif ne peut pas être redimensionné silencieusement.")
	if crop_policy not in [&"NONE", &"EXPLICIT_SAFE_CROP"]:
		errors.append("Politique de recadrage inconnue.")
	return errors


func to_dict() -> Dictionary:
	return {
		"native_art_size": _size(native_art_size),
		"source_image_size": _size(source_image_size),
		"reference_export_size": _size(reference_export_size),
		"preview_logic_size": _size(preview_logic_size),
		"preview_art_size": _size(preview_art_size),
		"preview_game_size": _size(preview_game_size),
		"thumbnail_size": _size(thumbnail_size),
		"runtime_reference_viewport": _size(runtime_reference_viewport),
		"scaling_policy": str(scaling_policy),
		"crop_policy": str(crop_policy),
	}


static func from_dict(data: Dictionary) -> ArenaArtResolutionContract:
	var contract := ArenaArtResolutionContract.new()
	contract.native_art_size = _vector2i(data.get("native_art_size", [1280, 720]))
	contract.source_image_size = _vector2i(data.get("source_image_size", [1280, 720]))
	contract.reference_export_size = _vector2i(data.get("reference_export_size", [1280, 720]))
	contract.preview_logic_size = _vector2i(data.get("preview_logic_size", [1280, 720]))
	contract.preview_art_size = _vector2i(data.get("preview_art_size", [1280, 720]))
	contract.preview_game_size = _vector2i(data.get("preview_game_size", [1280, 720]))
	contract.thumbnail_size = _vector2i(data.get("thumbnail_size", [512, 288]))
	contract.runtime_reference_viewport = _vector2i(data.get("runtime_reference_viewport", [1200, 896]))
	contract.scaling_policy = StringName(data.get("scaling_policy", "NATIVE_NO_RESAMPLE"))
	contract.crop_policy = StringName(data.get("crop_policy", "NONE"))
	return contract


static func _size(value: Vector2i) -> Array[int]:
	return [value.x, value.y]


static func _vector2i(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1])) \
		if value is Array and value.size() >= 2 else Vector2i.ZERO
