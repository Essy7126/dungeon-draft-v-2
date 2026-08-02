class_name StartHubController
extends Node

const BACKGROUND_SIZE := Vector2(2048.0, 2048.0)

@onready var world_root: Node2D = $"../WorldRoot"
@onready var grid_overlay: HubGridOverlay = $"../WorldRoot/GridOverlay"
@onready var player: Node2D = $"../WorldRoot/SortableWorld/Player"
@onready var navigation_grid: HubNavigationGrid = $"../NavigationGrid"
@onready var camera: Camera2D = $"../CameraRig/Camera2D"
@onready var debug_panel: Control = $"../HubUI/DebugPanel"
@onready var hover_label: Label = $"../HubUI/DebugPanel/Margin/Content/Hover"
@onready var conversion_label: Label = $"../HubUI/DebugPanel/Margin/Content/Conversion"
@onready var counts_label: Label = $"../HubUI/DebugPanel/Margin/Content/Counts"

var _debug_visible := true


func _ready() -> void:
	navigation_grid.rebuild()
	grid_overlay.setup(navigation_grid)
	var markers := _collect_markers()
	grid_overlay.set_technical_markers(markers)
	for marker in markers:
		marker.position = grid_overlay.cell_to_world(marker.cell)
	_place_player(markers)
	_update_counts()
	_fit_camera()
	if not get_viewport().size_changed.is_connected(_fit_camera):
		get_viewport().size_changed.connect(_fit_camera)
	if not grid_overlay.cell_hovered.is_connected(_on_cell_hovered):
		grid_overlay.cell_hovered.connect(_on_cell_hovered)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_debug_visible = not _debug_visible
		grid_overlay.set_debug_visible(_debug_visible)
		debug_panel.visible = _debug_visible
		get_viewport().set_input_as_handled()


func _collect_markers() -> Array[HubTechnicalMarker]:
	var result: Array[HubTechnicalMarker] = []
	for child in navigation_grid.get_children():
		if child is HubTechnicalMarker:
			result.append(child as HubTechnicalMarker)
	return result


func _place_player(markers: Array[HubTechnicalMarker]) -> void:
	for marker in markers:
		if marker.name != &"PlayerSpawn":
			continue
		player.position = grid_overlay.cell_to_world(marker.cell)
		if player.has_method("set_facing"):
			player.set_facing(Vector2i.UP)
		return
	push_error("StartHub: marqueur PlayerSpawn introuvable.")


func _fit_camera() -> void:
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	camera.position = BACKGROUND_SIZE * 0.5
	var fit := minf(viewport_size.x / BACKGROUND_SIZE.x, viewport_size.y / BACKGROUND_SIZE.y)
	camera.zoom = Vector2.ONE * fit
	camera.make_current()


func _update_counts() -> void:
	counts_label.text = "Praticables : %d | Bloquees : %d | F1 : debug" % [
		navigation_grid.get_walkable_cells().size(),
		navigation_grid.get_blocked_cells().size(),
	]


func _on_cell_hovered(
		cell: Vector2i,
		screen_position: Vector2,
		world_position: Vector2,
		snapped_world_position: Vector2
	) -> void:
	if cell == HubGridOverlay.INVALID_CELL:
		hover_label.text = "Cellule : hors grille"
		conversion_label.text = "Ecran %.0f,%.0f -> hors grille" % [
			screen_position.x, screen_position.y,
		]
		return
	var state := "praticable" if navigation_grid.is_walkable(cell) else "bloquee"
	hover_label.text = "Cellule : (%d,%d) - %s" % [cell.x, cell.y, state]
	conversion_label.text = (
		"Ecran %.0f,%.0f -> monde %.1f,%.1f -> cellule %d,%d -> centre %.1f,%.1f"
		% [
			screen_position.x, screen_position.y,
			world_position.x, world_position.y,
			cell.x, cell.y,
			snapped_world_position.x, snapped_world_position.y,
		]
	)
