@tool
class_name ArenaTileVisualNormalizationService
extends RefCounted

## Autorité commune du footprint des neuf assets du catalogue complet.

const OUTPUT_SIZE := Vector2i(256, 128)
const ALPHA_THRESHOLD := 0.01


static func alpha_bounds(image: Image) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= ALPHA_THRESHOLD:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


static func intersect_bounds(bounds: Array[Rect2i]) -> Rect2i:
	if bounds.is_empty():
		return Rect2i()
	var result := bounds[0]
	for rect in bounds.slice(1):
		result = result.intersection(rect)
	return result


static func normalize(source: Image, shared_crop: Rect2i) -> Image:
	if source == null or source.is_empty() or shared_crop.size.x <= 0 \
			or shared_crop.size.y <= 0:
		return Image.new()
	var output := source.get_region(shared_crop)
	output.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	output.convert(Image.FORMAT_RGBA8)
	for y in range(OUTPUT_SIZE.y):
		for x in range(OUTPUT_SIZE.x):
			var color := output.get_pixel(x, y)
			if _inside_diamond(x, y):
				color.a = 1.0
			else:
				color = Color.TRANSPARENT
			output.set_pixel(x, y, color)
	return output


static func alignment_report(textures: Array[Texture2D]) -> Dictionary:
	var centers: Array[Vector2] = []
	var bounds: Array[Rect2i] = []
	for texture in textures:
		if texture == null:
			return {"valid": false, "reason": "texture_missing"}
		var image := texture.get_image()
		var rect := alpha_bounds(image)
		bounds.append(rect)
		centers.append(Vector2(rect.position) + Vector2(rect.size) * 0.5)
	var reference := centers[0] if not centers.is_empty() else Vector2.ZERO
	var maximum_center_delta := 0.0
	for center in centers:
		maximum_center_delta = maxf(maximum_center_delta, center.distance_to(reference))
	var bounds_identical := true
	for rect in bounds:
		if rect != Rect2i(Vector2i.ZERO, OUTPUT_SIZE):
			bounds_identical = false
			break
	return {
		"valid": maximum_center_delta <= 0.5 and bounds_identical,
		"center_tolerance": 0.5,
		"corner_tolerance": 0.75,
		"maximum_center_delta": maximum_center_delta,
		"bounds": bounds,
	}


static func _inside_diamond(x: int, y: int) -> bool:
	if y <= 64:
		return float(x) >= 128.0 - float(y) * 2.0 \
			and float(x) <= 128.0 + float(y) * (127.0 / 64.0)
	var lower_y := float(y - 64)
	return float(x) >= lower_y * (128.0 / 63.0) \
		and float(x) <= 255.0 - lower_y * (127.0 / 63.0)
