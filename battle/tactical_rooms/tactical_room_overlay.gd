extends Node2D
var rules
var view: Node2D
var preview: Array[Vector2i] = []


func _draw() -> void:
	if rules == null or rules.boss == null:
		return
	var font := ThemeDB.fallback_font
	if rules.room_id == "reservoir" and rules.boss.is_alive:
		for index in 2:
			var center: Vector2 = view.grid_to_local(rules.RESERVOIRS[index])
			for slot in 6:
				draw_circle(
					center + Vector2((slot - 2.5) * 7, -23),
					2.5,
					Color("8cf3e0") if slot < rules.charges[index] else Color("445468"),
				)
			for actor in [rules.boss] + rules.carriers:
				if actor.is_alive and rules.grid.manhattan(actor.grid_pos, rules.RESERVOIRS[index]) <= 1:
					draw_dashed_line(
						center,
						view.grid_to_local(actor.grid_pos),
						Color("ef846d"),
						2,
						4,
					)
	if rules.room_id == "hourglass" and rules.skip_blast and rules.boss.is_alive:
		for cell: Vector2i in rules._cross(rules.mark):
			var center: Vector2 = view.grid_to_local(cell)
			draw_arc(center, 13, 0, TAU, 16, Color("eebc6b"), 2)
			draw_string(
				font,
				center + Vector2(-4, 4),
				"1",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color("eebc6b"),
			)
	if rules.room_id == "forge":
		for row in [1, 3, 5]:
			var from: Vector2 = view.grid_to_local(Vector2i(0, row))
			var to: Vector2 = view.grid_to_local(Vector2i(8, row))
			draw_line(from + Vector2(0, -5), to + Vector2(0, -5), Color("755435"), 2)
			draw_line(from + Vector2(0, 5), to + Vector2(0, 5), Color("755435"), 2)
	elif rules.room_id == "convoy" and rules.boss.is_alive:
		for carrier in rules.carriers:
			if not carrier.is_alive:
				continue
			var from: Vector2 = view.grid_to_local(carrier.grid_pos)
			if rules.grid.manhattan(carrier.grid_pos, rules.boss.grid_pos) <= 2:
				draw_dashed_line(
					from,
					view.grid_to_local(rules.boss.grid_pos),
					Color("ebce8e"),
					2,
					5,
				)
			if not rules.altar_sealed:
				draw_dashed_line(from, view.grid_to_local(rules.ALTAR), Color("82c8bc"), 1, 4)
	for cell in [
		Vector2i(2, 2),
		Vector2i(6, 2),
		Vector2i(2, 4),
		Vector2i(6, 4),
		Vector2i(3, 2),
		Vector2i(5, 2),
		Vector2i(3, 4),
		Vector2i(5, 4),
	]:
		if rules.grid.get_type(cell) != GridData.CellType.WALL:
			continue
		var point: Vector2 = view.grid_to_local(cell)
		draw_colored_polygon(
			PackedVector2Array(
				[
					point + Vector2(-18, 0),
					point + Vector2(0, 9),
					point + Vector2(0, -28),
					point + Vector2(-18, -37),
				]
			),
			Color("393e4a"),
		)
		draw_colored_polygon(
			PackedVector2Array(
				[
					point + Vector2(0, 9),
					point + Vector2(18, 0),
					point + Vector2(18, -37),
					point + Vector2(0, -28),
				]
			),
			Color("555d6a"),
		)
		draw_colored_polygon(
			PackedVector2Array(
				[
					point + Vector2(-18, -37),
					point + Vector2(0, -46),
					point + Vector2(18, -37),
					point + Vector2(0, -28),
				]
			),
			Color("939aaa"),
		)
	if rules.boss.is_alive:
		draw_arc(view.grid_to_local(rules.boss.grid_pos), 23, 0, TAU, 24, Color("f3ca79"), 3)
	for cell: Vector2i in rules.danger_cells():
		var center: Vector2 = view.grid_to_local(cell)
		var polygon := PackedVector2Array(
			[
				center + Vector2(-30, 0),
				center + Vector2(0, -15),
				center + Vector2(30, 0),
				center + Vector2(0, 15),
			]
		)
		draw_colored_polygon(polygon, Color(1, .25, .12, .48))
		draw_string(
			font,
			center + Vector2(-3, 4),
			"!",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color.WHITE,
		)
	for cell: Vector2i in rules.board_markers():
		var center: Vector2 = view.grid_to_local(cell)
		draw_arc(center, 17, 0, TAU, 24, Color("f3ca79"), 2)
		draw_string(
			font,
			center + Vector2(-5, 5),
			rules.board_markers()[cell],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color("f3ca79"),
		)
	for cell: Vector2i in rules.coins:
		draw_circle(view.grid_to_local(cell), 8, Color("8cf3e0"))
	for cell in preview:
		var center: Vector2 = view.grid_to_local(cell)
		var polygon := PackedVector2Array(
			[
				center + Vector2(-30, 0),
				center + Vector2(0, -15),
				center + Vector2(30, 0),
				center + Vector2(0, 15),
				center + Vector2(-30, 0),
			]
		)
		draw_polyline(polygon, Color("f5c551"), 3)
