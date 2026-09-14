class_name TacticalTelegraphLayer
extends Node2D

var _grid_view: Node2D = null
var _bound_grid: GridData = null
var _telegraphs: Dictionary = { }
var _tracked_unit_counts: Dictionary = { }
var _disposed := false
var _last_text_pixels_to_local := 1.0


func setup(grid_view: Node2D, bound_grid: GridData = null) -> void:
	_grid_view = grid_view
	_bound_grid = bound_grid
	_disposed = false
	_last_text_pixels_to_local = _local_pixels_per_screen_pixel()
	set_process(false)
	if not EventBus.ability_telegraphed.is_connected(_on_telegraphed):
		EventBus.ability_telegraphed.connect(_on_telegraphed)
	if not EventBus.telegraph_cleared.is_connected(_on_cleared):
		EventBus.telegraph_cleared.connect(_on_cleared)


func _exit_tree() -> void:
	dispose()


func dispose() -> void:
	if EventBus.ability_telegraphed.is_connected(_on_telegraphed):
		EventBus.ability_telegraphed.disconnect(_on_telegraphed)
	if EventBus.telegraph_cleared.is_connected(_on_cleared):
		EventBus.telegraph_cleared.disconnect(_on_cleared)
	_disconnect_all_tracked_units()
	_telegraphs.clear()
	_grid_view = null
	_bound_grid = null
	_disposed = true
	set_process(false)
	queue_redraw()


func _on_telegraphed(caster: Unit, spell: Spell, payload: Dictionary) -> void:
	if _disposed or caster == null or spell == null:
		return
	# During a scene transition, two battles may briefly receive the global
	# event. Only the layer owning the caster's grid may display it.
	if _bound_grid != null and caster.grid_context != _bound_grid:
		return
	if _telegraphs.has(caster):
		_untrack_entry(caster, _telegraphs[caster])
	_telegraphs[caster] = { "spell": spell, "payload": payload }
	_track_entry(caster, _telegraphs[caster])
	set_process(true)
	queue_redraw()


func _on_cleared(caster: Unit) -> void:
	if _disposed:
		return
	if _telegraphs.has(caster):
		_untrack_entry(caster, _telegraphs[caster])
	_telegraphs.erase(caster)
	if _telegraphs.is_empty():
		set_process(false)
	queue_redraw()


func get_telegraph_count() -> int:
	return _telegraphs.size()


func get_debug_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for caster_value in _telegraphs:
		var caster := caster_value as Unit
		var entry: Dictionary = _telegraphs[caster_value]
		var spell := entry.get("spell") as Spell
		var payload: Dictionary = entry.get("payload", { })
		if caster == null or spell == null:
			continue
		var target_cell: Vector2i = payload.get("cell", Vector2i(-1, -1))
		var tracked_target := payload.get("target") as Unit
		if tracked_target != null and tracked_target.is_alive:
			target_cell = tracked_target.grid_pos
		snapshot.append(
			{
				"spell_id": spell.get_effective_spell_id(),
				"source_cell": caster.grid_pos,
				"target_cell": target_cell,
				"source_position": _cell_center(caster.grid_pos),
				"target_position": _cell_center(target_cell),
				"label": str(payload.get("label", "Prochaine activation")),
			}
		)
	return snapshot


func clear_all() -> void:
	_disconnect_all_tracked_units()
	_telegraphs.clear()
	set_process(false)
	queue_redraw()


func _track_entry(caster: Unit, entry: Dictionary) -> void:
	_track_unit(caster)
	var payload: Dictionary = entry.get("payload", { })
	var target := payload.get("target") as Unit
	if target != caster:
		_track_unit(target)


func _untrack_entry(caster: Unit, entry: Dictionary) -> void:
	_untrack_unit(caster)
	var payload: Dictionary = entry.get("payload", { })
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


func _process(_delta: float) -> void:
	if _telegraphs.is_empty():
		set_process(false)
		return
	var current_pixels_to_local := _local_pixels_per_screen_pixel()
	if not is_equal_approx(current_pixels_to_local, _last_text_pixels_to_local):
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
		var payload: Dictionary = entry.get("payload", { })
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
		_draw_telegraph_label(
			center,
			str(payload.get("label", "Prochaine activation")),
			color.lightened(0.35),
		)


func _draw_telegraph_label(center: Vector2, label: String, color: Color) -> void:
	var lines := _telegraph_label_lines(label)
	var pixels_to_local := _local_pixels_per_screen_pixel()
	_last_text_pixels_to_local = pixels_to_local
	var baseline_offsets: Array[float] = []
	if lines.size() == 1:
		baseline_offsets.append(-34.0 * pixels_to_local)
	else:
		baseline_offsets.append(-49.0 * pixels_to_local)
		baseline_offsets.append(-32.0 * pixels_to_local)
	for index in lines.size():
		var screen_font_size := 15 if index == 0 else 13
		_draw_centered_label_line(
			center + Vector2(0.0, baseline_offsets[index]),
			lines[index],
			maxi(1, roundi(screen_font_size * pixels_to_local)),
			maxi(1, roundi(3.0 * pixels_to_local)),
			12.0 * pixels_to_local,
			color,
		)


func _draw_centered_label_line(
		baseline_center: Vector2,
		text: String,
		font_size: int,
		outline_size: int,
		horizontal_margin: float,
		color: Color,
	) -> void:
	var font := ThemeDB.fallback_font
	var width := ceilf(
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	) + horizontal_margin
	var position := baseline_center - Vector2(width * 0.5, 0.0)
	draw_string_outline(
		font,
		position,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		font_size,
		outline_size,
		Color(0.04, 0.035, 0.06, 0.95),
	)
	draw_string(
		font,
		position,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		font_size,
		color,
	)


func _local_pixels_per_screen_pixel() -> float:
	var screen_scale := get_global_transform_with_canvas().get_scale().abs()
	var uniform_scale := maxf(0.01, minf(screen_scale.x, screen_scale.y))
	return 1.0 / uniform_scale


static func _telegraph_label_lines(label: String) -> PackedStringArray:
	var separator_index := label.find(" — ")
	if separator_index < 0:
		return PackedStringArray([label.strip_edges()])
	return PackedStringArray(
		[
			label.left(separator_index).strip_edges(),
			label.substr(separator_index + 3).strip_edges(),
		]
	)
