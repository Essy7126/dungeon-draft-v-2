extends Node2D

## Separate overlay: low green palms, chest burst and a red ribbon toward the opponent.
var lab: Node2D


func _ready() -> void:
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend


func _halo(point: Vector2, radius: float, color: Color, strength: float) -> void:
	for i in range(10, 0, -1):
		var shade := color
		shade.a = strength * (0.025 + float(10 - i) * 0.008)
		draw_circle(point, radius * float(i) / 10.0, shade)


func _point(pixel: Array, lift: float) -> Vector2:
	return lab.actor_position + (Vector2(pixel[0], pixel[1]) - Vector2(320, 662 + lift)) * 0.55


func _bezier(energy: Dictionary, t: float) -> Vector2:
	var v := 1.0 - t
	return Vector2(energy.start) * v * v + Vector2(energy.control) * 2 * v * t + Vector2(energy.end) * t * t


func _draw() -> void:
	if lab == null or not lab.fx_enabled:
		return
	if not lab.active.is_empty() and lab.active.spell.mode == "vital":
		var definition: Dictionary = lab.active.spell
		var config: Dictionary = definition.vfx
		var time := float(lab.active.time)
		var phase := int(lab.actor.frame)
		var lift: float = lab._spell_lift(definition, time)
		var strength := float(config.palm_strength[phase])
		for palm: Array in config.palms[phase]:
			var p := _point(palm, lift)
			_halo(p, 10 + sin(time * 11) * 0.7, Color("64dc89"), strength)
			draw_circle(p, 1.7, Color(0.77, 1.0, 0.75, strength * 0.7))
		if time > 0.18 and time < 0.9:
			var build := (
				minf(1, (time - 0.18) / 0.44)
				if time < 0.62
				else maxf(0, 1 - (time - 0.62) / 0.28)
			)
			var chest := _point(config.chest[phase], lift)
			_halo(chest, (15 + build * 18) * 0.55, Color("d43e53"), build)
			_halo(chest, 3.3, Color("ffd0b4"), build)
	for energy: Dictionary in lab.vital_projectiles:
		var t := minf(1, float(energy.age) / float(energy.duration))
		var tail := maxf(0, t - 0.58)
		if t < 0.001:
			continue
		for ribbon in range(3):
			var points := PackedVector2Array()
			for i in range(21):
				var f := float(i) / 20.0
				var u := lerpf(tail, t, f)
				var point := _bezier(energy, u)
				point.y += sin(u * 18 - float(energy.age) * 9 + ribbon * 2.1) * (1 - f) * (
					3 + ribbon * 3
				)
				points.append(point)
			var polygon := PackedVector2Array()
			var colors := PackedColorArray()
			for side in range(2):
				for k in range(21):
					var i := k if side == 0 else 20 - k
					var f := float(i) / 20.0
					var tangent := points[mini(i + 1, 20)] - points[maxi(i - 1, 0)]
					var normal := tangent.normalized().orthogonal()
					var width := ((16 if ribbon == 0 else 4) * f + 1) * 0.5
					polygon.append(points[i] + normal * width * (1 if side == 0 else -1))
					colors.append(
						(
							Color(0.78, 0.14, 0.25, 0.15 + f * 0.5)
							if ribbon == 0
							else Color(
								0.94,
								float(77 + ribbon * 20) / 255.0,
								float(86 + ribbon * 20) / 255.0,
								f * 0.65,
							)
						)
					)
			draw_polygon(polygon, colors)
		var head := _bezier(energy, t)
		_halo(head, 17, Color("d43952"), 0.8)
		_halo(head, 6, Color("ffc3a0"), 1.2)
	for burst: Dictionary in lab.vital_bursts:
		var u := float(burst.age) / float(burst.life)
		var fade := 1 - u
		var p: Vector2 = burst.position
		_halo(p, 12 + u * (48 if burst.impact else 35), Color("d13851"), fade)
		for i in range(7):
			var angle := float(i) * 2.399 + (0.0 if burst.impact else 0.3)
			var radius := 6 + u * 38
			var previous := p + Vector2.from_angle(angle) * radius * 0.35
			for j in range(1, 7):
				var t := float(j) / 6.0
				var v := 1 - t
				var point := p + (
					Vector2.from_angle(angle) * 0.35 * v * v
					+ Vector2.from_angle(angle + 0.24) * 2 * v * t
					+ Vector2.from_angle(angle + 0.4) * 0.9 * t * t
				) * radius
				draw_line(previous, point, Color(0.95, 0.4, 0.44, fade * 0.8), 2.5 * fade + 1, true)
				previous = point
		_halo(p, 9 * fade + 1, Color("ffb9a2"), fade * 1.1)
