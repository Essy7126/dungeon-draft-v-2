extends "res://hub/painted_halt/living_halt.gd"
## A presentation before run creation. Only crossing the gate commits a run.
const ThresholdInteractions := preload("res://hub/catabase_threshold/threshold_interactions.gd")
const ThresholdNavigation := preload("res://hub/catabase_threshold/threshold_navigation.gd")
const Fog := preload("res://hub/catabase_threshold/threshold_fog.gd")
const PortraitDialogue := preload("res://ui/dialogue/portrait_dialogue.gd")
const CHARON_PORTRAIT := preload("res://assets/catabase/dialogue/charon_v1/portrait.png")
const CHARON_GREETING := "Te voilà, Achille. Au-delà de cette porte, un nouveau monde t’attend.\n\nMais souviens-toi : ici, c’est moi, Charon, qui déciderai si tu peux poursuivre ta route… ou si ton voyage s’arrête."
const CLASSIC_PROFILE := preload(
	"res://data/visuals/achilles/achilles_polish_sprite_profile_v3.tres"
)
const PAINTED_PROFILE := preload(
	"res://data/visuals/achilles/achilles_painted_g_sprite_profile.tres"
)
var run_manager_override: Node
var _entry_run: RunData
var _fog: Fog
var _objective: Label
var _approach: Button
var _dialogue: PanelContainer
var _dialogue_content: VBoxContainer
var _menu_open := false
var _departure_started := false
var _departure_pending := false
var _walked := false
var _nearest := -1
var _hovered := -1
var _movement_feedback := ""
var _feedback_until := 0.0
var _route_line: Line2D
var _welcome: PortraitDialogue


func _init() -> void:
	nav = ThresholdNavigation.new()


func _manager() -> Node:
	return run_manager_override if is_instance_valid(run_manager_override) else GameManager


func _ready() -> void:
	var manager := _manager()
	if manager.has_catabase_threshold_configuration():
		_entry_run = manager.peek_next_run_data()
	reduced = GameManager.is_reduced_motion_enabled()
	GameManager.reduced_motion_changed.connect(_sync_motion)
	await super._ready()
	if world == null or not is_inside_tree():
		return
	_route_line = Line2D.new()
	_route_line.name = "ThresholdRoute"
	_route_line.width = 2.0
	_route_line.default_color = Color("d6c796a0")
	_route_line.antialiased = true
	_route_line.joint_mode = Line2D.LINE_JOINT_ROUND
	world.add_child(_route_line)
	world.move_child(_route_line, world.get_node("DepthSortedActors").get_index())
	_fog = Fog.new()
	_fog.name = "ThresholdFog"
	world.add_child(_fog)
	if not _fog.configure(world_size, definition):
		push_error("THRESHOLD_FOG: " + _fog.configuration_error)
	_apply_effects()
	_welcome.present("Charon", "Le vieux passeur", CHARON_GREETING, CHARON_PORTRAIT)
	_update_status()


static func profile_for_variants(variants: Dictionary) -> AchillesSpriteVisualProfile:
	return PAINTED_PROFILE if str(variants.get("achilles", "")) == "painted_g" else CLASSIC_PROFILE


func _material_shader() -> Shader:
	return preload("res://hub/catabase_threshold/threshold_materials.gdshader")


func _configure_player(actor: Player) -> void:
	actor.sprite_profile = profile_for_variants(
		_entry_run.hero_visual_variants if _entry_run != null else { }
	)
	var frames := load(actor.sprite_profile.sprite_frames_path) as SpriteFrames
	var pose := frames.get_frame_texture(&"idle_S", 0)
	var silhouette_top := pose.get_image().get_used_rect().position.y
	var silhouette_height := maxf(1.0, actor.sprite_profile.foot_anchor.y - silhouette_top)
	actor.display_scale = ScaleReference.height_ratio(definition) * world_size.y / silhouette_height


func _create_interactions() -> Interactions:
	return ThresholdInteractions.new()


func _apply_effects() -> void:
	super._apply_effects()
	if is_instance_valid(_fog):
		_fog.set_state(clock, not original and layers.atmosphere, reduced)


func _sync_motion(value: bool) -> void:
	reduced = value
	_apply_effects()


func entry_input_blocked() -> bool:
	return _menu_open or _departure_started or (is_instance_valid(_welcome) and _welcome.visible)


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ThresholdInterface"
	add_child(canvas)
	_interface = Control.new()
	canvas.add_child(_interface)
	_interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interface.theme = _theme()
	var top := HBoxContainer.new()
	_interface.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_right = -28
	top.offset_top = 22
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = "Le Seuil des Ombres"
	title.add_theme_font_override("font", TITLE)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("e3c58e"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var menu := _button(top, "Menu", show_menu)
	menu.name = "ThresholdMenu"
	menu.custom_minimum_size = Vector2(82, 40)
	var bottom := VBoxContainer.new()
	_interface.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 28
	bottom.offset_right = -28
	bottom.offset_top = -94
	bottom.offset_bottom = -20
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_approach = _button(bottom, "", _approach_nearest)
	_approach.name = "ApproachLandmark"
	_approach.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_approach.custom_minimum_size = Vector2(240, 40)
	_approach.hide()
	_objective = Label.new()
	_objective.name = "ThresholdObjective"
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.add_theme_font_size_override("font_size", 16)
	_objective.add_theme_color_override("font_color", Color("e5d6b4"))
	_objective.add_theme_color_override("font_shadow_color", Color.BLACK)
	_objective.add_theme_constant_override("shadow_offset_y", 2)
	bottom.add_child(_objective)
	_dialogue = PanelContainer.new()
	_dialogue.name = "ThresholdDialogue"
	_interface.add_child(_dialogue)
	_dialogue.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dialogue.offset_left = -280
	_dialogue.offset_right = 280
	_dialogue.offset_top = -120
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101e23f5")
	style.border_color = Color("9c875b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_dialogue.add_theme_stylebox_override("panel", style)
	_dialogue_content = VBoxContainer.new()
	_dialogue_content.add_theme_constant_override("separation", 16)
	_dialogue.add_child(_dialogue_content)
	_dialogue.hide()
	_welcome = PortraitDialogue.new()
	_welcome.name = "CharonWelcome"
	_interface.add_child(_welcome)
	_welcome.dismissed.connect(_update_status)
	_update_status()


func _update_status() -> void:
	if _objective == null:
		return
	_objective.visible = not (is_instance_valid(_welcome) and _welcome.visible)
	if is_player_moving():
		_walked = true
	if clock < _feedback_until:
		_objective.text = _movement_feedback
	elif is_player_moving():
		_objective.text = "En route · Clic droit pour s’arrêter"
	elif _hovered >= 0:
		_objective.text = (
			"Cliquez sur la porte pour la rejoindre"
			if str(definition.landmarks[_hovered].get("action", "")) == "exit"
			else "Cliquez sur la plaque pour lire ce souvenir"
		)
	else:
		_objective.text = (
			"Rejoindre la porte · Les plaques racontent l’histoire des dieux"
			if _walked
			else "Cliquez pour marcher · Cliquez sur une plaque pour lire son histoire"
		)
	_refresh_route()
	_nearest = -1
	var nearest_distance := world_size.x * 0.075
	if player != null:
		for index: int in definition.landmarks.size():
			var distance := player.position.distance_to(point(definition.landmarks[index].point))
			if distance < nearest_distance:
				_nearest = index
				nearest_distance = distance
	_approach.visible = (
		_nearest >= 0 and not interactions.active
		and not entry_input_blocked() and not is_player_moving()
	)
	if _nearest >= 0:
		_approach.text = (
			"Franchir le seuil  ·  E"
			if str(definition.landmarks[_nearest].get("action", "")) == "exit"
			else "Lire la mémoire  ·  E"
		)


func _approach_nearest() -> void:
	if _nearest >= 0:
		interactions.request(_nearest)


func _clear_dialogue(title_text: String, body: String) -> void:
	for child in _dialogue_content.get_children():
		_dialogue_content.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", TITLE)
	title.add_theme_color_override("font_color", Color("e3c58e"))
	title.add_theme_font_size_override("font_size", 23)
	_dialogue_content.add_child(title)
	if not body.is_empty():
		var text := Label.new()
		text.text = body
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 480
		text.add_theme_font_size_override("font_size", 18)
		_dialogue_content.add_child(text)
	_dialogue.show()


func show_landmark(index: int) -> void:
	var landmark: Dictionary = definition.landmarks[index]
	var gate := str(landmark.get("action", "")) == "exit"
	_clear_dialogue(
		str(landmark.title),
		str(landmark.get("description", "Le silence des pierres vous accompagne.")),
	)
	var action: Button
	if gate:
		action = _button(
			_dialogue_content,
			"Franchir le seuil" if _entry_run != null else "Choisir mon apparence",
			depart if _entry_run != null else _open_selection,
		)
		action.name = "CrossThreshold" if _entry_run != null else "ChooseAppearance"
	else:
		interactions.awakened[str(landmark.get("id", ""))] = true
		action = _button(_dialogue_content, "Poursuivre", interactions.close)
		action.name = "CloseMemory"
	if gate:
		_button(_dialogue_content, "Rester un instant", interactions.close).name = "StayAtThreshold"
	_defer_focus(action)


func _defer_focus(control: Control) -> void:
	_focus_if_visible.call_deferred(weakref(control))


func _focus_if_visible(reference: WeakRef) -> void:
	var control := reference.get_ref() as Control
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


func close_dialogue() -> void:
	_dialogue.hide()
	_menu_open = false
	paused = false


func show_menu() -> void:
	if _departure_started or (is_instance_valid(_welcome) and _welcome.visible):
		return
	interactions.active = false
	stop_movement()
	_menu_open = true
	paused = true
	_clear_dialogue("Le Seuil des Ombres", "")
	_defer_focus(_button(_dialogue_content, "Reprendre", close_dialogue))
	var motion := CheckButton.new()
	motion.text = "Réduire les animations"
	motion.button_pressed = GameManager.is_reduced_motion_enabled()
	motion.toggled.connect(GameManager.set_reduced_motion_enabled)
	_dialogue_content.add_child(motion)
	_button(_dialogue_content, "Retour à l’accueil", return_to_title).name = "ReturnToTitle"


func depart() -> Dictionary:
	if (
		not interactions.active or interactions.selected < 0
		or str(definition.landmarks[interactions.selected].get("action", "")) != "exit"
	):
		return { "success": false, "pending": false }
	if _departure_started or _entry_run == null:
		return { "success": false, "pending": _departure_pending }
	_departure_started = true
	stop_movement()
	var result: Dictionary = _manager().finish_catabase_threshold()
	if bool(result.get("success", false)):
		AudioManager.play_feedback(&"confirm")
	_departure_pending = bool(result.get("pending", false))
	if not bool(result.get("success", false)):
		_departure_started = _departure_pending
		_clear_dialogue(
			"Le départ attend",
			str(result.get("message", "Le chemin ne peut pas encore s’ouvrir.")),
		)
		if _departure_pending:
			_button(_dialogue_content, "Réessayer l’enregistrement", retry_departure).name = "RetryThresholdSave"
		else:
			_button(_dialogue_content, "Retour à la sélection", _open_selection)
			_button(_dialogue_content, "Rester", interactions.close)
	return result


func retry_departure() -> bool:
	if not _departure_pending:
		return false
	var success: bool = _manager().retry_expedition_save()
	if success:
		AudioManager.play_feedback(&"confirm")
	_departure_pending = not success
	return success


func return_to_title() -> void:
	if _departure_pending:
		return
	if _entry_run != null:
		_manager().cancel_catabase_threshold()
	_manager().request_return_to_title()


func _open_selection() -> void:
	if _departure_pending:
		return
	if _entry_run != null:
		_manager().cancel_catabase_threshold()
	get_tree().change_scene_to_file("res://ui/selection/CharacterSelectionScreen.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _interface == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _departure_started:
				return
			if _menu_open:
				close_dialogue()
			elif interactions != null and interactions.active:
				interactions.close()
			else:
				show_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and not entry_input_blocked():
			_approach_nearest()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _ready_for_play:
		_hovered = interactions.hit_test(world.to_local(event.position)) if not interactions.blocked() else -1
		Input.set_default_cursor_shape(
			Input.CURSOR_POINTING_HAND if _hovered >= 0 else Input.CURSOR_ARROW
		)
		_update_status()
	if event is InputEventMouseButton:
		super._unhandled_input(event)
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not interactions.blocked():
			_show_movement_feedback("Déplacement arrêté")


func get_entry_state() -> Dictionary:
	return {
		"configured": _entry_run != null,
		"departure_started": _departure_started,
		"save_pending": _departure_pending,
		"menu_open": _menu_open,
		"welcome_open": is_instance_valid(_welcome) and _welcome.visible,
		"variant": str(_entry_run.hero_visual_variants.get("achilles", "")) if _entry_run != null else "",
		"ready": is_ready_for_play(),
	}


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	super._exit_tree()


func request_move(destination: Vector2) -> bool:
	if not _ready_for_play or paused or interactions.blocked():
		return false
	var route: Dictionary = (nav as ThresholdNavigation).resolve_destination(
		player.position,
		destination,
		world_size.x * 0.045,
	)
	if not bool(route.get("ok", false)):
		_show_movement_feedback("Ce passage est inaccessible · Choisissez le chemin dégagé")
		return false
	interactions.cancel()
	_path = route.path
	_path_index = 0
	_target = route.destination
	_marker.position = _target
	_marker.show()
	_show_movement_feedback(
		(
			"Destination rapprochée du chemin praticable"
			if route.adjusted
			else "En route · Clic droit pour s’arrêter"
		)
	)
	_refresh_route()
	return true


func announce_approach(index: int) -> void:
	_show_movement_feedback(
		"En route vers %s · Clic droit pour s’arrêter" % str(definition.landmarks[index].title)
	)


func _show_movement_feedback(message: String) -> void:
	_movement_feedback = message
	_feedback_until = clock + 4.0
	_update_status()


func _refresh_route() -> void:
	if not is_instance_valid(_route_line):
		return
	var remaining := PackedVector2Array()
	if is_player_moving():
		remaining.append(player.position)
		for index in range(_path_index, _path.size()):
			if remaining[-1].distance_to(_path[index]) > 0.1:
				remaining.append(_path[index])
	_route_line.points = remaining
	_route_line.visible = remaining.size() >= 2 and not original


func stop_movement(cancel_interaction := true) -> void:
	super.stop_movement(cancel_interaction)
	_refresh_route()


func _advance_move(delta: float) -> void:
	if not is_player_moving():
		return
	var remaining := 0.0
	var previous := player.position
	for index in range(_path_index, _path.size()):
		remaining += _ground_distance(_path[index] - previous)
		previous = _path[index]
	var desired_speed := minf(float(definition.world.speed), sqrt(1200.0 * remaining))
	if _path_index + 1 < _path.size():
		var approach := _path[_path_index] - player.position
		var departure := _path[_path_index + 1] - _path[_path_index]
		var angle := absf(approach.angle_to(departure)) if not approach.is_zero_approx() else 0.0
		var corner_speed := float(definition.world.speed) * lerpf(
			1.0,
			0.35,
			clampf(angle / PI, 0.0, 1.0),
		)
		desired_speed = minf(
			desired_speed,
			sqrt(corner_speed * corner_speed + 1200.0 * _ground_distance(approach)),
		)
	_speed = move_toward(_speed, desired_speed, 800.0 * delta)
	var travel := _speed * delta
	while is_player_moving() and travel > 0.0:
		var offset := _path[_path_index] - player.position
		var distance := _ground_distance(offset)
		if distance < 0.15:
			_path_index += 1
			continue
		var used := minf(travel, distance)
		var next := player.position + offset * used / distance
		if not (nav as ThresholdNavigation).segment_is_walkable(player.position, next):
			stop_movement()
			_show_movement_feedback("Le passage est bloqué · Choisissez une autre destination")
			return
		player.play_walk(offset)
		player.position = next
		player.advance_ground_stride(used)
		ambience.advance(
			player.normalized_stride_distance(used),
			paused,
			audio_enabled and not original,
		)
		travel -= used
		if used >= distance:
			_path_index += 1
	if not is_player_moving():
		stop_movement(false)


func get_movement_state() -> Dictionary:
	return {
		"destination": _target,
		"path": _path.duplicate(),
		"path_index": _path_index,
		"moving": is_player_moving(),
		"feedback": _movement_feedback,
	}
