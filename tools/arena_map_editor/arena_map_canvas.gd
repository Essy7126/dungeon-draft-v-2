class_name ArenaMapCanvas
extends Node2D

signal stroke_started()
signal stroke_finished()
signal paint_requested(cell: Vector2i, erase: bool)
signal eyedrop_requested(cell: Vector2i)
signal hovered_cell_changed(cell: Vector2i)

const INVALID_CELL := Vector2i(-1, -1)
const NORMALIZED_TILE_SIZE := Vector2(256, 128)
const TILE_SCALE := Vector2(64, 32) / NORMALIZED_TILE_SIZE
const WALL_SCENE := preload("res://tools/arena_map_editor/EditorWallPreview.tscn")

const TILE_TEXTURES := {
	ArenaMapDocument.BaseTile.STONE: preload("res://tools/labs/dynamic_arena/assets/normalized/stone.png"),
	ArenaMapDocument.BaseTile.WATER: preload("res://tools/labs/dynamic_arena/assets/normalized/water.png"),
	ArenaMapDocument.BaseTile.ICE: preload("res://tools/labs/dynamic_arena/assets/normalized/ice.png"),
	ArenaMapDocument.BaseTile.LAVA: preload("res://tools/labs/dynamic_arena/assets/normalized/lava.png"),
	ArenaMapDocument.BaseTile.SHADOW: preload("res://tools/labs/dynamic_arena/assets/normalized/stone.png"),
	ArenaMapDocument.BaseTile.RUNE: preload("res://tools/labs/dynamic_arena/assets/normalized/stone.png"),
}

const SURFACE_TEXTURES := {
	ArenaMapDocument.SurfaceEffect.FIRE: preload("res://tools/labs/dynamic_arena/assets/normalized/lava.png"),
	ArenaMapDocument.SurfaceEffect.WATER: preload("res://tools/labs/dynamic_arena/assets/normalized/water.png"),
	ArenaMapDocument.SurfaceEffect.ICE: preload("res://tools/labs/dynamic_arena/assets/normalized/ice.png"),
}

const BASE_TINTS := {
	ArenaMapDocument.BaseTile.STONE: Color.WHITE,
	ArenaMapDocument.BaseTile.WATER: Color(0.82, 0.96, 1, 1),
	ArenaMapDocument.BaseTile.ICE: Color(0.9, 0.98, 1, 1),
	ArenaMapDocument.BaseTile.LAVA: Color(1, 0.88, 0.76, 1),
	ArenaMapDocument.BaseTile.SHADOW: Color(0.32, 0.25, 0.48, 1),
	ArenaMapDocument.BaseTile.RUNE: Color(0.72, 0.36, 0.88, 1),
}

const LOGIC_COLORS := {
	ArenaMapDocument.BaseTile.VOID: Color("11141c"),
	ArenaMapDocument.BaseTile.STONE: Color("8e9aa8"),
	ArenaMapDocument.BaseTile.WATER: Color("31b9df"),
	ArenaMapDocument.BaseTile.ICE: Color("b9efff"),
	ArenaMapDocument.BaseTile.LAVA: Color("f05b32"),
	ArenaMapDocument.BaseTile.SHADOW: Color("49306d"),
	ArenaMapDocument.BaseTile.RUNE: Color("b24bda"),
}

enum DisplayMode {
	EDITOR,
	REFERENCE,
	LOGIC,
	DEBUG,
}

@onready var floor_layer: Node2D = $FloorLayer
@onready var surface_layer: Node2D = $SurfaceLayer
@onready var y_sorted_world: Node2D = $YSortedWorld
@onready var marker_layer: Node2D = $YSortedWorld/MarkerLayer
@onready var grid_view: IsoGridView = $GridDebug

var document: ArenaMapDocument = null
var grid: GridData = null
var editor_camera: Camera2D = null
var editor_input_enabled := true
var display_mode := DisplayMode.EDITOR
var selected_cell := INVALID_CELL
var hovered_cell := INVALID_CELL

var _cell_visuals: Dictionary = {}
var _painting := false
var _erasing := false
var _panning := false


func configure(map_document: ArenaMapDocument) -> void:
	if document != null:
		if document.changed.is_connected(_on_document_cell_changed):
			document.changed.disconnect(_on_document_cell_changed)
		if document.resized.is_connected(_on_document_resized):
			document.resized.disconnect(_on_document_resized)
		if document.reset_completed.is_connected(_on_document_reset):
			document.reset_completed.disconnect(_on_document_reset)
	document = map_document
	grid = GridData.new(document.grid_size.x, document.grid_size.y)
	grid_view.setup(grid)
	grid_view.set_process_unhandled_input(false)
	document.changed.connect(_on_document_cell_changed)
	document.resized.connect(_on_document_resized)
	document.reset_completed.connect(_on_document_reset)
	_rebuild_all()


func set_editor_camera(camera: Camera2D) -> void:
	editor_camera = camera


func set_display_mode(mode: int) -> void:
	display_mode = clampi(mode, DisplayMode.EDITOR, DisplayMode.DEBUG)
	var show_visuals := display_mode != DisplayMode.LOGIC
	floor_layer.visible = show_visuals
	surface_layer.visible = show_visuals
	y_sorted_world.visible = show_visuals
	match display_mode:
		DisplayMode.EDITOR:
			grid_view.visible = true
			grid_view.set_render_options(false, true, false, true)
		DisplayMode.REFERENCE:
			grid_view.visible = false
		DisplayMode.LOGIC:
			grid_view.visible = false
		DisplayMode.DEBUG:
			grid_view.visible = true
			grid_view.set_render_options(false, true, true, true)
	queue_redraw()


func set_grid_visible(visible_now: bool) -> void:
	grid_view.visible = visible_now


func set_special_markers_visible(visible_now: bool) -> void:
	marker_layer.visible = visible_now


func get_map_bounds() -> Rect2:
	return grid_view.get_map_bounds() if grid_view != null else Rect2()


func cell_to_local(cell: Vector2i) -> Vector2:
	return grid_view.grid_to_local(cell)


func local_to_cell(local_position: Vector2) -> Vector2i:
	var cell := grid_view.local_to_grid(grid_view.to_local(to_global(local_position)))
	return cell if document != null and document.is_valid_cell(cell) else INVALID_CELL


func select_cell(cell: Vector2i) -> void:
	selected_cell = cell if document != null and document.is_valid_cell(cell) else INVALID_CELL
	if selected_cell == INVALID_CELL:
		grid_view.clear_selection()
	else:
		grid_view.set_selected_cell(selected_cell)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not editor_input_enabled or document == null:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_camera(1.12)
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_camera(1.0 / 1.12)
			return
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = button.pressed
			return
		if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var cell := local_to_cell(to_local(get_global_mouse_position()))
			if button.pressed:
				if cell == INVALID_CELL:
					return
				if button.alt_pressed:
					eyedrop_requested.emit(cell)
					select_cell(cell)
					return
				_painting = true
				_erasing = button.button_index == MOUSE_BUTTON_RIGHT
				stroke_started.emit()
				select_cell(cell)
				paint_requested.emit(cell, _erasing)
			else:
				if _painting:
					stroke_finished.emit()
				_painting = false
			return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _panning and editor_camera != null:
			editor_camera.position -= motion.relative / editor_camera.zoom
			return
		var hovered := local_to_cell(to_local(get_global_mouse_position()))
		if hovered != hovered_cell:
			hovered_cell = hovered
			hovered_cell_changed.emit(hovered)
		if _painting and hovered != INVALID_CELL:
			select_cell(hovered)
			paint_requested.emit(hovered, _erasing)


func _zoom_camera(factor: float) -> void:
	if editor_camera == null:
		return
	var next := clampf(editor_camera.zoom.x * factor, 0.25, 3.0)
	editor_camera.zoom = Vector2.ONE * next


func _rebuild_all() -> void:
	_clear_all_visuals()
	if document == null:
		return
	_sync_grid_all()
	for cell in document.all_cells():
		_build_cell_visual(cell)
	queue_redraw()


func _build_cell_visual(cell: Vector2i) -> void:
	_clear_cell_visual(cell)
	var state := document.get_cell(cell)
	var nodes: Array[Node] = []
	if int(state.base) != ArenaMapDocument.BaseTile.VOID \
			and int(state.wall) == ArenaMapDocument.WallType.NONE:
		var base_sprite := _new_tile_sprite(
			TILE_TEXTURES[int(state.base)],
			BASE_TINTS[int(state.base)],
			cell
		)
		base_sprite.name = "Base_%d_%d" % [cell.x, cell.y]
		floor_layer.add_child(base_sprite)
		nodes.append(base_sprite)
	if int(state.surface) != ArenaMapDocument.SurfaceEffect.NONE:
		var surface_sprite := _new_tile_sprite(
			SURFACE_TEXTURES[int(state.surface)], Color.WHITE, cell
		)
		surface_sprite.name = "Surface_%d_%d" % [cell.x, cell.y]
		surface_layer.add_child(surface_sprite)
		nodes.append(surface_sprite)
	if int(state.wall) != ArenaMapDocument.WallType.NONE:
		var wall := WALL_SCENE.instantiate() as ArenaEditorWallPreview
		wall.configure(int(state.wall))
		wall.position = grid_view.grid_to_local(cell)
		y_sorted_world.add_child(wall)
		nodes.append(wall)
	if int(state.special) != ArenaMapDocument.SpecialTile.NONE:
		var marker := _new_special_marker(int(state.special), cell)
		marker_layer.add_child(marker)
		nodes.append(marker)
	_cell_visuals[cell] = nodes


func _new_tile_sprite(texture: Texture2D, tint: Color, cell: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = true
	sprite.position = grid_view.grid_to_local(cell)
	sprite.scale = TILE_SCALE
	sprite.self_modulate = tint
	return sprite


func _new_special_marker(special: int, cell: Vector2i) -> Node2D:
	var marker := Node2D.new()
	marker.name = "Special_%s_%d_%d" % [
		ArenaMapDocument.SPECIAL_NAMES[special], cell.x, cell.y,
	]
	marker.position = grid_view.grid_to_local(cell)
	var colors := {
		ArenaMapDocument.SpecialTile.ALLY_SPAWN: Color("4aa8ff"),
		ArenaMapDocument.SpecialTile.ENEMY_SPAWN: Color("ff5d55"),
		ArenaMapDocument.SpecialTile.OBJECTIVE: Color("ffd75a"),
		ArenaMapDocument.SpecialTile.DECOR_ANCHOR: Color("76e49b"),
	}
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -11), Vector2(21, 0), Vector2(0, 11), Vector2(-21, 0),
	])
	diamond.color = colors[special]
	marker.add_child(diamond)
	var label := Label.new()
	label.text = ["", "A", "E", "O", "D"][special]
	label.position = Vector2(-7, -14)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("102033"))
	marker.add_child(label)
	return marker


func _sync_grid_all() -> void:
	grid = GridData.new(document.grid_size.x, document.grid_size.y)
	grid_view.setup(grid)
	for cell in document.all_cells():
		_sync_grid_cell(cell)


func _sync_grid_cell(cell: Vector2i) -> void:
	var state := document.get_cell(cell)
	var type := GridData.CellType.NORMAL
	if int(state.wall) != ArenaMapDocument.WallType.NONE:
		type = GridData.CellType.WALL
	else:
		match int(state.base):
			ArenaMapDocument.BaseTile.VOID:
				type = GridData.CellType.HOLE
			ArenaMapDocument.BaseTile.ICE:
				type = GridData.CellType.ICE
			ArenaMapDocument.BaseTile.LAVA:
				type = GridData.CellType.LAVA
			ArenaMapDocument.BaseTile.SHADOW:
				type = GridData.CellType.SHADOW
			ArenaMapDocument.BaseTile.RUNE:
				type = GridData.CellType.RUNE
	grid.set_type(cell, type)
	grid_view.queue_redraw()


func _on_document_cell_changed(cell: Vector2i, _previous: Dictionary, _current: Dictionary) -> void:
	_sync_grid_cell(cell)
	_build_cell_visual(cell)
	queue_redraw()


func _on_document_resized(_previous: Vector2i, _current: Vector2i) -> void:
	_rebuild_all()


func _on_document_reset() -> void:
	_rebuild_all()


func _clear_cell_visual(cell: Vector2i) -> void:
	for node in _cell_visuals.get(cell, []):
		if node != null and is_instance_valid(node):
			var parent: Node = node.get_parent()
			if parent != null:
				parent.remove_child(node)
			node.free()
	_cell_visuals.erase(cell)


func _clear_all_visuals() -> void:
	for cell in _cell_visuals.keys():
		_clear_cell_visual(cell)
	_cell_visuals.clear()


func _draw() -> void:
	if document == null or grid_view == null:
		return
	var bounds := grid_view.get_map_bounds().grow(96)
	draw_rect(bounds, Color("111925"), true)
	draw_rect(bounds, Color("314257"), false, 3.0)
	if display_mode == DisplayMode.LOGIC:
		for cell in document.all_cells():
			var state := document.get_cell(cell)
			var color: Color = LOGIC_COLORS[int(state.base)]
			if int(state.wall) != ArenaMapDocument.WallType.NONE:
				color = Color("ba463d")
			draw_colored_polygon(grid_view.get_cell_polygon(cell), color)
			var center := grid_view.grid_to_local(cell)
			draw_string(
				ThemeDB.fallback_font, center + Vector2(-12, 4),
				"%d,%d" % [cell.x, cell.y], HORIZONTAL_ALIGNMENT_CENTER,
				24, 8, Color("101722")
			)
	elif display_mode == DisplayMode.DEBUG:
		for cell in document.all_cells():
			var center := grid_view.grid_to_local(cell)
			draw_string(
				ThemeDB.fallback_font, center + Vector2(-12, 4),
				"%d,%d" % [cell.x, cell.y], HORIZONTAL_ALIGNMENT_CENTER,
				24, 8, Color.WHITE
			)
