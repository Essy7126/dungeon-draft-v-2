@tool
class_name EncounterMapPreview
extends Control

signal forbidden_cell_toggled(cell: Vector2i)

var room: RoomData = null
var preview := {}
var grid: GridData = null
var selected_cell := Vector2i(-1, -1)
var show_distances := true
var _background_texture: Texture2D = null
var _scale := 1.0
var _offset := Vector2.ZERO
var _logical_rect := Rect2()


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	tooltip_text = "Cliquez une case pour l'ajouter ou la retirer des cases interdites au déploiement ennemi."
	resized.connect(queue_redraw)


func set_context(value: RoomData, result: Dictionary) -> void:
	room = value
	preview = result
	grid = result.get("grid") as GridData
	# Le terrain existe avant son premier affrontement. Le résultat de placement
	# est alors volontairement vide, mais la grille reste reconstructible depuis
	# le brouillon Terrain et doit continuer à être affichée.
	if grid == null and room != null:
		grid = EncounterGridFactory.build_from_room(room)
	_background_texture = null
	if room != null and room.painted_map_visual_data != null:
		_background_texture = room.painted_map_visual_data.load_background_texture()
	elif room != null:
		_background_texture = room.background_image
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.05), true)
	if room == null or grid == null:
		_draw_centered_message("Sélectionnez une salle et générez un placement.")
		return
	_configure_projection()
	var visual := room.painted_map_visual_data
	if _background_texture != null:
		draw_texture_rect(
			_background_texture,
				Rect2(_offset + _logical_rect.position * _scale, _logical_rect.size * _scale),
				false,
				Color(0.82, 0.82, 0.82, 0.92),
			)
	for y in grid.rows:
		for x in grid.cols:
			var cell := Vector2i(x, y)
			var polygon := _cell_polygon(cell)
			var type := grid.get_type(cell)
			var fill := _terrain_color(type)
			if room.hero_spawn_zone.has(cell):
				fill = Color(0.12, 0.48, 1.0, 0.42)
			elif room.enemy_spawn_zone.has(cell):
				fill = Color(1.0, 0.48, 0.08, 0.34)
			draw_colored_polygon(polygon, fill)
			_draw_outline(polygon, Color(0.68, 0.75, 0.82, 0.28), 1.0)
	var encounter := _encounter()
	if encounter != null:
		for cell in encounter.forbidden_initial_spawn_cells:
			if not grid.is_valid(cell):
				continue
			var polygon := _cell_polygon(cell)
			draw_colored_polygon(polygon, Color(0.9, 0.08, 0.08, 0.42))
			draw_line(polygon[0], polygon[2], Color(1.0, 0.35, 0.35), 2.0)
			draw_line(polygon[1], polygon[3], Color(1.0, 0.35, 0.35), 2.0)
	for placement_value in preview.get("placements", []):
		var placement := placement_value as Dictionary
		var cell := placement.get("cell", Vector2i(-1, -1)) as Vector2i
		if not grid.is_valid(cell):
			continue
		var center := _cell_center(cell)
		var color := Color(0.24, 0.95, 0.54) if preview.get("valid", false) \
			else Color(1.0, 0.16, 0.16)
		draw_circle(center, clampf(12.0 * _scale, 7.0, 17.0), color, true)
		draw_circle(center, clampf(12.0 * _scale, 7.0, 17.0), Color.WHITE, false, 1.5)
		var marker := "%d" % (int(placement.get("order", 0)) + 1)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-4, 5),
			marker,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(0.02, 0.04, 0.03),
		)
	if show_distances:
		_draw_distance_legend()
	if selected_cell != Vector2i(-1, -1) and grid.is_valid(selected_cell):
		_draw_outline(_cell_polygon(selected_cell), Color.YELLOW, 3.0)
	_draw_legend()
	if _encounter() == null:
		_draw_empty_encounter_message()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		selected_cell = _position_to_cell(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		var cell := _position_to_cell(event.position)
		if grid != null and grid.is_valid(cell):
			forbidden_cell_toggled.emit(cell)


func visual_snapshot() -> Dictionary:
	return {
		"size": size,
		"grid_size": Vector2i(grid.cols, grid.rows) if grid != null else Vector2i.ZERO,
		"placement_count": (preview.get("placements", []) as Array).size(),
		"valid": preview.get("valid", false),
		"has_room": room != null,
	}


func _configure_projection() -> void:
	var padding := 20.0
	var visual := room.painted_map_visual_data
	if visual != null:
		_logical_rect = visual.image_rect()
	else:
		_logical_rect = Rect2(Vector2.ZERO, Vector2(grid.cols, grid.rows) * 48.0)
	if _logical_rect.size.x <= 0.0 or _logical_rect.size.y <= 0.0:
		_logical_rect = Rect2(Vector2.ZERO, Vector2.ONE)
	_scale = minf(
		maxf(0.01, (size.x - padding * 2.0) / _logical_rect.size.x),
		maxf(0.01, (size.y - padding * 2.0) / _logical_rect.size.y),
	)
	_offset = (size - _logical_rect.size * _scale) * 0.5 \
		- _logical_rect.position * _scale


func _cell_center(cell: Vector2i) -> Vector2:
	var visual := room.painted_map_visual_data
	if visual != null:
		return _offset + visual.cell_to_image(cell) * _scale
	var cell_size := _logical_rect.size / Vector2(grid.cols, grid.rows)
	return _offset + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size * _scale


func _cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var visual := room.painted_map_visual_data
	var result := PackedVector2Array()
	if visual != null:
		for point in visual.cell_polygon(cell):
			result.append(_offset + point * _scale)
		return result
	var cell_size := _logical_rect.size / Vector2(grid.cols, grid.rows)
	var position := _offset + Vector2(cell) * cell_size * _scale
	var scaled_size := cell_size * _scale
	return PackedVector2Array([
		position,
		position + Vector2(scaled_size.x, 0),
		position + scaled_size,
		position + Vector2(0, scaled_size.y),
	])


func _position_to_cell(position: Vector2) -> Vector2i:
	if room == null or grid == null:
		return Vector2i(-1, -1)
	var logical := (position - _offset) / _scale
	if room.painted_map_visual_data != null:
		return room.painted_map_visual_data.image_to_cell(logical)
	var cell_size := _logical_rect.size / Vector2(grid.cols, grid.rows)
	return Vector2i(floori(logical.x / cell_size.x), floori(logical.y / cell_size.y))


func _encounter() -> EncounterDefinition:
	if room == null:
		return null
	var wave_index := int(preview.get("wave_index", 0))
	return room.get_encounter_for_wave(wave_index)


func _terrain_color(type: GridData.CellType) -> Color:
	match type:
		GridData.CellType.WALL: return Color(0.2, 0.22, 0.25, 0.72)
		GridData.CellType.HOLE: return Color(0.02, 0.02, 0.025, 0.8)
		GridData.CellType.LAVA: return Color(0.94, 0.2, 0.04, 0.48)
		GridData.CellType.ICE: return Color(0.42, 0.82, 1.0, 0.4)
		GridData.CellType.SHADOW: return Color(0.3, 0.16, 0.48, 0.55)
		GridData.CellType.RUNE: return Color(0.64, 0.2, 0.92, 0.5)
	return Color(0.12, 0.18, 0.2, 0.28)


func _draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.is_empty():
		return
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


func _draw_centered_message(message: String) -> void:
	draw_string(
		ThemeDB.fallback_font, size * 0.5 - Vector2(180, 0), message,
		HORIZONTAL_ALIGNMENT_CENTER, 360, 16, Color(0.72, 0.78, 0.86)
	)


func _draw_empty_encounter_message() -> void:
	var panel_size := Vector2(minf(520.0, size.x - 40.0), 58.0)
	var panel_position := Vector2((size.x - panel_size.x) * 0.5, 16.0)
	draw_rect(
		Rect2(panel_position, panel_size), Color(0.015, 0.025, 0.04, 0.9), true
	)
	draw_string(
		ThemeDB.fallback_font,
		panel_position + Vector2(12.0, 23.0),
		"Terrain de la salle affiché en lecture seule",
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_size.x - 24.0,
		15,
		Color(0.55, 0.86, 1.0),
	)
	draw_string(
		ThemeDB.fallback_font,
		panel_position + Vector2(12.0, 45.0),
		"Créez le premier affrontement pour ajouter des ennemis.",
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_size.x - 24.0,
		13,
		Color(0.9, 0.93, 0.96),
	)


func _draw_legend() -> void:
	var text := "Bleu : zone alliée  •  Orange : zone ennemie préférée  •  Rouge : interdit  •  Vert : placement"
	draw_rect(Rect2(8, size.y - 30, minf(size.x - 16, 760), 24), Color(0.02, 0.03, 0.05, 0.88), true)
	draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.93, 0.96))


func _draw_distance_legend() -> void:
	var placements := preview.get("placements", []) as Array
	if placements.is_empty():
		return
	var row_height := 15.0
	var panel_width := minf(250.0, size.x * 0.42)
	var panel_height := 8.0 + row_height * placements.size()
	draw_rect(
		Rect2(8, 8, panel_width, panel_height),
		Color(0.015, 0.025, 0.04, 0.88), true
	)
	for placement_value in placements:
		var placement := placement_value as Dictionary
		var order := int(placement.get("order", 0))
		var unit := placement.get("unit_data") as UnitData
		var text := "%d. %s  •  distance %d" % [
			order + 1,
			unit.unit_name if unit != null else "Unité absente",
			int(placement.get("distance_to_ally_deployment", -1)),
		]
		draw_string(
			ThemeDB.fallback_font,
			Vector2(14, 22 + order * row_height),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			panel_width - 12,
			11,
			Color(1.0, 1.0, 0.84),
		)
