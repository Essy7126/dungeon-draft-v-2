extends Control
signal cell_clicked(cell: Vector2i)
const Combat = preload("res://tools/charon_workshop/charon_combat.gd")
var combat: Combat
var selected_spell: Spell
var preview: Array[Vector2i] = []
var hovered := Vector2i(-1, -1)
const GOLD := Color("eac27b")
const TEAL := Color("79dfcf")


func _cell_size() -> float:
	return minf((size.x - 32) / 9.0, (size.y - 32) / 7.0)


func _origin() -> Vector2:
	return (size - Vector2(9, 7) * _cell_size()) / 2


func _gui_input(event: InputEvent) -> void:
	if combat == null:
		return
	if event is InputEventMouse:
		var cell := Vector2i(((event.position - _origin()) / _cell_size()).floor())
		hovered = cell
		if combat.grid.is_valid(cell):
			var actor: Unit = combat.grid.get_unit(cell)
			tooltip_text = (
				"%s · %d/%d PV · %d bouclier"
				% [actor.unit_name, actor.current_hp, actor.max_hp.get_int(), actor.current_shield]
				if actor != null
				else "Case (%d, %d)" % [cell.x, cell.y]
			)
			if cell in combat.TERMINALS:
				tooltip_text += "\nBorne : sur cette case ou à côté, 1 PA + 1 obole."
			if (
				event is InputEventMouseButton and event.pressed
				and event.button_index == MOUSE_BUTTON_LEFT
			):
				cell_clicked.emit(cell)
		queue_redraw()


func _draw() -> void:
	if combat == null or combat.grid == null:
		return
	var cell_size := _cell_size()
	var origin := _origin()
	var font := ThemeDB.fallback_font
	var targets: Array = []
	var reachable: Array = []
	if combat.player_turn and combat.outcome.is_empty():
		if selected_spell != null:
			targets = combat.caster.get_targetable_cells(combat.hero, selected_spell)
		else:
			reachable = combat.pathfinder.get_reachable(
				combat.hero.grid_pos,
				combat.hero.current_mp,
				combat.hero,
			)
	var danger: Array = combat.pending.get("cells", [])
	if not combat.pending.is_empty() and combat.boss.grid_pos != combat.pending.origin:
		danger = []
	for y in 7:
		for x in 9:
			var cell := Vector2i(x, y)
			var rect := Rect2(
				origin + Vector2(cell) * cell_size + Vector2(2, 2),
				Vector2.ONE * (cell_size - 4),
			)
			var walkable := combat.grid.is_terrain_interactable(cell)
			var color := Color("233a42") if walkable else Color("0b1a28")
			if cell in reachable:
				color = Color("2c5559")
			if cell in danger:
				color = Color("803f38")
			if combat.pending.get("gate", false) and cell in danger:
				color = Color("474e44")
			if cell in preview:
				color = Color("9b713e")
			if cell in targets:
				color = color.lightened(0.14)
			draw_rect(rect, color)
			if cell == hovered:
				draw_rect(rect, TEAL, false, 2)
			if cell in combat.TERMINALS:
				draw_rect(rect.grow(-4), GOLD, false, 2)
				draw_string(
					font,
					rect.position + Vector2(7, 17),
					"B",
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					15,
					GOLD,
				)
			if combat.coins.has(cell):
				draw_circle(rect.get_center(), 9, GOLD)
				draw_string(
					font,
					rect.get_center() + Vector2(-4, 5),
					"o",
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					15,
					Color("13212a"),
				)
			var actor: Unit = combat.grid.get_unit(cell)
			if actor != null:
				var ink := (
					TEAL
					if actor == combat.hero
					else (GOLD
						if actor == combat.boss
						else Color("cf9caf"))
				)
				var center := rect.get_center() - Vector2(0, 5)
				draw_circle(center, cell_size * .23, Color("101e29"))
				draw_arc(center, cell_size * .23, 0, TAU, 28, ink, 2, true)
				var initial := "A" if actor == combat.hero else "C" if actor == combat.boss else "P"
				draw_string(
					font,
					center + Vector2(-6, 6),
					initial,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					18,
					ink,
				)
				draw_string(
					font,
					rect.position + Vector2(4, rect.size.y - 5),
					str(actor.current_hp),
					HORIZONTAL_ALIGNMENT_CENTER,
					rect.size.x - 8,
					14,
					Color.WHITE,
				)
				var bar := Rect2(
					rect.position + Vector2(4, rect.size.y - 3),
					Vector2((rect.size.x - 8) * actor.get_hp_ratio(), 2),
				)
				draw_rect(bar, ink)
	if not danger.is_empty():
		var from := origin + (Vector2(combat.pending.origin) + Vector2(.5, .5)) * cell_size
		var to := origin + (Vector2(danger.back()) + Vector2(.5, .5)) * cell_size
		draw_line(from, to, Color(1, .62, .43, .65), 3, true)
