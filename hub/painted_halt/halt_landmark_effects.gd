extends Node2D
var hall


func _draw() -> void:
	if hall == null or hall.original or hall.player == null:
		return
	for landmark: Dictionary in hall.definition.landmarks:
		var point: Vector2 = hall.point(landmark.get("focus", landmark.point))
		var approach: Vector2 = hall.point(landmark.point)
		var near := clampf(1.0 - hall.player.position.distance_to(approach) / 260.0, 0.0, 1.0)
		var used: bool = hall.interactions != null and hall.interactions.awakened.has(
				str(landmark.id)
			)
		var power := maxf(near * 0.45, 0.85 if used else 0.0)
		var action := str(landmark.get("action", ""))
		if power < 0.01 or action not in ["sanctuary", "exit", "merchant"]:
			continue
		var color := Color("82e5bd") if action == "sanctuary" else Color("edbb61")
		var pulse := 0.92 + 0.08 * sin(hall.clock * (0.8 if hall.reduced else 1.8))
		for layer in 8:
			var radius := 10.0 + layer * 4.0
			var ring := PackedVector2Array()
			for i in 40:
				var angle := TAU * i / 40.0
				ring.append(point + Vector2(cos(angle), sin(angle) * 0.48) * radius)
			draw_colored_polygon(ring, Color(color, power * pulse * 0.012))
		if used:
			for i in 5:
				var age := fposmod(hall.clock * 0.2 + i * 0.2, 1.0)
				var at := point + Vector2(sin(i * 2.4 + age) * 22.0, -age * 65.0)
				draw_circle(at, 1.5, Color(color, sin(age * PI) * 0.5))
