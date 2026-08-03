class_name TacticalTelegraphLayer
extends Node2D

var _grid_view: Node2D = null
var _telegraphs: Dictionary = {}


func setup(grid_view: Node2D) -> void:
	_grid_view = grid_view
	if not EventBus.ability_telegraphed.is_connected(_on_telegraphed):
		EventBus.ability_telegraphed.connect(_on_telegraphed)
	if not EventBus.telegraph_cleared.is_connected(_on_cleared):
		EventBus.telegraph_cleared.connect(_on_cleared)


func _exit_tree() -> void:
	if EventBus.ability_telegraphed.is_connected(_on_telegraphed):
		EventBus.ability_telegraphed.disconnect(_on_telegraphed)
	if EventBus.telegraph_cleared.is_connected(_on_cleared):
		EventBus.telegraph_cleared.disconnect(_on_cleared)


func _on_telegraphed(caster: Unit, spell: Spell, payload: Dictionary) -> void:
	if caster == null or spell == null:
		return
	_telegraphs[caster] = {"spell": spell, "payload": payload}
	queue_redraw()


func _on_cleared(caster: Unit) -> void:
	_telegraphs.erase(caster)
	queue_redraw()


func get_telegraph_count() -> int:
	return _telegraphs.size()


func clear_all() -> void:
	_telegraphs.clear()
	queue_redraw()


func _cell_center(cell: Vector2i) -> Vector2:
	if _grid_view != null and _grid_view.has_method("grid_to_world"):
		return _grid_view.grid_to_world(cell)
	return Vector2(cell) * 64.0 + Vector2(32, 32)


func _draw() -> void:
	for caster_value in _telegraphs:
		var caster := caster_value as Unit
		var entry: Dictionary = _telegraphs[caster_value]
		var spell := entry.get("spell") as Spell
		var payload: Dictionary = entry.get("payload", {})
		if caster == null or spell == null:
			continue
		var color: Color = payload.get("color", Color.RED)
		var cell: Vector2i = payload.get("cell", Vector2i(-1, -1))
		var center := _cell_center(cell)
		var source := _cell_center(caster.grid_pos)
		draw_line(source, center, color, 5.0, true)
		if spell.is_summon():
			draw_circle(center, 27.0, Color(color, 0.22))
			draw_arc(center, 27.0, 0.0, TAU, 32, color, 4.0, true)
			draw_arc(center, 17.0, 0.0, TAU, 24, color.lightened(0.2), 3.0, true)
		else:
			draw_circle(center, 25.0, Color(color, 0.2))
			draw_arc(center, 25.0, 0.0, TAU, 28, color, 4.0, true)
			draw_line(center + Vector2(-12, -12), center + Vector2(12, 12), color, 4.0)
			draw_line(center + Vector2(12, -12), center + Vector2(-12, 12), color, 4.0)
		var label: String = payload.get("label", "Prochaine activation")
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-54, -34),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			108.0,
			14,
			color.lightened(0.25)
		)
