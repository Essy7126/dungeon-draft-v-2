extends Node2D
## Approved bronze tether, harpe and five-arrow volley. Presentation only.
signal cancelled
var CONTACT := .3
var recipe: Dictionary = { }
var origin := Vector2.ZERO
var point := Vector2.ZERO
var width := 128.0
var anchor: Node2D
var source_anchor: Node2D
var elapsed := 0.0
var duration := .9
var closed := false
var persistent := false
var badge_mode := false
var manual := false
var confirmed := false
var preparing := false
var full_sequence := false
var empowered := false
var hit := false
var destinations: Array[Vector2] = []
var hit_points: Array[Vector2] = []
var sprites: Array[Sprite2D] = []
var _clock := 0.0
var _contact_point := Vector2.ZERO
var _target: WeakRef
var _destination_cell := Vector2i.ZERO
var _movement_from := Vector2.ZERO
var _movement_to := Vector2.ZERO
var _moving := false
var _move_duration := .22
var _initial_position := Vector2.ZERO
static var textures := { }


func configure(
	entry: Dictionary,
	at: Vector2,
	display_width: float,
	unit_anchor: Node2D = null,
	_hold := false,
) -> void:
	recipe = entry.duplicate(true)
	point = at
	width = display_width
	anchor = unit_anchor
	CONTACT = { "g_hook": .2, "a_reap": .3, "r_scatter": .4 }.get(recipe.id, .3)
	preparing = bool(entry.get("approved_preparing", false))
	full_sequence = preparing
	confirmed = not preparing
	duration = .95 if preparing else .95 - CONTACT
	global_position = point
	z_index = 4
	match recipe.id:
		"g_hook":
			_sprite("hook")
			for i in 48:
				_sprite("link" if i % 2 == 0 else "link_edge")
		"a_reap":
			var blade := _sprite("reap")
			blade.hframes = 6
			blade.vframes = 5
			blade.offset = Vector2(0, -62.122)
		"r_scatter":
			pass # One instance per real area cell, populated by set_destinations.
	sample(0.0)


func _sprite(id: String) -> Sprite2D:
	if not textures.has(id):
		textures[id] = load("res://vfx/class_cards/approved/" + id + ".png")
	var sprite := Sprite2D.new()
	sprite.texture = textures[id]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	sprites.append(sprite)
	return sprite


func set_destinations(points: Array[Vector2]) -> void:
	destinations = points.duplicate()
	if recipe.id == "r_scatter":
		while sprites.size() < destinations.size():
			var arrow := _sprite("arrow")
			arrow.offset = Vector2(0, -79.7426)
	sample(elapsed)


func confirm() -> void:
	if closed or confirmed:
		return
	confirmed = true
	preparing = false
	elapsed = CONTACT
	sample(elapsed)


func follow_displacement(unit: Unit, view: Node2D, from: Vector2, to: Vector2) -> void:
	if not is_instance_valid(view) or from.is_equal_approx(to) or not unit.is_alive:
		return
	_target = weakref(unit)
	anchor = view
	_destination_cell = unit.grid_pos
	_movement_from = from
	_movement_to = to
	_move_duration = clampf(from.distance_to(to) / maxf(width, 1.0) * .075, .12, .26)
	_moving = true
	anchor.global_position = from
	_initial_position = from


func _process(delta: float) -> void:
	if closed or manual:
		return
	sample(elapsed + delta)
	if (preparing and elapsed > CONTACT + .45) or (confirmed and elapsed >= duration):
		cancel()


func sample(time: float) -> void:
	elapsed = maxf(time, 0.0)
	_clock = elapsed if full_sequence else elapsed + CONTACT
	if preparing:
		_clock = minf(_clock, CONTACT - .0001)
	global_position = point
	var age := maxf(0.0, _clock - CONTACT)
	if _moving:
		var unit: Unit = _target.get_ref()
		if not is_instance_valid(anchor) or unit == null or not unit.is_alive \
				or unit.grid_pos != _destination_cell \
				or not anchor.global_position.is_equal_approx(_initial_position):
			_moving = false # Another movement or shutdown owns the actor now.
		else:
			anchor.global_position = _movement_from.lerp(
				_movement_to,
				1.0 - pow(1.0 - clampf(age / _move_duration, 0.0, 1.0), 3.0),
			)
			_initial_position = anchor.global_position
			if age >= _move_duration:
				_moving = false
	match recipe.id:
		"g_hook":
			_chain(age)
		"a_reap":
			_reap(age)
		"r_scatter":
			_volley(age)
	queue_redraw()


func _chain(age: float) -> void:
	var start := (source_anchor.global_position if is_instance_valid(source_anchor) else origin) - point + Vector2(
		0,
		-width * .48,
	)
	var finish := (anchor.global_position if is_instance_valid(anchor) else point) - point + Vector2(
		0,
		-width * .34,
	)
	if not confirmed:
		finish = start.lerp(finish, smoothstep(0.0, CONTACT, _clock))
	var release := smoothstep(_move_duration + .035, _move_duration + .23, age) if confirmed else 0.0
	var vector := finish - start
	var count := clampi(ceili(vector.length() / (width * .13)), 1, 48)
	for i in range(1, sprites.size()):
		var link := sprites[i]
		link.visible = not closed and i <= count and release < 1.0
		var u := float(i - 1) / float(count)
		link.position = start.lerp(finish, u) + Vector2(
			0,
			width * .12 * sin(u * PI) * (1.0 - smoothstep(.10, CONTACT, _clock)),
		)
		link.position += Vector2((i % 3 - 1) * release, -release * (.3 + (i % 4) * .08)) * width * .2
		link.rotation = vector.angle() + .15 + release * (1.0 if i % 2 else -1.0)
		link.scale = Vector2.ONE * width * .27 / 192.0 * (1.0 - release)
	var hook := sprites[0]
	hook.visible = not closed and release < 1.0
	hook.position = finish + Vector2(width * .15 * release, -width * .12 * release)
	hook.rotation = vector.angle() + release * .7
	hook.scale = Vector2.ONE * width * .55 / 256.0 * (1.0 - release)
	_contact_point = finish


func _reap(age: float) -> void:
	var blade := sprites[0]
	blade.frame = clampi(int((_clock + .00001) * 30.0), 0, 29)
	blade.scale = Vector2.ONE * width * 2.25 / 384.0
	blade.position.y = -width * .12
	blade.visible = not closed and _clock < .90
	_contact_point = Vector2(0, -width * .40)
	# Geometry is identical; an execution bonus intensifies the single cut only.
	blade.modulate = Color(1.12, 1.07, 1.02) if empowered and confirmed and age < .1 else Color.WHITE


func _volley(age: float) -> void:
	for i in sprites.size():
		var arrow := sprites[i]
		arrow.visible = not closed and i < destinations.size() and _clock < CONTACT + .20
		if i >= destinations.size():
			continue
		var at := destinations[i] - point
		var incoming := Vector2(-width * (.35 + i * .035), -width * 1.7)
		var progress := smoothstep(.10, CONTACT, _clock)
		arrow.position = at + incoming * (1.0 - progress)
		arrow.rotation = -.18 * (1.0 - progress)
		arrow.scale = Vector2.ONE * width * .95 / 256.0
		if confirmed:
			arrow.scale *= 1.0 - smoothstep(.025, .20, age)
		arrow.modulate.a = smoothstep(0.0, .08, _clock)


func _draw() -> void:
	if closed:
		return
	var age := _clock - CONTACT
	if recipe.id == "a_reap" and _clock >= .18 and _clock < .53:
		_slash(age)
	if not confirmed:
		return
	match recipe.id:
		"g_hook":
			if hit:
				_burst(_contact_point, age, .17, Color("e5ae59"), true)
		"a_reap":
			if hit:
				_burst(_contact_point, age, .40 if empowered else .28, Color("8d6a8b"), true)
		"r_scatter":
			for at in destinations:
				_burst(
					at - point,
					age,
					.34 if at in hit_points else .19,
					Color("bc9358"),
					at in hit_points,
				)


func _slash(age: float) -> void:
	var progress := smoothstep(.18, .32, _clock)
	var fade := 1.0 - smoothstep(.34, .53, _clock)
	for layer in 2:
		var polygon := PackedVector2Array()
		var radius := Vector2(width * .62, width * .54)
		var center := Vector2(-width * .04, -width * .47)
		var thickness := (.16 if empowered and confirmed else .105) * fade * (
			1.0 if layer == 0 else .48
		)
		for i in 14:
			var u := float(i) / 13.0
			var angle := lerpf(-1.80, 1.15 * progress, u)
			polygon.append(
				center + Vector2(cos(angle), sin(angle)) * radius * (1.0 + thickness * sin(u * PI))
			)
		for i in range(13, -1, -1):
			var u := float(i) / 13.0
			var angle := lerpf(-1.80, 1.15 * progress, u)
			polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(polygon, Color("73506e") if layer == 0 else Color("fff1cf"))
	if age >= .10 and age < .46:
		for i in 3:
			var at := Vector2(width * (.45 + age * .50 + i * .13), -width * (.08 + i * .21))
			_diamond(at, width * .05 * (1.0 - smoothstep(.18, .46, age)), Color("664761"))


func _burst(at: Vector2, age: float, size_factor: float, shade: Color, struck: bool) -> void:
	if age < 0.0 or age > .40:
		return
	var cel := floorf(age * 30.0) / 30.0
	var size_value := width * size_factor * (1.0 - smoothstep(.04, .18, cel))
	if size_value > .01:
		var outline := [
			Vector2(-1, 0),
			Vector2(-.30, -.24),
			Vector2(-.78, -.84),
			Vector2(-.13, -.45),
			Vector2(.02, -1.32),
			Vector2(.23, -.43),
			Vector2(.83, -.94),
			Vector2(.49, -.20),
			Vector2(1.10, -.08),
			Vector2(.34, .15),
			Vector2(0, .32),
			Vector2(-.30, .12),
		]
		for layer in 2:
			var polygon := PackedVector2Array()
			for p: Vector2 in outline:
				polygon.append(
					at
					+ p * size_value * Vector2(1.0, .9 if struck else .48)
					* (1.0 if layer == 0 else .67)
				)
			draw_colored_polygon(polygon, shade if layer == 0 else Color("fff1cf"))
	for i in (5 if struck else 3):
		var direction := Vector2(cos(i * 2.39), sin(i * 2.39) * .55)
		var pos := at + direction * width * (.08 + age * .55) + Vector2(
			0,
			width * (age * age * 1.1 - age * .35),
		)
		_diamond(pos, width * .024 * (1.0 - smoothstep(.16, .40, age)), shade)


func _diamond(at: Vector2, size_value: float, shade: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array(
			[
				at + Vector2(0, -size_value),
				at + Vector2(size_value * .5, 0),
				at + Vector2(0, size_value * .7),
				at - Vector2(size_value * .5, 0),
			]
		),
		shade,
	)


func cancel() -> void:
	if closed:
		return
	if _moving and is_instance_valid(anchor):
		var unit: Unit = _target.get_ref()
		if (
			unit != null and unit.grid_pos == _destination_cell
			and anchor.global_position.is_equal_approx(_initial_position)
		):
			anchor.global_position = _movement_to
	_moving = false
	closed = true
	cancelled.emit()
	hide()
	queue_free()
