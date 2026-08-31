class_name StartHubController
extends Node

signal state_changed(previous_state: HubState, next_state: HubState)
signal run_transition_started
signal run_transition_failed
signal intro_cinematic_requested(scene_path: String)

enum HubState {
	IDLE,
	MOVING,
	APPROACHING_INTERACTION,
	INTERACTING,
	UI_LOCKED,
	TRANSITIONING,
}

const BACKGROUND_SIZE := Vector2(2048.0, 2048.0)
const STATE_NAMES := [
	"IDLE",
	"MOVING",
	"APPROACHING_INTERACTION",
	"INTERACTING",
	"UI_LOCKED",
	"TRANSITIONING",
]

@export_range(0.0, 1.5, 0.05) var transition_fade_duration := 0.35
@export_file("*.tscn") var intro_cinematic_scene_path := (
	"res://cinematics/intro/intro_cinematic.tscn"
)
@export var debug_enabled := false

@onready var world_root: Node2D = $"../WorldRoot"
@onready var grid_overlay: HubGridOverlay = $"../WorldRoot/GridOverlay"
@onready var navigation_region: HubNavigationRegion2D = \
	$"../WorldRoot/NavigationRegion2D"
@onready var player: Node2D = $"../WorldRoot/SortableWorld/Player"
@onready var archivist: HubArchivist = $"../WorldRoot/SortableWorld/Archivist"
@onready var navigation_grid_node: HubNavigationGridNode = $"../NavigationGrid"
@onready var camera: Camera2D = $"../CameraRig/Camera2D"
@onready var debug_panel: Control = $"../HubUI/DebugPanel"
@onready var hover_label: Label = $"../HubUI/DebugPanel/Margin/Content/Hover"
@onready var conversion_label: Label = $"../HubUI/DebugPanel/Margin/Content/Conversion"
@onready var counts_label: Label = $"../HubUI/DebugPanel/Margin/Content/Counts"
@onready var archivist_panel: ArchivistPanel = $"../HubUI/ArchivistPanel"
@onready var trade_panel: TradePanel = $"../HubUI/TradePanel"
@onready var transition_fade: ColorRect = $"../HubUI/TransitionFade"
@onready var movement: ExplorationMovement = $ExplorationMovement
@onready var interaction_resolver: HubInteractionResolver = $InteractionResolver

var cinematic_open_callable: Callable
var _state := HubState.IDLE
var _intent_sequence := 0
var _active_intent: InteractionIntent = null
var _cinematic_transition_committed := false
var navigation_grid: HubNavigationGrid = null


func _ready() -> void:
	navigation_region.rebuild()
	navigation_grid_node.rebuild()
	navigation_grid = navigation_grid_node.model
	grid_overlay.setup(navigation_grid)
	var markers := _collect_markers()
	grid_overlay.set_technical_markers(markers)
	for marker in markers:
		marker.position = navigation_grid.cell_to_world(marker.cell)
	_configure_archivist_navigation_points()
	_apply_debug_state()
	var spawn_world_position := _get_marker_world_position(&"PlayerSpawn")
	movement.setup(player, navigation_region, spawn_world_position)
	if not navigation_grid.occupy(archivist.occupied_cell, archivist):
		push_error("StartHub: metadonnee de cellule Archiviste invalide.")
	_connect_signals()
	_update_counts()
	_fit_camera()
	if not cinematic_open_callable.is_valid():
		cinematic_open_callable = Callable(self, "_open_intro_cinematic")
	if not get_viewport().size_changed.is_connected(_fit_camera):
		get_viewport().size_changed.connect(_fit_camera)


func _exit_tree() -> void:
	if is_instance_valid(navigation_grid) and is_instance_valid(archivist):
		navigation_grid.vacate(archivist.occupied_cell, archivist)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
		and event.keycode == KEY_F1:
		set_debug_enabled(not debug_enabled)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
		request_primary_click_at_screen(event.position)
		get_viewport().set_input_as_handled()


func request_primary_click_at_screen(screen_position: Vector2) -> bool:
	var canvas_position := get_viewport().get_canvas_transform().affine_inverse() \
		* screen_position
	return request_primary_click_at_world(canvas_position)


func request_primary_click_at_world(world_position: Vector2) -> bool:
	if archivist.is_click_proxy_world_point(world_position):
		return request_interaction(archivist) != null
	return request_ground_move(world_position)


func is_debug_enabled() -> bool:
	return debug_enabled


func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	_apply_debug_state()


func request_ground_move(world_position: Vector2) -> bool:
	if _state not in [HubState.IDLE, HubState.MOVING, HubState.APPROACHING_INTERACTION]:
		return false
	_cancel_active_intent()
	_intent_sequence += 1
	_set_state(HubState.MOVING)
	if not movement.request_move(world_position):
		_set_state(HubState.IDLE)
		return false
	return true


func request_interaction(target: Interactable) -> InteractionIntent:
	if _state not in [HubState.IDLE, HubState.MOVING, HubState.APPROACHING_INTERACTION] \
		or target == null or not target.can_interact(player):
		return null
	_cancel_active_intent()
	_intent_sequence += 1
	var intent := InteractionIntent.new(_intent_sequence, target)
	_active_intent = intent
	var resolution := interaction_resolver.resolve(
		player, target, navigation_region, intent
	)
	if resolution.is_empty():
		intent.cancel()
		_active_intent = null
		_set_state(HubState.IDLE)
		return null
	_set_state(HubState.APPROACHING_INTERACTION)
	if not movement.request_move(intent.destination, intent):
		navigation_region.release_world_position(intent.destination, intent)
		intent.cancel()
		_active_intent = null
		_set_state(HubState.IDLE)
		return null
	return intent


func get_state() -> HubState:
	return _state


func get_state_name() -> String:
	return STATE_NAMES[_state]


func get_active_intent() -> InteractionIntent:
	return _active_intent


func get_last_intent_id() -> int:
	return _intent_sequence


func is_ui_locked() -> bool:
	return _state in [HubState.UI_LOCKED, HubState.TRANSITIONING]


func _connect_signals() -> void:
	grid_overlay.cell_hovered.connect(_on_cell_hovered)
	archivist.interaction_requested.connect(request_interaction)
	archivist.interaction_activated.connect(_on_archivist_interaction_activated)
	movement.movement_completed.connect(_on_movement_completed)
	movement.movement_failed.connect(_on_movement_failed)
	movement.movement_direction_changed.connect(
		_on_movement_direction_changed
	)
	movement.path_changed.connect(navigation_region.set_debug_path)
	archivist_panel.trade_requested.connect(_on_trade_requested)
	archivist_panel.run_requested.connect(_on_run_requested)
	archivist_panel.closed.connect(_on_archivist_panel_closed)
	trade_panel.closed.connect(_on_trade_panel_closed)


func _on_movement_completed(_destination: Vector2) -> void:
	if _state == HubState.MOVING:
		_set_state(HubState.IDLE)
		return
	if _state != HubState.APPROACHING_INTERACTION:
		return
	var intent := _active_intent
	if intent == null:
		_set_state(HubState.IDLE)
		return
	navigation_region.release_world_position(intent.destination, intent)
	var target := intent.get_target()
	if target == null or not target.can_interact(player) \
		or player.global_position.distance_to(intent.destination) \
		> movement.arrival_tolerance + 0.5:
		_cancel_active_intent()
		_set_state(HubState.IDLE)
		return
	var target_world_position := target.get_occupied_world_position()
	if player.global_position.distance_to(target_world_position) \
		> target.get_max_interaction_distance():
		_cancel_active_intent()
		_set_state(HubState.IDLE)
		return
	_orient_player_to_world_direction(
		target_world_position - player.global_position
	)
	_set_state(HubState.INTERACTING)
	target.interact(player)
	if _state == HubState.INTERACTING:
		_cancel_active_intent()
		_set_state(HubState.IDLE)


func _on_movement_failed(_destination: Vector2) -> void:
	if _state in [HubState.MOVING, HubState.APPROACHING_INTERACTION]:
		_cancel_active_intent()
		_set_state(HubState.IDLE)


func _on_archivist_interaction_activated(_actor: Node) -> void:
	if _state != HubState.INTERACTING or _active_intent == null \
		or _active_intent.get_target() != archivist:
		return
	_cancel_active_intent()
	movement.ensure_idle()
	archivist_panel.open_panel(archivist.data)
	_set_state(HubState.UI_LOCKED)


func _on_trade_requested() -> void:
	if _state != HubState.UI_LOCKED:
		return
	archivist_panel.close_silently()
	trade_panel.open_panel(archivist.data)


func _on_trade_panel_closed() -> void:
	if _state == HubState.UI_LOCKED:
		archivist_panel.open_panel(archivist.data)


func _on_archivist_panel_closed() -> void:
	if _state == HubState.UI_LOCKED and not trade_panel.visible:
		_set_state(HubState.IDLE)


func _on_run_requested(run_data: RunData, start_room_index: int) -> void:
	if _state != HubState.UI_LOCKED or _cinematic_transition_committed:
		return
	if archivist.data == null \
			or not archivist.data.get_available_runs().has(run_data) \
			or not GameManager.configure_next_run(run_data, start_room_index):
		return
	_begin_run_transition()


func _begin_run_transition() -> void:
	_cinematic_transition_committed = true
	_cancel_active_intent()
	archivist_panel.close_silently()
	trade_panel.close_silently()
	archivist.set_interaction_enabled(false)
	_set_state(HubState.TRANSITIONING)
	run_transition_started.emit()
	transition_fade.visible = true
	if transition_fade_duration > 0.0:
		var tween := create_tween()
		tween.tween_property(
			transition_fade, "color:a", 1.0, transition_fade_duration
		)
		await tween.finished
	else:
		transition_fade.color.a = 1.0

	var configured_run := GameManager.peek_next_run_data()
	if configured_run == null:
		_restore_failed_run_transition("configuration de run perdue avant transition")
		return
	if configured_run.intro_sequence == null:
		if GameManager.start_configured_run():
			return
		_restore_failed_run_transition("demarrage direct de la run refuse")
		return

	intro_cinematic_requested.emit(intro_cinematic_scene_path)
	var opened = cinematic_open_callable.call(intro_cinematic_scene_path)
	if opened is bool and opened:
		return
	_restore_failed_run_transition(
		"impossible d'ouvrir la cinematique d'introduction : %s"
		% intro_cinematic_scene_path
	)


func _restore_failed_run_transition(reason: String) -> void:
	push_error("StartHub: %s" % reason)
	_cinematic_transition_committed = false
	GameManager.clear_next_run_configuration()
	archivist.set_interaction_enabled(true)
	transition_fade.color.a = 0.0
	transition_fade.visible = false
	_set_state(HubState.IDLE)
	run_transition_failed.emit()


func _open_intro_cinematic(scene_path: String) -> bool:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return false
	var error := get_tree().change_scene_to_packed(packed)
	if error != OK:
		push_error(
			"StartHub: changement vers la cinematique refuse : %s"
			% error_string(error)
		)
		return false
	return true


func _cancel_active_intent() -> void:
	if _active_intent == null:
		return
	if _active_intent.has_destination():
		navigation_region.release_world_position(
			_active_intent.destination, _active_intent
		)
	_active_intent.cancel()
	_active_intent = null


func _set_state(next_state: HubState) -> void:
	if _state == next_state:
		return
	var previous := _state
	_state = next_state
	state_changed.emit(previous, _state)


func _collect_markers() -> Array[HubTechnicalMarker]:
	var result: Array[HubTechnicalMarker] = []
	for child in navigation_grid_node.get_children():
		if child is HubTechnicalMarker:
			result.append(child as HubTechnicalMarker)
	return result


func _get_marker_cell(marker_name: StringName) -> Vector2i:
	var marker := navigation_grid_node.get_node_or_null(NodePath(String(marker_name))) \
		as HubTechnicalMarker
	if marker == null:
		push_error("StartHub: marqueur %s introuvable." % marker_name)
		return Vector2i.ZERO
	return marker.cell


func _get_marker_world_position(marker_name: StringName) -> Vector2:
	var marker := navigation_grid_node.get_node_or_null(
		NodePath(String(marker_name))
	) as HubTechnicalMarker
	if marker == null:
		push_error("StartHub: marqueur %s introuvable." % marker_name)
		return Vector2.ZERO
	return marker.global_position


func _configure_archivist_navigation_points() -> void:
	var approaches := PackedVector2Array()
	for marker_name in [
		&"ArchivistApproachNorthWest",
		&"ArchivistApproachNorthEast",
		&"ArchivistApproachSouthEast",
		&"ArchivistApproachSouthWest",
	]:
		approaches.append(_get_marker_world_position(marker_name))
	archivist.configure_navigation_points(
		_get_marker_world_position(&"ArchivistCell"), approaches
	)


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


func _apply_debug_state() -> void:
	if is_instance_valid(grid_overlay):
		grid_overlay.visible = debug_enabled
		grid_overlay.set_debug_visible(debug_enabled)
	if is_instance_valid(debug_panel):
		debug_panel.visible = debug_enabled
	if is_instance_valid(navigation_region):
		navigation_region.set_debug_visible(debug_enabled)
	for marker in _collect_markers():
		marker.visible = debug_enabled

func _on_movement_direction_changed(world_direction: Vector2) -> void:
	_orient_player_to_world_direction(world_direction)


func _orient_player_to_world_direction(world_direction: Vector2) -> void:
	if world_direction.is_zero_approx():
		return
	var character_pivot := player.get_node_or_null(
		"CharacterViewport/CharacterWorld/CharacterPivot"
	) as Node3D
	if character_pivot == null:
		return
	var continuous_grid_direction := Vector2(
		world_direction.x / 64.0 + world_direction.y / 32.0,
		world_direction.y / 32.0 - world_direction.x / 64.0
	)
	character_pivot.rotation_degrees.y = rad_to_deg(atan2(
		continuous_grid_direction.x,
		continuous_grid_direction.y
	))
