@tool
class_name ArenaTileProjectionService
extends RefCounted

## Projection affine de l'empreinte losange normalisee d'une texture vers le
## polygone reel d'une cellule. Le meme calcul sert a tous les renderers Node2D.

const NORMALIZED_TILE_SIZE := Vector2i(256, 128)


static func texture_contract(texture: Texture2D) -> Dictionary:
	var result := {
		"valid": false,
		"size": Vector2i.ZERO,
		"alpha_bounds": Rect2i(),
		"expected_size": NORMALIZED_TILE_SIZE,
		"expected_alpha_bounds": Rect2i(Vector2i.ZERO, NORMALIZED_TILE_SIZE),
		"reason": "texture_missing",
	}
	if texture == null:
		return result
	result.size = Vector2i(texture.get_size())
	if result.size != NORMALIZED_TILE_SIZE:
		result.reason = "size_mismatch"
		return result
	var image := texture.get_image()
	if image == null or image.is_empty():
		result.reason = "image_unreadable"
		return result
	var bounds := _alpha_bounds(image)
	result.alpha_bounds = bounds
	if bounds != Rect2i(Vector2i.ZERO, NORMALIZED_TILE_SIZE):
		result.reason = "alpha_bounds_mismatch"
		return result
	result.valid = true
	result.reason = "normalized_diamond"
	return result


static func _alpha_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 1.0 / 255.0:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


static func sprite_transform(
		texture: Texture2D,
		target_polygon: PackedVector2Array,
		center: Vector2,
		inset_ratio := 0.0
	) -> Transform2D:
	if texture == null or target_polygon.size() < 4:
		return Transform2D.IDENTITY
	var source_size := Vector2(texture.get_size())
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Transform2D.IDENTITY
	var source_top := Vector2(source_size.x * 0.5, 0.0)
	var source_right := Vector2(source_size.x, source_size.y * 0.5)
	var source_left := Vector2(0.0, source_size.y * 0.5)
	var source_transform := Transform2D(
		source_right - source_top,
		source_left - source_top,
		source_top
	)
	if is_zero_approx(source_transform.determinant()):
		return Transform2D.IDENTITY
	var keep_ratio := 1.0 - clampf(inset_ratio, 0.0, 0.95)
	var target_top: Vector2 = (target_polygon[0] - center) * keep_ratio
	var target_right: Vector2 = (target_polygon[1] - center) * keep_ratio
	var target_left: Vector2 = (target_polygon[3] - center) * keep_ratio
	var target_transform := Transform2D(
		target_right - target_top,
		target_left - target_top,
		target_top
	)
	return target_transform * source_transform.affine_inverse()


static func polygon_uv(texture: Texture2D) -> PackedVector2Array:
	if texture == null:
		return PackedVector2Array()
	# CanvasItem.draw_polygon attend des UV normalisées, contrairement à la
	# transformation Sprite2D ci-dessus qui travaille dans l'espace pixel source.
	return PackedVector2Array([
		Vector2(0.5, 0.0),
		Vector2(1.0, 0.5),
		Vector2(0.5, 1.0),
		Vector2(0.0, 0.5),
	])
