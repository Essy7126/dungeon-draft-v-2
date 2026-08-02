extends Node2D

## Substitution visuelle temporaire, activee uniquement par la premiere salle
## isometrique. Le parent UnitView continue de porter toute la logique, les
## signaux et les animations ; seuls ses CanvasItem historiques sont masques.

const HERO_COLOR := Color(0.20, 0.72, 1.0, 1.0)
const HERO_LIGHT := Color(0.62, 0.91, 1.0, 1.0)
const ENEMY_COLOR := Color(0.95, 0.31, 0.23, 1.0)
const ENEMY_LIGHT := Color(1.0, 0.68, 0.42, 1.0)
const OUTLINE := Color(0.055, 0.075, 0.10, 0.95)
const SHADOW := Color(0.03, 0.045, 0.05, 0.42)
const REFERENCE_GOBLIN_NAME := "Eclaireur gobelin"

var unit = null
var _legacy_items: Array[CanvasItem] = []
var _reference_sprite: AnimatedSprite2D = null
var _reference_visual_bounds := Rect2()
var _draw_marker := true
# Faux quand une ombre skewee (IsoGroundShadow) epouse deja la case : on evite
# alors la double ombre en n'affichant plus l'ellipse plate historique.
var _draw_flat_shadow := true


func setup(p_unit, unit_view: Node2D) -> void:
	unit = p_unit
	name = "IsoTemporaryPlaceholder"
	add_to_group("iso_temporary_placeholders")
	set_meta("temporary_iso_only", true)
	# Si une ombre skewee epouse deja la case, on desactive l'ellipse plate.
	for sibling in unit_view.get_children():
		if sibling != self and sibling.is_in_group("iso_ground_shadow"):
			_draw_flat_shadow = false
			break
	_draw_marker = not (unit.team != 0 and unit.unit_name == REFERENCE_GOBLIN_NAME)
	for child in unit_view.get_children():
		if child == self or not child is CanvasItem:
			continue
		if child.is_in_group("optional_unit_visuals"):
			continue
		_legacy_items.append(child)
		child.visible = false
		if not _draw_marker and _reference_sprite == null and child is AnimatedSprite2D:
			_reference_sprite = child
	if unit_view.has_method("has_optional_visual") and unit_view.has_optional_visual():
		visible = false
		set_process(false)
		queue_redraw()
		return
	if is_instance_valid(_reference_sprite):
		_prepare_reference_goblin(_reference_sprite)
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	# signal de stats. Ce composant local les maintient masquees sans modifier
	# UnitView ni les ressources de personnages.
	for item in _legacy_items:
		if not is_instance_valid(item):
			continue
		item.visible = item == _reference_sprite


func _prepare_reference_goblin(sprite: AnimatedSprite2D) -> void:
	var texture: Texture2D = null
	if sprite.sprite_frames != null and sprite.animation != &"":
		texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		_draw_marker = true
		_reference_sprite = null
		return
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		_draw_marker = true
		_reference_sprite = null
		return
	var visible_rect := _opaque_pixel_rect(texture)
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		visible_rect = Rect2(Vector2.ZERO, source_size)
	var factor := minf(34.0 / visible_rect.size.x, 52.0 / visible_rect.size.y)
	var visible_center_x := visible_rect.position.x + visible_rect.size.x * 0.5
	var visible_bottom := visible_rect.position.y + visible_rect.size.y
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.scale = Vector2(factor, factor)
	sprite.position = Vector2(
		-(visible_center_x - source_size.x * 0.5) * factor,
		-(visible_bottom - source_size.y * 0.5) * factor
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.visible = true
	_reference_visual_bounds = Rect2(
		Vector2(-visible_rect.size.x * factor * 0.5, -visible_rect.size.y * factor),
		visible_rect.size * factor
	)


func _opaque_pixel_rect(texture: Texture2D) -> Rect2:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2()
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.05:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2()
	return Rect2(
		Vector2(float(min_x), float(min_y)),
		Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))
	)


func get_ground_pivot() -> Vector2:
	return Vector2.ZERO


func get_visual_bounds() -> Rect2:
	if _draw_marker:
		return Rect2(-15.0, -58.0, 30.0, 58.0)
	if is_instance_valid(_reference_sprite):
		return _reference_visual_bounds
	return Rect2()


func uses_reference_goblin_sprite() -> bool:
	return not _draw_marker and is_instance_valid(_reference_sprite)


func _draw() -> void:
	if _draw_flat_shadow:
		draw_colored_polygon(_ellipse(Vector2(0.0, 0.5), Vector2(13.0, 4.0)), SHADOW)
	if not _draw_marker:
		return
	var main: Color = HERO_COLOR if unit != null and unit.team == 0 else ENEMY_COLOR
	var light: Color = HERO_LIGHT if unit != null and unit.team == 0 else ENEMY_LIGHT
	# Pivot au sol : les deux pieds terminent exactement sur y = 0.
	draw_line(Vector2(-6.0, -14.0), Vector2(-7.0, -1.0), OUTLINE, 7.0, true)
	draw_line(Vector2(6.0, -14.0), Vector2(7.0, -1.0), OUTLINE, 7.0, true)
	draw_line(Vector2(-6.0, -14.0), Vector2(-7.0, -1.0), main, 4.0, true)
	draw_line(Vector2(6.0, -14.0), Vector2(7.0, -1.0), main, 4.0, true)
	var torso := PackedVector2Array([
		Vector2(-12.0, -37.0), Vector2(12.0, -37.0),
		Vector2(10.0, -13.0), Vector2(-10.0, -13.0),
	])
	draw_colored_polygon(torso, OUTLINE)
	var inner_torso := PackedVector2Array([
		Vector2(-9.5, -35.0), Vector2(9.5, -35.0),
		Vector2(7.5, -15.0), Vector2(-7.5, -15.0),
	])
	draw_colored_polygon(inner_torso, main)
	draw_circle(Vector2(0.0, -47.0), 11.0, OUTLINE)
	draw_circle(Vector2(0.0, -47.0), 8.5, light)
	if unit != null and unit.team == 0:
		draw_polyline(PackedVector2Array([
			Vector2(-5.0, -27.0), Vector2(0.0, -22.0), Vector2(5.0, -27.0),
		]), light, 2.0, true)
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, -31.0), Vector2(5.0, -22.0), Vector2(-5.0, -22.0),
		]), light)


func _ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
