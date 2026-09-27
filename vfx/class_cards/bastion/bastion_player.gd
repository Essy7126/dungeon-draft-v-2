extends Node2D
## Three authored panels; source-scoped protection uses the existing compact badge rail.
const SOURCE_ID := &"class_g_bastion"
const ATLAS := "res://vfx/class_cards/bastion/"
static var textures: Dictionary = { }
var recipe: Dictionary = { }
var elapsed := 0.0
var duration := 1.6
var closed := false
var persistent := false
var badge_mode := false
var anchor: Node2D
var point := Vector2.ZERO
var origin := Vector2.INF
var width := 280.0
var sprites: Array[Sprite2D] = []
var manual := false
var status_slot := 0
var status_count := 1
var phase := ""


func configure(
	entry: Dictionary,
	world_point: Vector2,
	display_width: float,
	unit_anchor: Node2D = null,
	hold := false,
) -> void:
	recipe = entry.duplicate(true)
	point = world_point
	width = display_width
	anchor = unit_anchor
	persistent = hold
	phase = recipe.get("feedback_phase", "")
	badge_mode = hold or phase == "expire"
	status_slot = int(recipe.get("status_slot", 0))
	status_count = int(recipe.get("status_count", 1))
	duration = 1.6 if phase == "" else .42
	if phase == "" and not hold:
		for layer in ["back", "front"]:
			if not textures.has(layer):
				textures[layer] = load(ATLAS + layer + ".png")
			var sprite := Sprite2D.new()
			sprite.texture = textures[layer]
			sprite.hframes = 8
			sprite.vframes = 6
			sprite.offset = Vector2(0, -54.0192)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			if is_instance_valid(anchor):
				anchor.add_child(sprite)
			else:
				add_child(sprite)
			sprite.z_index = 0 if layer == "back" else 3
			sprite.show_behind_parent = layer == "back"
			if layer == "back":
				sprite.get_parent().move_child(sprite, 0)
			sprites.append(sprite)
	z_index = 7 if badge_mode else 4
	sample(0.0)


func set_status_slot(slot: int, count: int) -> void:
	status_slot = slot
	status_count = count
	sample(elapsed)


func _process(delta: float) -> void:
	if manual or closed:
		return
	if not persistent and phase == "" and recipe.has("bastion_unit"):
		var unit = recipe.bastion_unit.get_ref()
		if not is_instance_valid(unit) or not unit.is_alive or unit.get_shield_value(SOURCE_ID) <= 0:
			cancel()
			return
	sample(elapsed + delta)
	if not persistent and elapsed >= duration:
		cancel()


func sample(time: float) -> void:
	elapsed = maxf(time, 0.0)
	global_position = anchor.global_position if is_instance_valid(anchor) else point
	for sprite in sprites:
		if not is_instance_valid(sprite):
			continue
		sprite.global_position = global_position
		sprite.global_scale = Vector2.ONE * width / 384.0
		sprite.frame = clampi(int(elapsed * 30.0 + .00001), 0, 47)
		sprite.visible = not closed and elapsed < duration
		sprite.modulate.a = smoothstep(0.0, .09, elapsed) * (1.0 - smoothstep(.90, 1.46, elapsed))
	queue_redraw()


func _shield(at: Vector2, size_value: float, alpha: float, split := 0.0) -> void:
	var outline := [
		Vector2(-.5, -.32),
		Vector2(-.5, -.64),
		Vector2(-.24, -.64),
		Vector2(-.24, -.40),
		Vector2(-.10, -.40),
		Vector2(-.10, -.70),
		Vector2(.10, -.70),
		Vector2(.10, -.40),
		Vector2(.24, -.40),
		Vector2(.24, -.64),
		Vector2(.5, -.64),
		Vector2(.5, -.32),
		Vector2(.42, .32),
		Vector2(0, .65),
		Vector2(-.42, .32),
	]
	for layer in 3:
		var shade: Color = [Color("172938"), Color("efc76c"), Color("327480")][layer]
		shade.a = alpha
		var scale_value: float = size_value * [1.16, 1.0, .70][layer]
		if split == 0.0:
			var points := PackedVector2Array()
			for p: Vector2 in outline:
				points.append(at + p * scale_value)
			draw_colored_polygon(points, shade)
		else:
			for side in [-1.0, 1.0]:
				var points := PackedVector2Array()
				for p: Vector2 in [
					Vector2(0, -.64),
					Vector2(.46, -.5),
					Vector2(.42, .32),
					Vector2(0, .65),
					Vector2(.08, .1),
					Vector2(-.04, -.14),
				]:
					points.append(
						at + Vector2(p.x * side + side * split, p.y + split * .55) * scale_value
					)
				draw_colored_polygon(points, shade)
	if split == 0.0:
		draw_line(
			at + Vector2(0, -.22) * size_value,
			at + Vector2(0, .24) * size_value,
			Color(.72, .96, .84, alpha),
			maxf(1.0, size_value * .10),
			true,
		)


func _draw() -> void:
	if closed:
		return
	if badge_mode:
		if status_slot >= 6:
			return
		var at := Vector2((status_slot - (mini(status_count, 6) - 1) * .5) * 24.0, -106)
		if persistent and status_count > 6 and status_slot == 5:
			draw_string(
				ThemeDB.fallback_font,
				at + Vector2(-9, 5),
				"+%d" % (status_count - 5),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				13,
				Color("fff1cc"),
			)
			return
		var alpha := 1.0 if persistent else 1.0 - smoothstep(.0, .42, elapsed)
		if not persistent:
			at.y -= elapsed * 24
		_shield(at, 16, alpha)
		return
	if phase in ["absorb", "break"]:
		var center := Vector2(0, -width * .42)
		var u := clampf(elapsed / duration, 0.0, 1.0)
		var alpha := 1.0 - smoothstep(.48, 1.0, u)
		var size_value := width * .27 * (1.0 + .12 * sin(u * PI))
		_shield(center, size_value, alpha, u * .8 if phase == "break" else 0.0)
		if phase == "absorb" and u < .52:
			for side in [-1, 1]:
				var at := center + Vector2(side * size_value * .70, -size_value * .08)
				draw_line(
					at,
					at + Vector2(side * size_value * .27, -size_value * .16),
					Color("fff0bf"),
					2,
					true,
				)
		if phase == "break":
			for i in 4:
				var side := -1.0 if i % 2 == 0 else 1.0
				var at := center + Vector2(side * (.2 + u * .65), u * u * .60 - .15 * (i % 2)) * size_value
				var shard := PackedVector2Array(
					[at, at + Vector2(side * 5, -7), at + Vector2(side * 8, 4)]
				)
				draw_colored_polygon(shard, Color(.94, .75, .38, alpha))
		return
	# A thin contact at each locking foot, then a short transfer toward the badge.
	for i in 3:
		var age: float = elapsed - [8.0 / 30.0, 10.0 / 30.0, 12.0 / 30.0][i]
		if age >= 0 and age < .13:
			var at: Vector2 = [Vector2(-.17, .02), Vector2(-.035, -.10), Vector2(.17, .045)][i] * width
			var reach := width * (.045 + age * .22)
			draw_line(at - Vector2(reach, 0), at + Vector2(reach, 0), Color("fff0bf"), 2, true)
	if elapsed >= .84 and elapsed < 1.32:
		var u := inverse_lerp(.84, 1.32, elapsed)
		for side in [-1.0, 1.0]:
			var at := Vector2(side * width * .18 * (1 - u), lerpf(-width * .2, -106, u))
			var size_value := 3.0 * sin(u * PI)
			draw_colored_polygon(
				PackedVector2Array(
					[
						at + Vector2(0, -size_value * 2),
						at + Vector2(size_value, 0),
						at + Vector2(0, size_value * 2),
						at - Vector2(size_value, 0),
					]
				),
				Color("bcf4d8"),
			)


func cancel() -> void:
	if closed:
		return
	closed = true
	for sprite in sprites:
		if is_instance_valid(sprite):
			sprite.hide()
			sprite.queue_free()
	sprites.clear()
	hide()
	queue_free()


func _exit_tree() -> void:
	for sprite in sprites:
		if is_instance_valid(sprite) and sprite.get_parent() != self:
			sprite.queue_free()
