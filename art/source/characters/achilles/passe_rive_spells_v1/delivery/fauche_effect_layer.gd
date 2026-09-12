extends Node2D

## Blade-bound wake in two layers, sharing the timings and tip positions with the browser.
var lab: Node2D
var front: bool = true


func _draw() -> void:
	if not is_instance_valid(lab) or not lab.fx_enabled or lab.active.is_empty():
		return
	var spell: Dictionary = lab.active.spell
	if not spell.has("sweep_trail"):
		return
	var cfg: Dictionary = spell.sweep_trail
	var ms: float = float(lab.active.time) * 1000.0
	var start_ms: float = 0.0
	var pivot := Vector2(spell.pivot[0], spell.pivot[1])
	draw_set_transform(lab.actor_position - pivot * 0.55, 0.0, Vector2.ONE * 0.55)
	for i in range(1, 6):
		start_ms += float(spell.frames[i - 1].duration_ms)
		var age := ms - start_ms
		if age < 0 or age >= float(cfg.tail_ms) or front != (i >= 4):
			continue
		var a := Vector2(cfg.tips[i - 1][0], cfg.tips[i - 1][1])
		var b := Vector2(cfg.tips[i][0], cfg.tips[i][1])
		var control := (a + b) * 0.5 + Vector2(18, -15)
		if i == 1:
			control = Vector2((a.x + b.x) * 0.5, minf(a.y, b.y) - 155)
		elif i == 4:
			control = Vector2(a.x + 35, b.y + 70)
		elif i == 5:
			control = Vector2((a.x + b.x) * 0.5, maxf(a.y, b.y) + 85)
		var fade := pow(1.0 - age / float(cfg.tail_ms), 1.4)
		var width := 26.0 if i >= 3 else 16.0
		var points := PackedVector2Array()
		for j in range(29):
			var u := float(j) / 28.0
			points.append(a * (1 - u) * (1 - u) + control * 2 * u * (1 - u) + b * u * u)
		_ribbon(points, width * 1.6 * fade, Color(0.4, 0.8, 0.68, 0.12 * fade))
		_ribbon(points, width * fade, Color(0.62, 0.89, 0.78, 0.42 * fade))
		_ribbon(points, width * 0.22 * fade, Color(0.93, 0.97, 0.83, 0.8 * fade))


func _ribbon(points: PackedVector2Array, width: float, color: Color) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(points.size()):
		var previous := points[maxi(0, i - 1)]
		var next := points[mini(points.size() - 1, i + 1)]
		var normal := (next - previous).normalized().orthogonal()
		var w := sin(PI * float(i) / float(points.size() - 1)) * width
		left.append(points[i] + normal * w)
		right.append(points[i] - normal * w)
	for i in range(right.size() - 1, -1, -1):
		left.append(right[i])
	draw_colored_polygon(left, color)
