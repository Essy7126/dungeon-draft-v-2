extends "res://battle/modular/modular_battle.gd"
const Rules = preload("res://core/expedition/card_tactical_room_rules.gd")
const ResourceRules = preload("res://core/expedition/card_tactical_resource_rules.gd")
const Rooms = preload("res://core/expedition/card_tactical_room_catalog.gd")
const Overlay = preload("res://battle/tactical_rooms/tactical_room_overlay.gd")
var room_rules: Rules
var room_overlay: Node2D
var room_panel: PanelContainer
var room_label: Label
var room_buttons: Dictionary = { }
var room_description: Label
var room_scroll: ScrollContainer
var _tactical_hand_top := -1.0


func _ready() -> void:
	EventBus.combat_started.connect(_bind_room)
	EventBus.turn_ended.connect(_room_turn_ended)
	super()
	_build_room_panel()
	var identity := str(room_data.get_meta("card_tactical_room_id", "forge"))
	_arena_tile_parent.modulate = {
		"forge": Color("e7b583"),
		"garden": Color("a5bbd9"),
		"convoy": Color("91c4b4"),
		"hourglass": Color("c0a4df"),
		"reservoir": Color("88c9d7"),
	}[identity]
	_fit_camera_to_battle()


func set_card_hand_top(screen_y: float) -> void:
	if is_equal_approx(_tactical_hand_top, screen_y):
		return
	_tactical_hand_top = screen_y
	_fit_camera_to_battle()


func _fit_camera_to_battle() -> void:
	if camera == null or grid_view == null or not grid_view.has_method("get_map_bounds"):
		return
	var viewport := get_viewport_rect().size
	var bottom := _tactical_hand_top if _tactical_hand_top > 0 else viewport.y * .63
	var available := Rect2(
		Vector2(300, 90),
		Vector2(maxf(200, viewport.x - 320), maxf(180, bottom - 105)),
	)
	var bounds: Rect2 = grid_view.get_map_bounds()
	bounds = bounds.grow_individual(25, 80, 25, 5)
	var zoom_value := minf(available.size.x / bounds.size.x, available.size.y / bounds.size.y)
	camera.zoom = Vector2.ONE * zoom_value
	camera.position = grid_view.to_global(bounds.get_center()) - (
		available.get_center() - viewport * .5
	) / zoom_value
	if room_panel != null:
		room_panel.size = Vector2(280, maxf(200, bottom - 105))


func _bind_room(actors: Array, board: GridData) -> void:
	if board != grid or room_rules != null:
		return
	var identity := str(room_data.get_meta("card_tactical_room_id", "forge"))
	room_rules = ResourceRules.new() if identity in ["hourglass", "reservoir"] else Rules.new()
	room_rules.bind(
		str(room_data.get_meta("card_tactical_room_id", "forge")),
		grid,
		terrain_effects,
		actors,
		_room_input_allowed,
	)
	room_rules.changed.connect(_refresh_room)
	room_overlay = Overlay.new()
	room_overlay.rules = room_rules
	room_overlay.view = grid_view
	grid_view.add_child(room_overlay)
	_refresh_room()


func _room_input_allowed() -> bool:
	return (
		_can_accept_player_intent() and not _battle_over and not _closing
		and not _spell_resolution_pending and turn_queue != null and room_rules != null
		and turn_queue.get_current_unit() == room_rules.hero and turn_state != null
		and turn_state.current
		in [
			TurnState.State.IDLE,
			TurnState.State.MOVE,
			TurnState.State.TARGET_MELEE,
			TurnState.State.TARGET_SPELL,
		]
	)


func _on_turn_started(actor: Unit) -> void:
	if room_rules != null and not _battle_over and not _closing and actor.team != 0:
		var is_courier := (
			room_rules.room_id == "convoy" and actor in room_rules.carriers
			and not room_rules.altar_sealed and room_rules.boss.is_alive
		)
		_begin_outcome_deferral()
		var consumed := false
		if is_courier:
			var stunned := ArenaTerrainStatusTimingService.resolve_activation_start(
				actor,
				terrain_effects,
			)
			if actor.is_alive and not stunned:
				room_rules.begin_enemy_turn(actor)
			consumed = true
		else:
			room_rules.begin_enemy_turn(actor)
		_sync_room_positions()
		if _finish_outcome_deferral():
			return
		if consumed:
			_begin_action_resolution(&"room_convoy")
			if not await _wait_battle_seconds_safe(.35, _lifecycle_generation):
				return
			_turn_end_committed = false
			_finish_active_turn(&"room_convoy")
			return
	super(actor)


func _room_turn_ended(actor: Unit, reason: StringName) -> void:
	if (
		room_rules == null or actor != room_rules.hero
		or _battle_over or _closing or reason == &"dead"
	):
		return
	room_rules.finish_hero_turn()
	_sync_room_positions()
	_refresh_room()


func _sync_room_positions() -> void:
	for actor in _unit_views:
		var view = _unit_views[actor]
		if is_instance_valid(view) and actor.is_alive:
			view.position = grid_cell_to_parent_local(actor.grid_pos, view.get_parent())
		if is_instance_valid(view) and view.has_method("synchronize_external_movement"):
			view.synchronize_external_movement()


func _build_room_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 12
	add_child(canvas)
	room_panel = PanelContainer.new()
	room_panel.position = Vector2(12, 90)
	room_panel.custom_minimum_size.x = 270
	canvas.add_child(room_panel)
	room_scroll = ScrollContainer.new()
	room_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	room_scroll.custom_minimum_size = Vector2(270, 200)
	room_panel.add_child(room_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_scroll.add_child(column)
	room_label = Label.new()
	room_label.custom_minimum_size.x = 270
	room_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_label.add_theme_font_size_override("font_size", 14)
	column.add_child(room_label)
	var details := CheckButton.new()
	details.text = "Règles de la salle"
	column.add_child(details)
	room_description = Label.new()
	room_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_description.add_theme_font_size_override("font_size", 13)
	room_description.visible = false
	column.add_child(room_description)
	details.toggled.connect(
		func(value):
			room_description.visible = value,
	)
	for action in ["left", "right", "gate"]:
		var button := Button.new()
		column.add_child(button)
		room_buttons[action] = button
		button.pressed.connect(
			func():
				_use_room_mechanism(action),
		)
		button.mouse_entered.connect(
			func():
				if room_overlay != null:
					room_overlay.preview = room_rules.preview_terminal(action),
		)
		button.mouse_exited.connect(
			func():
				if room_overlay != null:
					room_overlay.preview.clear(),
		)
	_refresh_room()


func _use_room_mechanism(action: String) -> void:
	if room_rules == null or not _room_input_allowed():
		return
	_begin_outcome_deferral()
	if room_rules.use_terminal(action):
		room_overlay.preview.clear()
		_cancel_action_selection_for_active_unit()
		_sync_room_positions()
		_hud_port.update_info(room_rules.hero)
		_hud_port.build_actions(room_rules.hero)
	if _finish_outcome_deferral():
		return
	_refresh_room()


func _process(_delta: float) -> void:
	_refresh_room()


func _refresh_room() -> void:
	if room_label == null:
		return
	if room_rules == null:
		room_label.text = room_data.room_name + "\nDéployez Achille pour commencer."
		for button in room_buttons.values():
			button.visible = false
		return
	room_rules.outcome = "closed" if _battle_over else ""
	room_label.text = room_data.room_name + "\n" + room_rules.intention_text()
	room_description.text = Rooms.ROOMS[room_rules.room_id].rule + "\nL : levier · O : autel · S : socle · C : croix · H/B : réserves · ! : danger.\n" + "\n".join(
		room_rules.messages
	)
	var captions: Array = {
		"forge": ["Rail haut · 1 PA", "Rail bas · 1 PA", "Rail central · 1 PA"],
		"garden": ["Socle haut · 1 PA", "Socle bas · 1 PA", ""],
		"convoy": ["", "", "Sceller l'autel · 2 PA"],
		"hourglass": ["Retarder · 1 PA (+16 dégâts)", "Recentrer sur le chef · 2 PA", ""],
		"reservoir": ["Décharger H · 1 PA", "Décharger B · 1 PA", ""],
	}[room_rules.room_id]
	for index in 3:
		var action: String = ["left", "right", "gate"][index]
		var button: Button = room_buttons[action]
		button.text = captions[index]
		button.visible = not button.text.is_empty()
		var reason := room_rules.terminal_failure(action)
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason
	if room_overlay != null:
		if not _room_input_allowed():
			room_overlay.preview.clear()
		room_overlay.queue_redraw()


func _exit_tree() -> void:
	if EventBus.combat_started.is_connected(_bind_room):
		EventBus.combat_started.disconnect(_bind_room)
	if EventBus.turn_ended.is_connected(_room_turn_ended):
		EventBus.turn_ended.disconnect(_room_turn_ended)
	if room_rules != null:
		room_rules.dispose()
	super()
