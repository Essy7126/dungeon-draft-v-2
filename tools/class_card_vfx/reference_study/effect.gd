extends Node2D
## Redrawn reference studies. Deterministic absolute-time sampling; no combat mutations.
var study := 0
var treatment := 0
var time := 0.0
var feedback := true
var released := false
var states: Array[String] = []
var state_pulse := 0.0
var actor: Texture2D
var atlas: Texture2D
var art_regions: Array = []
var standard_art: Texture2D
var standard_region: Array = []
const REGION := Rect2(4, 4, 452, 442)
const ACTOR_RECT := Rect2(-42.68, -95.48, 99.44, 97.24)
const DURATION := 2.4
const CONTACT := [0.72, 0.36, 0.48]
var ink := Color("133344")
var body := Color("28b7ce")
var shade := Color("16708e")
var light := Color("c8fff5")
var white := Color("f6fff4")


func sample(value: float) -> void:
	time = maxf(0.0, value)
	queue_redraw()


func phase() -> String:
	if study == 3:
		return "Maintien des états"
	if study == 2 and time > .72:
		return "Retrait demandé" if released else "Étendard maintenu"
	if time < CONTACT[study]:
		return "Suspension" if study == 0 else "Jaillissement" if study == 1 else "Apparition"
	if time < CONTACT[study] + .13:
		return "Contact"
	return "Retombée" if time < 1.65 else "Retour au calme"


func _palette() -> void:
	ink = Color(["114157", "112a35", "263a3b"][treatment])
	body = Color(["16b8ef", "168ec2", "719b91"][treatment])
	shade = Color(["0864ac", "075078", "345d61"][treatment])
	light = Color(["adfff6", "c4ffe3", "cdd6ac"][treatment])
	white = Color(["f1fff9", "faffdc", "f8ead0"][treatment])
	if study == 2:
		body = Color(["ffb039", "e8a53c", "cfa273"][treatment])
		shade = Color(["d94c1f", "933926", "86563c"][treatment])
		light = Color(["ffe08f", "fff1b4", "ede0be"][treatment])


func _draw() -> void:
	_palette()
	_ellipse(Vector2.ZERO, Vector2(32, 12), Color(0.02, .04, .04, .38))
	if study == 3:
		_status_ground()
	else:
		_ground()
	var recoil := 0.0
	if feedback and study < 2:
		var dt: float = time - CONTACT[study]
		if dt > 0.0 and dt < .24:
			recoil = sin(dt / .24 * PI) * (6.0 if study == 0 else 4.0)
	var flash: bool = (
		feedback and study < 2 and time >= CONTACT[study] and time < CONTACT[study] + .055
	)
	draw_set_transform(
		Vector2(recoil, 0),
		recoil * .012,
		Vector2(1.0 + recoil * .006, 1.0 - recoil * .004),
	)
	if actor:
		draw_texture_rect_region(
			actor,
			ACTOR_RECT,
			REGION,
			Color(1.55, 1.45, 1.2) if flash else Color.WHITE,
		)
	draw_set_transform(Vector2.ZERO)
	if study == 3:
		_status_front()
	elif study == 0:
		_celestial()
	elif study == 1:
		_water_hand()
	elif study == 2:
		_standard()


func _p(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(0, values.size(), 2):
		result.append(Vector2(float(values[i]), float(values[i + 1])))
	return result


func _shape(points: PackedVector2Array, color: Color, edge := false) -> void:
	if color.a <= 0.001 or points.size() < 3:
		return
	draw_colored_polygon(points, color)
	if edge:
		var border := points.duplicate()
		border.append(points[0])
		draw_polyline(border, Color(ink, color.a), 1.65 if treatment != 2 else 2.3, true)


func _ellipse(at: Vector2, radius: Vector2, color: Color) -> void:
	if minf(radius.x, radius.y) <= .01:
		return
	var points := PackedVector2Array()
	for i in 48:
		points.append(at + Vector2(cos(i * TAU / 48), sin(i * TAU / 48)) * radius)
	_shape(points, color)


func _ring(at: Vector2, radius: Vector2, width: float, color: Color, jagged := false) -> void:
	if minf(radius.x, radius.y) < .2 or color.a < .001:
		return
	# At birth and extinction the puddle can be narrower than its rim.
	# Keep the inner contour inside the outer contour instead of inverting it.
	width = minf(width, minf(radius.x, radius.y * 2.0) * .9)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 65:
		var angle := i * TAU / 64.0
		var irregular := 1.0 + sin(angle * 11 + .4) * .07 + sin(angle * 17) * .025 if jagged else 1.0
		var v := Vector2(cos(angle), sin(angle))
		outer.append(at + v * radius * irregular)
		inner.append(at + v * (radius - Vector2(width, width * .5)) * irregular)
	for i in 64:
		_shape(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]), color)


func _curve(points: Array, widths: Array, color: Color) -> void:
	var line := Curve2D.new()
	for i in points.size():
		var before: Vector2 = points[maxi(0, i - 1)]
		var after: Vector2 = points[mini(points.size() - 1, i + 1)]
		var tangent := (after - before) / 6.0
		line.add_point(points[i], -tangent, tangent)
	var samples := line.get_baked_points()
	if samples.size() < 3:
		return
	var front := PackedVector2Array()
	var back := PackedVector2Array()
	for i in samples.size():
		var u := float(i) / (samples.size() - 1)
		var w := lerpf(float(widths[0]), float(widths[1]), u) * sin(PI * u)
		var dir := (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]) \
				.normalized() \
				.orthogonal()
		front.append(samples[i] + dir * w)
		back.append(samples[i] - dir * w)
	back.reverse()
	front.append_array(back)
	_shape(front, color)


func _ground() -> void:
	var hit: float = CONTACT[study]
	var dt := time - hit
	if study == 2:
		if time > .24 and not released:
			var spread := clampf((time - .24) / .32, 0.0, 1.0)
			for cell in [
				Vector2(-1, -1),
				Vector2(0, -1),
				Vector2(1, -1),
				Vector2(-1, 0),
				Vector2(1, 0),
				Vector2(-1, 1),
				Vector2(0, 1),
				Vector2(1, 1),
			]:
				var at := Vector2(62 + (cell.x - cell.y) * 25, (cell.x + cell.y) * 12)
				draw_set_transform(at, 0, Vector2(.40, .20) * spread)
				_emblem(Color(body, .78))
				draw_set_transform(Vector2.ZERO)
		return
	if study == 1 and time > .1 and time < 1.65:
		var puddle := smoothstep(.1, .3, time) * (1.0 - smoothstep(1.1, 1.65, time))
		_ellipse(Vector2(0, -2), Vector2(32, 12) * puddle, Color(shade, .65))
		_ring(Vector2(0, -2), Vector2(37, 14) * puddle, 3, Color(body, .65), true)
	if dt < 0.0 or dt > .8:
		return
	var u := clampf(dt / .65, 0, 1)
	var radius := lerpf(18.0, 76.0 if study == 0 else 46.0, sqrt(u))
	_ellipse(Vector2.ZERO, Vector2(radius, radius * .43), Color(shade, .17 * (1.0 - u)))
	_ring(Vector2.ZERO, Vector2(radius, radius * .43), lerpf(9, 1, u), Color(body, 1.0 - u), true)
	_ring(Vector2.ZERO, Vector2(radius + 1, radius * .43 + .5), 1.8, Color(white, 1.0 - u), true)
	if study == 0:
		for i in 7:
			var a := i * TAU / 7 + .32
			var start := Vector2(cos(a) * 20, sin(a) * 8)
			var middle := Vector2(cos(a + .11) * 32, sin(a + .11) * 14)
			var end := Vector2(cos(a) * 48, sin(a) * 19)
			draw_polyline(
				PackedVector2Array([start, middle, end]),
				Color(ink, (1.0 - u) * .8),
				1.5,
				true,
			)


func _sword(tip: Vector2, size_value: Vector2, alpha: float, solid := false) -> void:
	draw_set_transform(tip, -.055 if solid else 0.0, size_value)
	_art(2 if solid else 0, 145.0 if solid else 125.0, alpha)
	draw_set_transform(Vector2.ZERO)


func _art(index: int, height: float, alpha: float) -> void:
	if atlas == null or alpha <= .001:
		return
	var r: Array = standard_region if index == 2 else art_regions[index]
	var source := Rect2(r[0], r[1], r[2], r[3])
	var width := height * source.size.x / source.size.y
	var whitening := 1.0 + smoothstep(.59, .69, time) * 2.5 if study == 0 else 1.0
	draw_texture_rect_region(
		standard_art if index == 2 else atlas,
		Rect2(-width * .5, -height, width, height),
		source,
		Color(whitening, whitening, whitening, alpha),
	)


func _celestial() -> void:
	if time <= .07 or time >= 1.72:
		return
	var dt := time - .72
	if time < .72:
		var appear := smoothstep(.12, .32, time)
		var drop := pow(clampf((time - .63) / .09, 0, 1), 2.2)
		var tip := Vector2(0, lerpf(-93, -4, drop))
		if time > .60:
			_shape(
				_p([-11, -205, 11, -205, 24, tip.y - 20, 0, tip.y + 4, -24, tip.y - 20]),
				Color(light, .45 * drop),
			)
		_sword(tip, Vector2(.70 + .08 * appear, .74 + .10 * appear), appear)
		if time < .60:
			var swirl := (time - .12) * 5.0
			_curve(
				[
					Vector2(-27 + swirl * 5, -158),
					Vector2(-33, -173 - swirl * 4),
					Vector2(-16 + swirl * 7, -185),
					Vector2(8 + swirl * 7, -188 + swirl * 3),
				],
				[1.7, .3],
				Color(light, appear * .75),
			)
	elif dt < .085:
		_shape(
			_p(
				[
					-6,
					-205,
					6,
					-205,
					14,
					-145,
					12,
					-84,
					23,
					-30,
					7,
					7,
					-7,
					7,
					-23,
					-30,
					-12,
					-84,
					-14,
					-145,
				]
			),
			white,
		)
		_burst(Vector2(0, -20), dt / .085, 66, white)
	else:
		var tail := 1.0 - smoothstep(.11, .7, dt)
		var curl := sin(dt * 9) * 14
		_curve(
			[
				Vector2(0, -5 - dt * 22),
				Vector2(-20 + curl, -65),
				Vector2(12 - curl, -114),
				Vector2(23 + dt * 17, -146 - dt * 15),
			],
			[11 * tail, 2.5 * tail],
			Color(body, tail),
		)
		_curve(
			[
				Vector2(-3, -12 - dt * 26),
				Vector2(5 + curl, -66),
				Vector2(-4 - curl, -102),
				Vector2(20 + dt * 17, -145 - dt * 15),
			],
			[4 * tail, 1 * tail],
			Color(light, tail),
		)
		_debris(dt, 0)
		_dust(dt, 0)


func _burst(at: Vector2, progress: float, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 28:
		var a := i * TAU / 28 + .17
		var r := radius * (1.0 if i % 2 == 0 else .26) * (1.0 - progress * .45)
		points.append(at + Vector2(cos(a), sin(a)) * r * Vector2(1.0, .75))
	_shape(points, color)


func _debris(dt: float, kind: int) -> void:
	if dt <= 0 or dt > .9:
		return
	for i in 11:
		var a := i * 2.399 + .2
		var speed := 38 + fmod(i * 19.0, 42.0)
		var x := cos(a) * speed * dt * 2
		var y := sin(a) * speed * dt * .5 - (60 + i * 4) * dt + 126 * dt * dt
		var s := (3.5 + fmod(i * 2.6, 5.0)) * (1.0 - smoothstep(.55, .9, dt))
		draw_set_transform(Vector2(x, y - 5), a + dt * (i - 4), Vector2.ONE * s)
		var rock := _p([-1, -.3, -.45, -1, .6, -.8, 1, .3, .1, 1, -.7, .7])
		_shape(rock, ink if kind == 0 else shade)
		_shape(_p([-1, -.3, -.45, -1, .6, -.8, .2, 0]), Color("698577") if kind == 0 else light)
		draw_set_transform(Vector2.ZERO)


func _dust(dt: float, kind: int) -> void:
	if dt < .06 or dt > .78:
		return
	var u := (dt - .06) / .72
	for i in 8:
		var a := i * TAU / 8 + .4
		var at := Vector2(cos(a) * (23 + u * 45), sin(a) * (10 + u * 17) - u * 12)
		var radius := Vector2(11 + u * 10, 6 + u * 6)
		var c := Color("9ba08a") if kind == 0 else body
		_ellipse(at, radius, Color(c, (1 - u) * .52))
		if treatment == 1:
			_ellipse(at + Vector2(-3, -3), radius * .6, Color(light, (1 - u) * .22))


func _water_hand() -> void:
	if time < .1 or time > 1.7:
		return
	var up := smoothstep(.14, .39, time)
	var fall := smoothstep(.63, .99, time)
	var height := up * (1 - fall)
	if height > .01:
		draw_set_transform(Vector2(0, -3), -.05, Vector2(1.0 + fall * .7, height))
		_art(1, 147.0, 1.0)
		draw_set_transform(Vector2.ZERO)
	if time > .22 and time < .48:
		var u := (time - .22) / .26
		for side in [-1, 1]:
			_curve(
				[Vector2(side * 25, 0), Vector2(side * 18, -72 * u), Vector2(side * 10, -186 * u)],
				[3, 1],
				Color(white, 1 - u * .5),
			)
	if time > .36:
		_debris(time - .36, 0)
	if time > .7:
		var u := (time - .7) / .85
		for i in 15:
			var a := i * 2.399
			var x := cos(a) * (18 + u * 49)
			var y := -22 - sin(i * 1.7) * 9 - 48 * u + 72 * u * u
			var s := (3 + fmod(i * 3.7, 4.0)) * (1 - smoothstep(.45, 1, u))
			draw_set_transform(Vector2(x, y), a * .2, Vector2(s, s * 1.5))
			_shape(
				_p([0, -1, .6, -.2, .7, .3, .2, .7, -.4, .5, -.6, 0]),
				light if i % 3 == 0 else body,
			)
			draw_set_transform(Vector2.ZERO)
		_dust(time - .7, 1)


func _emblem(color: Color) -> void:
	_shape(
		_p(
			[
				-4,
				24,
				-4,
				2,
				-20,
				5,
				-35,
				-5,
				-39,
				-19,
				-30,
				-11,
				-18,
				-8,
				-7,
				-12,
				-12,
				-23,
				-3,
				-18,
				0,
				-26,
				5,
				-17,
				13,
				-23,
				8,
				-12,
				22,
				-7,
				32,
				-12,
				40,
				-23,
				38,
				-6,
				22,
				5,
				5,
				2,
				5,
				24,
				0,
				34,
			]
		),
		color,
	)


func _standard() -> void:
	if time < .14 or released:
		return
	var settle := smoothstep(.14, .48, time)
	var tilt := sin(clampf((time - .48) / .18, 0, 1) * PI) * 3.0
	# The reference's object stays on its own cell, beside the actor.
	_sword(Vector2(62, -2 - (1 - settle) * 90), Vector2(.73, .80), settle, true)
	if time >= .48 and time < .78:
		_ring(
			Vector2(62, 0),
			Vector2(10 + (time - .48) * 100, 5 + (time - .48) * 45),
			3,
			Color(light, 1 - (time - .48) / .3),
			true,
		)
		_ellipse(Vector2(62, 2), Vector2(20 + tilt, 7), Color(ink, .32))


func _status_ground() -> void:
	if treatment == 0:
		return # The left comparison uses the actual production Player instead.
	if treatment == 1 and "Entrave" in states:
		_ring(Vector2.ZERO, Vector2(28, 11), 3, Color("adcba0"))
		for side in [-1, 1]:
			_curve(
				[Vector2(side * 26, 0), Vector2(side * 17, -18), Vector2(side * 19, -30)],
				[3, 1],
				Color("7d977d"),
			)


func _status_front() -> void:
	if treatment == 0:
		return
	if treatment == 1 and "Marque" in states:
		var p := Vector2(0, -108)
		draw_arc(p, 7, 0, TAU, 20, Color("f5c671"), 2, true)
		draw_line(p + Vector2(-11, 0), p + Vector2(11, 0), Color("f5c671"), 2, true)
	if state_pulse > 0 and "Brûlure" in states:
		_curve(
			[Vector2(17, -15), Vector2(11, -38), Vector2(20, -59)],
			[4, 1],
			Color(1, .48, .16, state_pulse),
		)
