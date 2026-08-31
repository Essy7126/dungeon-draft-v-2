class_name TacticalTelegraphLayer
extends Node2D

var _grid_view: Node2D = null
var _telegraphs: Dictionary = {}
var _tracked_unit_counts: Dictionary = {}


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
	_disconnect_all_tracked_units()


func _on_telegraphed(caster: Unit, spell: Spell, payload: Dictionary) -> void:
	if caster == null or spell == null:
		return
	if _telegraphs.has(caster):
		_untrack_entry(caster, _telegraphs[caster])
	_telegraphs[caster] = {"spell": spell, "payload": payload}
	_track_entry(caster, _telegraphs[caster])
	queue_redraw()


func _on_cleared(caster: Unit) -> void:
	if _telegraphs.has(caster):
		_untrack_entry(caster, _telegraphs[caster])
	_telegraphs.erase(caster)
	queue_redraw()


func get_telegraph_count() -> int:
	return _telegraphs.size()


func clear_all() -> void:
	_disconnect_all_tracked_units()
	_telegraphs.clear()
	queue_redraw()


func _track_entry(caster: Unit, entry: Dictionary) -> void:
	_track_unit(caster)
	var payload: Dictionary = entry.get("payload", {})
	var target := payload.get("target") as Unit
	if target != caster:
		_track_unit(target)


func _untrack_entry(caster: Unit, entry: Dictionary) -> void:
	_untrack_unit(caster)
	var payload: Dictionary = entry.get("payload", {})
	var target := payload.get("target") as Unit
	if target != caster:
		_untrack_unit(target)


func _track_unit(unit: Unit) -> void:
	if unit == null:
		return
	var count := int(_tracked_unit_counts.get(unit, 0))
	_tracked_unit_counts[unit] = count + 1
	if count == 0 and not unit.moved.is_connected(_on_tracked_unit_moved):
		unit.moved.connect(_on_tracked_unit_moved)


func _untrack_unit(unit: Unit) -> void:
	if unit == null or not _tracked_unit_counts.has(unit):
		return
	var count := int(_tracked_unit_counts[unit]) - 1
	if count > 0:
		_tracked_unit_counts[unit] = count
		return
	_tracked_unit_counts.erase(unit)
	if unit.moved.is_connected(_on_tracked_unit_moved):
		unit.moved.disconnect(_on_tracked_unit_moved)


func _disconnect_all_tracked_units() -> void:
	for unit_value in _tracked_unit_counts:
		var unit := unit_value as Unit
		if unit != null and unit.moved.is_connected(_on_tracked_unit_moved):
			unit.moved.disconnect(_on_tracked_unit_moved)
	_tracked_unit_counts.clear()


func _on_tracked_unit_moved(_from_cell: Vector2i, _to_cell: Vector2i) -> void:
	if not _telegraphs.is_empty():
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
		var tracked_target := payload.get("target") as Unit
		if tracked_target != null and tracked_target.is_alive:
			cell = tracked_target.grid_pos
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
