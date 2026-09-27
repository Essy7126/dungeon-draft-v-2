extends Node2D
## Blender object + independent cel contact/debris. A windup never fabricates a hit.
signal cancelled
const CONTACT := .5
const LENGTH := 1.6
const ART := "res://vfx/class_cards/sentence/hammer.png"
const MATERIAL := preload("hammer.gdshader")
static var texture_cache: Texture2D
var recipe: Dictionary = { }
var origin := Vector2.INF
var point := Vector2.ZERO
var width := 220.0
var anchor: Node2D
var elapsed := 0.0
var duration := LENGTH - CONTACT
var closed := false
var persistent := false
var badge_mode := false
var manual := false
var confirmed := false
var preparing := false
var full_sequence := false
var sprites: Array[Sprite2D] = []
var trails: Array[Polygon2D] = []
var _clock := 0.0


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
	preparing = bool(entry.get("sentence_preparing", false))
	full_sequence = preparing
	confirmed = not preparing
	duration = LENGTH if preparing else LENGTH - CONTACT
	var sprite := Sprite2D.new()
	if texture_cache == null:
		texture_cache = load(ART) as Texture2D
	sprite.texture = texture_cache
	sprite.show_behind_parent = true
	sprite.hframes = 8
	sprite.vframes = 6
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.offset = Vector2(0, -99.4289)
	var mat := ShaderMaterial.new()
	mat.shader = MATERIAL
	sprite.material = mat
	add_child(sprite)
	sprites.append(sprite)
	for shade in [Color("e99b35"), Color("fff0bf")]:
		var trail := Polygon2D.new()
		trail.z_index = -1
		trail.color = shade
		add_child(trail)
		trails.append(trail)
	z_index = 4
	sample(0.0)


func confirm() -> void:
	if closed or confirmed:
		return
	confirmed = true
	preparing = false
	elapsed = CONTACT
	sample(elapsed)


func _process(delta: float) -> void:
	if manual or closed:
		return
	sample(elapsed + delta)
	# A missing/failed confirmation releases the suspended object without an impact.
	if (preparing and elapsed > CONTACT + .35) or (confirmed and elapsed >= duration):
		cancel()


func sample(time: float) -> void:
	elapsed = maxf(time, 0.0)
	_clock = elapsed if full_sequence else elapsed + CONTACT
	if preparing:
		_clock = minf(_clock, CONTACT - 1.0 / 30.0)
	global_position = point
	for sprite in sprites:
		sprite.frame = clampi(int((_clock + .00001) * 30.0), 0, 47)
		sprite.scale = Vector2.ONE * width / 384.0
		sprite.visible = not closed and _clock < LENGTH
		var material := sprite.material as ShaderMaterial
		material.set_shader_parameter(
			"contact_light",
			.38 * (1.0 - smoothstep(0.0, .08, _clock - CONTACT)) if confirmed else 0.0,
		)
		material.set_shader_parameter("withdrawal", smoothstep(.63, .99, _clock) * 1.13 - .12)
	for trail in trails:
		trail.visible = not closed and full_sequence and _clock >= .40 and _clock < CONTACT
	if not trails.is_empty() and trails[0].visible:
		var u := inverse_lerp(.40, CONTACT, _clock)
		var tip := Vector2(-width * .06, -width * (.12 + .55 * (1.0 - u)))
		var tail := Vector2(-width * .23, -width * .73)
		var side := (tip - tail).normalized().orthogonal() * width
		trails[0].polygon = PackedVector2Array([tail, tip + side * .036, tip - side * .016])
		trails[1].polygon = PackedVector2Array([tail, tip + side * .021, tip])
	queue_redraw()


func _draw() -> void:
	if closed or not confirmed or _clock < CONTACT:
		return
	# Contact is sampled on twos; the flying fragments keep continuous trajectories.
	var t := maxf(0.0, _clock - CONTACT)
	var cel_time := floorf((t + .00001) * 15.0) / 15.0
	_ground_pressure(t)
	_contact_flash(cel_time)
	_chips(t)


func _shape(points: Array, at: Vector2, scale_value: Vector2, shade: Color) -> void:
	var polygon := PackedVector2Array()
	for p: Vector2 in points:
		polygon.append(at + p * scale_value)
	draw_colored_polygon(polygon, shade)


func _contact_flash(t: float) -> void:
	var center := Vector2(0, -width * .065)
	# A compressed, asymmetric burst follows the striking sole, with a short ivory core.
	if t < .13:
		var points := [
			Vector2(-1, -.04),
			Vector2(-.45, -.23),
			Vector2(-.66, -.68),
			Vector2(-.19, -.39),
			Vector2(-.12, -1.20),
			Vector2(.08, -.38),
			Vector2(.48, -.88),
			Vector2(.39, -.22),
			Vector2(1, -.14),
			Vector2(.55, .12),
			Vector2(.73, .38),
			Vector2(.19, .24),
			Vector2(-.03, .51),
			Vector2(-.27, .21),
			Vector2(-.82, .32),
			Vector2(-.53, .10),
		]
		var size_value := Vector2(width * (.25 + t * .35), width * (.085 - t * .17))
		_shape(points, center + Vector2(0, width * .009), size_value * 1.10, Color("703727"))
		_shape(points, center, size_value, Color("eda137"))
		_shape(points, center, size_value * Vector2(.73, .70), Color("fff1bb"))
		if t < .06:
			_shape(points, center, size_value * Vector2(.43, .39), Color("fffdf0"))
	# Four short, tapered flecks split off as the main flash disappears.
	if t >= .06 and t < .20:
		for i in 4:
			var side := -1.0 if i % 2 == 0 else 1.0
			var angle := -.22 - (i / 2) * .58
			var direction := Vector2(side * cos(angle), sin(angle))
			var at := center + direction * width * (.15 + t * .63)
			var length_value := width * .08 * (1.0 - smoothstep(.07, .20, t))
			var across := direction.orthogonal() * width * .009
			draw_colored_polygon(
				PackedVector2Array(
					[
						at + direction * length_value,
						at + across,
						at - direction * length_value * .45,
						at - across,
					]
				),
				Color("ffe5a1"),
			)


func _ground_pressure(t: float) -> void:
	# Two broken arcs compress against the floor, then open sideways; never a full halo.
	if t < .29:
		var u := smoothstep(0.0, .29, t)
		for side in [-1.0, 1.0]:
			var at := Vector2(side * width * (.06 + u * .20), width * .006)
			var size_value := Vector2(side * width * (.20 - u * .06), width * .045 * (1.0 - u))
			var arc := [
				Vector2(-.55, .12),
				Vector2(.30, -.85),
				Vector2(.91, -.38),
				Vector2(1.1, .25),
				Vector2(.60, -.05),
				Vector2(.22, -.26),
			]
			_shape(arc, at + Vector2(0, width * .006), size_value * 1.13, Color("383842"))
			_shape(arc, at, size_value, Color("dda55d"))
	# Just two low dust tongues; they shrink before they can hide the target's state.
	if t >= .065 and t < .40:
		var u := inverse_lerp(.065, .40, t)
		var life := sin(u * PI)
		for side in [-1.0, 1.0]:
			var at := Vector2(side * width * (.14 + .12 * u), width * .018)
			var size_value := Vector2(side * width * .075, width * .032) * life
			var dust := [
				Vector2(-1, 0),
				Vector2(-.70, -.63),
				Vector2(-.25, -.72),
				Vector2(.04, -1.18),
				Vector2(.61, -.85),
				Vector2(.75, -.34),
				Vector2(1.1, -.10),
				Vector2(.72, .26),
				Vector2(-.18, .31),
			]
			_shape(dust, at, size_value, Color("99704a"))
			_shape(dust, at + Vector2(0, -width * .006 * life), size_value * .72, Color("d8b777"))


func _chips(t: float) -> void:
	# Six faceted chips, fixed trajectories and one low bounce; no gameplay RNG.
	for i in 6:
		var age := t - .018 - (i % 3) * .012
		if age < 0.0 or age >= .62:
			continue
		var side := -1.0 if i % 2 == 0 else 1.0
		var speed := .32 + (i % 3) * .095
		var flight := .30 + (i % 3) * .055
		var height := 1.9 * age * (age - flight)
		if age > flight:
			var bounce := age - flight
			height = minf(0.0, 2.2 * bounce * (bounce - .13))
		var at := Vector2(side * width * (.055 + speed * minf(age, flight + .13)), width * height)
		var size_value := width * (.018 + (i % 3) * .006) * (1.0 - smoothstep(.42, .62, age))
		var points := PackedVector2Array()
		for corner in [
			Vector2(-1, -.4),
			Vector2(-.25, -.95),
			Vector2(.64, -.60),
			Vector2(1, .3),
			Vector2(-.4, .8),
		]:
			points.append(at + corner.rotated(age * (3.2 + i) * side) * size_value)
		draw_colored_polygon(points, Color("3a4148"))
		draw_colored_polygon(
			PackedVector2Array([points[0], points[1], points[2], at]),
			Color("cf9b54"),
		)
		draw_colored_polygon(PackedVector2Array([at, points[2], points[3]]), Color("855638"))


func cancel() -> void:
	if closed:
		return
	closed = true
	cancelled.emit()
	hide()
	queue_free()
