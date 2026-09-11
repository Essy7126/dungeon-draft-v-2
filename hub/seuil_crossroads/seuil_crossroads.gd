extends "res://hub/painted_halt/living_halt.gd"
## The cleared opening becomes a free-walking room. Rewards remain transactions.
const Routes := preload("res://hub/seuil_crossroads/seuil_route_choices.gd")
const ExitInteractions := preload("res://hub/catabase_threshold/threshold_interactions.gd")
const WalkNavigation := preload("res://hub/catabase_threshold/threshold_navigation.gd")
const Attributes := preload("res://ui/expedition/expedition_attributes_view.gd")
var _dialogue: PanelContainer
var _content: VBoxContainer
var _message: Label
var _departing := false


func _init() -> void:
	nav = WalkNavigation.new()


func _ready() -> void:
	reduced = GameManager.is_reduced_motion_enabled()
	await super._ready()
	# Keep the painted stone and lantern frames stable; only their light breathes.
	effect_material.set_shader_parameter("fire_warp_strength", 0.0)
	effect_material.set_shader_parameter("fire_flicker_speed", 0.25)
	get_window().title = "Le Seuil de Catabase — trois chemins"


func _create_interactions() -> Interactions:
	return ExitInteractions.new()


func entry_input_blocked() -> bool:
	var persistent := GameManager.get_persistent_run_ui()
	return _departing or (persistent != null and persistent.has_active_modal())


func announce_approach(index: int) -> void:
	_message.text = "Approche : " + str(definition.landmarks[index].title)


func get_movement_state() -> Dictionary:
	return { "destination": _target, "moving": is_player_moving() }


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "CrossroadsInterface"
	add_child(canvas)
	_interface = Control.new()
	_interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interface.theme = _theme()
	canvas.add_child(_interface)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 18
	_interface.add_child(top)
	var title := Label.new()
	title.text = "Le Seuil de Catabase · Combat terminé"
	title.add_theme_font_override("font", TITLE)
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_button(
		top,
		"Butin et préparatifs",
		func():
			interactions.active = true
			interactions.selected = -1
			stop_movement()
			show_landmark(-1),
	)
	_message = Label.new()
	_message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message.offset_top = -48
	_message.offset_bottom = -16
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_shadow_color", Color.BLACK)
	_message.add_theme_constant_override("shadow_offset_y", 2)
	_message.text = "Cliquez pour marcher · 1 Barque · 2 Porte ronde · 3 Puits"
	_interface.add_child(_message)
	_dialogue = PanelContainer.new()
	_dialogue.name = "CrossroadsChoices"
	_dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue.anchor_left = 0.12
	_dialogue.anchor_right = 0.88
	_dialogue.anchor_top = 0.13
	_dialogue.anchor_bottom = 0.86
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142321fa")
	style.border_color = Color("b39461")
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	_dialogue.add_theme_stylebox_override("panel", style)
	_interface.add_child(_dialogue)
	var scroll := ScrollContainer.new()
	_dialogue.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_dialogue.hide()


func _text(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)


func show_landmark(index: int) -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_dialogue.show()
	var session := GameManager.expedition
	var has_points := (
		session != null and session.character.champion_progression.unspent_attribute_points > 0
	)
	var has_reward := session != null and session.route.phase == "reward"
	_dialogue.anchor_left = 0.10 if has_points else (0.20 if has_reward else 0.25)
	_dialogue.anchor_right = 1.0 - _dialogue.anchor_left
	_dialogue.anchor_top = 0.10 if has_points else (0.23 if has_reward else 0.34)
	_dialogue.anchor_bottom = 0.90 if has_points else (0.80 if has_reward else 0.66)
	var route: Dictionary = Routes.destination(session, str(definition.landmarks[index].id)) if index >= 0 else { }
	_text(
		(
			str(definition.landmarks[index].title) + " → "
			+ str(route.get("title", "Chemin indisponible"))
			if index >= 0
			else "Butin et préparatifs"
		)
	)
	if session == null:
		_text(
			"Visite d'atelier : les trois sorties s'activent après la victoire du premier combat."
		)
	elif bool(GameManager.get_expedition_save_status().get("pending", false)):
		_text("Le départ attend l'enregistrement de vos choix.")
		_button(
			_content,
			"Réessayer la sauvegarde",
			func():
				GameManager.retry_expedition_save()
				if is_inside_tree():
					show_landmark(index),
		)
	elif session.character.champion_progression.unspent_attribute_points > 0:
		_text("Répartissez vos nouveaux points avant de partir.")
		var attributes := Attributes.new()
		attributes.custom_minimum_size.y = maxf(300, get_viewport_rect().size.y * 0.5)
		_content.add_child(attributes)
		attributes.configure(session)
		attributes.attribute_requested.connect(
			func(id: StringName):
				GameManager.spend_champion_attribute(&"achilles", id)
				show_landmark(index),
		)
	elif session.route.phase == "reward":
		_text("Choisissez le butin du combat avant de prendre ce passage.")
		for offer in session.reward_options(GameManager.item_catalog):
			var option: String = offer.id
			var reward_button := _button(
				_content,
				str(offer.title),
				func():
					var result := GameManager.claim_expedition_reward(option)
					_message.text = str(result.get("message", ""))
					show_landmark(index),
			)
			reward_button.name = "SeuilReward_" + option
			_text(str(offer.description))
	elif not route.is_empty():
		_text(str(definition.landmarks[index].description))
		_button(
			_content,
			"Emprunter ce passage",
			func():
				depart(index),
		)
	else:
		_text("Vous êtes prêt. Rejoignez la barque, la porte ou le puits.")
	_button(
		_content,
		"Revenir au Seuil",
		func():
			interactions.close(),
	)


func close_dialogue() -> void:
	_dialogue.hide()


func depart(index: int) -> bool:
	if _departing or index < 0 or index >= definition.landmarks.size():
		return false
	var session := GameManager.expedition
	if not Routes.can_depart(session) or GameManager.get_expedition_save_status().get(
			"pending",
			false,
		):
		return false
	var destination := Routes.destination(session, str(definition.landmarks[index].id))
	if destination.is_empty():
		return false
	_departing = true
	var success := GameManager.choose_expedition_node(str(destination.id))
	if not success:
		_departing = false
		show_landmark(index)
	return success


func _update_status() -> void:
	pass


func _button(parent: Node, label: String, callback: Callable) -> Button:
	var button := super._button(parent, label, callback)
	button.custom_minimum_size.y = 40
	button.add_theme_font_size_override("font_size", 18)
	return button
