extends "res://tools/labs/apothecary_living_map/playable_hall.gd"

## Production halt: the painting owns presentation; GameManager owns every receipt,
## price, health change, stock choice, departure and save operation.
const SERVICE_APPROACHES := [Vector2(423, 501), Vector2(720, 399), Vector2(938, 490), Vector2(638, 617), Vector2(778, 444)]
const SERVICE_CAPTIONS := ["Reliques", "Poteries", "Arcanes", "Repos", "Mémoire"]
const STALL_RECTS := [Rect2(285, 319, 273, 160), Rect2(650, 145, 177, 176), Rect2(897, 171, 249, 306)]

var _halt_valid := false
var _selected_service_id := ""
var _pending_service_id := ""
var _service_ids: Array[String] = []
var _service_buttons: Array[Button] = []
var _service_overlay: ColorRect
var _service_card: PanelContainer
var _service_title: Label
var _service_description: Label
var _service_price: Label
var _service_result: Label
var _confirm_service: Button
var _close_service: Button
var _resources: Label
var _leave_button: Button
var _workshop_button: Button
var _menu_button: Button
var _retry_save_button: Button
var _transaction_running := false
var _receipt_applied := false
var _departure_recovery_queued := false


func _ready() -> void:
	_halt_valid = _is_active_halt()
	if not _halt_valid:
		_build_unavailable()
		return
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
	await super._ready()
	if not is_inside_tree():
		return
	_feedback = "Approchez d’un étal pour découvrir ses objets."
	_feedback_until = _time + 6.0
	var persistent := GameManager.get_persistent_run_ui()
	if persistent != null:
		persistent.inventory_screen.screen_closed.connect(_on_inventory_closed)
	GameManager.expedition_save_status_changed.connect(_on_save_status_changed)
	_update_labels()


func is_ready_for_play() -> bool:
	return _halt_valid and _walk_ready and _is_active_halt()


func _process(delta: float) -> void:
	if _halt_valid:
		super._process(delta)


func _advance_movement(delta: float) -> void:
	if not _interaction_blocked():
		super._advance_movement(delta)


func _finish_movement() -> void:
	super._finish_movement()
	if not _pending_service_id.is_empty():
		_selected_service_id = _pending_service_id
		_pending_service_id = ""
		_open_service_panel()


func request_move(native_point: Vector2) -> bool:
	if not is_ready_for_play() or _interaction_blocked():
		return false
	_pending_service_id = ""
	return super.request_move(native_point)


func stop_movement() -> void:
	_pending_service_id = ""
	super.stop_movement()


func request_service(service_id: String) -> bool:
	if not is_ready_for_play() or _interaction_blocked():
		return false
	var services := _services()
	var index := -1
	for candidate in services.size():
		if str(services[candidate].id) == service_id:
			index = candidate
			break
	if index < 0 or index >= SERVICE_APPROACHES.size():
		return false
	_selected_service_id = service_id
	_pending_service_id = service_id
	_receipt_applied = false
	_service_result.text = ""
	if not super.request_move(SERVICE_APPROACHES[index]):
		_pending_service_id = ""
		return false
	return true


func get_selected_service_id() -> String:
	return _selected_service_id


func is_service_panel_open() -> bool:
	return is_instance_valid(_service_overlay) and _service_overlay.visible


func _open_service_panel() -> void:
	if _selected_service().is_empty():
		return
	_service_overlay.show()
	_hover_marker.hide()
	_refresh_service_panel()
	_close_service.grab_focus()


func close_service_panel() -> void:
	if is_instance_valid(_service_overlay):
		_service_overlay.hide()
	_last_hover = Vector2(INF, INF)
	_update_labels()


func activate_selected_service() -> Dictionary:
	if not is_ready_for_play() or not is_service_panel_open() or _transaction_running or _persistent_modal_open():
		return {"success": false, "message": "Ce service n’est pas accessible pour le moment."}
	var service := _selected_service()
	var reason := _service_unavailable_reason(service)
	if not reason.is_empty():
		_service_result.text = reason
		_refresh_service_panel()
		return {"success": false, "message": reason}
	_transaction_running = true
	_confirm_service.disabled = true
	var result: Dictionary = GameManager.use_catabase_hub_service(_selected_service_id)
	_transaction_running = false
	# A successful transaction remains applied in memory even if its disk save fails.
	# Only retry_expedition_save may retry that write; never repeat the service call.
	_receipt_applied = bool(result.get("success", false))
	_service_result.text = str(result.get("message", result.get("reason", "")))
	_update_labels()
	_refresh_service_panel()
	return result


func _services() -> Array[Dictionary]:
	if not _is_active_halt() or GameManager.expedition == null:
		return []
	return GameManager.expedition.hub_services(GameManager.item_catalog)


func _selected_service() -> Dictionary:
	for service: Dictionary in _services():
		if str(service.id) == _selected_service_id:
			return service
	return {}


func _service_unavailable_reason(service: Dictionary) -> String:
	if _save_pending():
		return "L’enregistrement doit être rétabli avant une nouvelle transaction."
	if service.is_empty():
		return "Ce service n’est plus disponible."
	if _receipt_applied or bool(service.get("used", false)):
		return "Déjà utilisé pendant cette halte."
	var missing := int(service.get("cost", 0)) - GameManager.expedition.gold
	if missing > 0:
		return "Il vous manque %d oboles." % missing
	if str(service.id) == "rest":
		var hero := GameManager.expedition.character.unit
		if hero.current_hp >= hero.max_hp.get_int():
			return "Vos PV sont déjà au maximum."
	return ""


func _is_active_halt() -> bool:
	return GameManager.has_method("is_merchant_hall_active") and bool(GameManager.call("is_merchant_hall_active"))


func _save_pending() -> bool:
	return bool(GameManager.get_expedition_save_status().get("pending", false))


func _persistent_modal_open() -> bool:
	var persistent := GameManager.get_persistent_run_ui()
	return persistent != null and persistent.has_active_modal()


func _interaction_blocked() -> bool:
	return is_service_panel_open() or _persistent_modal_open() or _save_pending() or _transaction_running


func _input(event: InputEvent) -> void:
	if not _halt_valid or _persistent_modal_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_service_panel_open():
				close_service_panel()
				get_viewport().set_input_as_handled()
			elif is_player_moving():
				stop_movement()
				get_viewport().set_input_as_handled()
			# Otherwise PersistentRunUI owns the global pause menu.
			return
		if _interaction_blocked():
			return
		if event.keycode == KEY_H:
			set_chrome_visible(not _chrome_visible)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:
			get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_request_service_index(int(event.keycode) - int(KEY_1))
			get_viewport().set_input_as_handled()
		# Tab and Space deliberately retain their normal inventory/focus semantics.


func _unhandled_input(event: InputEvent) -> void:
	if not is_ready_for_play() or _interaction_blocked():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			stop_movement()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var native := _world.to_local(event.position)
			for index in STALL_RECTS.size():
				if STALL_RECTS[index].has_point(native):
					_request_service_index(index)
					get_viewport().set_input_as_handled()
					return
			super._unhandled_input(event)


func _update_hover() -> void:
	if _interaction_blocked():
		_hover_marker.hide()
		_last_hover = Vector2(INF, INF)
		return
	super._update_hover()


func _request_service_index(index: int) -> void:
	if index >= 0 and index < _service_ids.size():
		request_service(_service_ids[index])


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "MerchantHallInterface"
	canvas.layer = 2
	add_child(canvas)
	_chrome = Control.new()
	_chrome.name = "HallControls"
	canvas.add_child(_chrome)
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.theme = _theme()
	_top = _make_panel(_chrome, Control.PRESET_TOP_WIDE)
	_top.offset_top = 12
	_top.offset_bottom = 82
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	_top.add_child(top_row)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(titles)
	var title := _label(titles, "La Halle sous les racines", 23, INK)
	title.add_theme_font_override("font", TITLE_FONT)
	_resolution = _label(titles, "Étape IV · L’étal du passeur", 14, GOLD)
	_resources = _label(top_row, "", 17, INK)
	_resources.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_workshop_button = _button("Carte et préparatifs")
	_workshop_button.name = "ExpeditionWorkshop"
	_workshop_button.pressed.connect(_open_workshop)
	top_row.add_child(_workshop_button)
	_menu_button = _button("Menu")
	_menu_button.name = "MerchantHallMenu"
	_menu_button.pressed.connect(_open_menu)
	top_row.add_child(_menu_button)
	_bottom = _make_panel(_chrome, Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_top = -88
	_bottom.offset_bottom = -12
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	_bottom.add_child(stack)
	var service_row := HBoxContainer.new()
	service_row.add_theme_constant_override("separation", 9)
	stack.add_child(service_row)
	for index in SERVICE_CAPTIONS.size():
		var button := _button("%d · %s" % [index + 1, SERVICE_CAPTIONS[index]])
		button.name = "Service_%d" % index
		button.pressed.connect(_request_service_index.bind(index))
		service_row.add_child(button)
		_service_buttons.append(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	service_row.add_child(spacer)
	_retry_save_button = _button("Réessayer l’enregistrement")
	_retry_save_button.name = "RetryHallSave"
	_retry_save_button.pressed.connect(_retry_save)
	_retry_save_button.hide()
	service_row.add_child(_retry_save_button)
	_leave_button = _button("Reprendre la route  →")
	_leave_button.name = "LeaveMerchantHall"
	_leave_button.pressed.connect(_leave_hall)
	service_row.add_child(_leave_button)
	_status = _label(stack, "", 14, Color("b8baab"))
	_build_service_panel(canvas)
	_update_labels()


func _make_panel(parent: Control, preset: int) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = 20
	panel.offset_right = -20
	var style := _panel_style()
	style.bg_color = Color(0.07, 0.105, 0.11, 0.94)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _build_service_panel(canvas: CanvasLayer) -> void:
	_service_overlay = ColorRect.new()
	_service_overlay.name = "ServiceModal"
	_service_overlay.color = Color(0.018, 0.028, 0.03, 0.40)
	canvas.add_child(_service_overlay)
	_service_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_service_overlay.theme = _theme()
	var center := CenterContainer.new()
	_service_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_card = PanelContainer.new()
	_service_card.custom_minimum_size.x = 510
	_service_card.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_service_card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	_service_card.add_child(content)
	_label(content, "L’ÉTAL DU PASSEUR", 12, GOLD)
	_service_title = _label(content, "", 25, INK)
	_service_title.add_theme_font_override("font", TITLE_FONT)
	_service_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_service_description = _label(content, "", 18, INK)
	_service_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_service_description.custom_minimum_size.x = 470
	_service_price = _label(content, "", 16, GOLD)
	_service_result = _label(content, "", 16, Color("b8baab"))
	_service_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	_close_service = _button("Fermer")
	_close_service.name = "CloseService"
	_close_service.pressed.connect(close_service_panel)
	actions.add_child(_close_service)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_confirm_service = _button("Acheter")
	_confirm_service.name = "ConfirmService"
	_confirm_service.pressed.connect(activate_selected_service)
	actions.add_child(_confirm_service)
	_service_overlay.hide()


func _refresh_service_panel() -> void:
	if not is_service_panel_open():
		return
	var service := _selected_service()
	_service_title.text = str(service.get("title", "Service indisponible"))
	_service_description.text = str(service.get("description", "Cette halte n’est plus ouverte."))
	var reason := _service_unavailable_reason(service)
	var cost := int(service.get("cost", 0))
	_service_price.text = "%d oboles" % cost if cost > 0 else "Sans dépense d’oboles"
	if not reason.is_empty():
		_service_price.text += " · " + reason
	_service_price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_service.disabled = _transaction_running or not reason.is_empty() or _persistent_modal_open()
	if _receipt_applied or bool(service.get("used", false)):
		_confirm_service.text = "Déjà utilisé"
	elif _selected_service_id.begins_with("buy:"):
		_confirm_service.text = "Acheter · %d oboles" % cost
	elif _selected_service_id == "rest":
		_confirm_service.text = "Se reposer · %d oboles" % cost
	else:
		_confirm_service.text = "Recueillir la mémoire"


func _update_labels() -> void:
	if not is_instance_valid(_status) or not _halt_valid:
		return
	var services := _services()
	_service_ids.clear()
	for service: Dictionary in services:
		_service_ids.append(str(service.id))
	var blocked := not is_ready_for_play() or _interaction_blocked()
	for index in _service_buttons.size():
		var button := _service_buttons[index]
		button.disabled = blocked or index >= services.size()
		if index < services.size():
			button.text = "%d · %s%s" % [index + 1, SERVICE_CAPTIONS[index], " ✓" if bool(services[index].get("used", false)) else ""]
			button.tooltip_text = str(services[index].title)
	if GameManager.expedition != null:
		var hero := GameManager.expedition.character.unit
		_resources.text = "%d / %d PV  ·  %d oboles" % [hero.current_hp, hero.max_hp.get_int(), GameManager.expedition.gold]
		var node := GameManager.expedition.route.get_current_node()
		var depth := int(node.get("depth", 4))
		_resolution.text = "Étape %s · %s" % ["IV" if depth == 4 else str(depth), str(node.get("title", "L’étal du passeur"))]
	_leave_button.disabled = blocked
	_workshop_button.disabled = blocked
	_menu_button.disabled = is_service_panel_open() or _persistent_modal_open()
	_retry_save_button.visible = _save_pending() and not is_service_panel_open()
	_retry_save_button.disabled = _persistent_modal_open()
	_status.text = "Clic : se déplacer  ·  Clic droit : s’arrêter  ·  Échap : menu  ·  H : masquer l’interface"
	if is_player_moving() and not _pending_service_id.is_empty():
		_status.text = "Achille rejoint l’étal…"
	elif _time < _feedback_until and not _feedback.is_empty():
		_status.text = _feedback
	if _save_pending():
		_status.text = str(GameManager.get_expedition_save_status().get("message", "Enregistrement en attente."))
	_refresh_service_panel()


func _fit_world() -> void:
	if not is_instance_valid(_world):
		return
	var viewport_size := get_viewport_rect().size
	var factor := minf(viewport_size.x / NATIVE_SIZE.x, viewport_size.y / NATIVE_SIZE.y)
	_world.scale = Vector2.ONE * factor
	_world.position = (viewport_size - NATIVE_SIZE * factor) * 0.5
	_last_hover = Vector2(INF, INF)


func _open_workshop() -> void:
	if _interaction_blocked():
		return
	stop_movement()
	if not bool(GameManager.call("open_expedition_workshop")):
		_feedback = str(GameManager.get_expedition_save_status().get("message", "Les préparatifs ne sont pas accessibles."))
		_feedback_until = _time + 8.0
		_update_labels()


func _leave_hall() -> void:
	if _interaction_blocked():
		return
	stop_movement()
	var result: Dictionary = GameManager.call("leave_merchant_hall")
	if not bool(result.get("success", false)):
		_feedback = str(result.get("message", "Impossible de reprendre la route."))
		_feedback_until = _time + 8.0
		_update_labels()


func _open_menu() -> void:
	if is_service_panel_open() or _persistent_modal_open():
		return
	stop_movement()
	var persistent := GameManager.get_persistent_run_ui()
	if persistent != null:
		persistent.open_pause_menu()


func _retry_save() -> void:
	GameManager.retry_expedition_save()
	_update_labels()


func _on_save_status_changed(status_value: Dictionary) -> void:
	_update_labels()
	# Leaving consumes the halt before writing the checkpoint. Another legitimate
	# save (for example after closing inventory) can subsequently finish that write
	# without retaining the original departure operation. Recover the presentation
	# only; the halt receipt and route must never be applied a second time.
	if bool(status_value.get("success", false)) and _halt_valid \
			and not _departure_recovery_queued and not _is_active_halt() \
			and GameManager.expedition != null and GameManager.expedition.route.phase == "map":
		_departure_recovery_queued = true
		_recover_saved_departure.call_deferred()


func _recover_saved_departure() -> void:
	if not is_inside_tree():
		_departure_recovery_queued = false
		return
	var scene_tree := get_tree()
	# Give the normal departure/retry transition time to replace this scene first.
	await scene_tree.process_frame
	if is_inside_tree() and scene_tree.current_scene == self \
			and GameManager.run_active and GameManager.expedition != null \
			and GameManager.expedition.route.phase == "map" and not _save_pending():
		GameManager.open_expedition_workshop()
	_departure_recovery_queued = false


func _on_inventory_closed() -> void:
	if _halt_valid and _is_active_halt():
		GameManager.save_expedition()
		_update_labels()


func _build_unavailable() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var center := CenterContainer.new()
	canvas.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.theme = _theme()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	_label(content, "La Halle n’est pas ouverte", 25, INK)
	_label(content, "Rejoignez une halte marchande depuis votre expédition.", 17, INK)
	var back := _button("Retour au titre")
	back.name = "MerchantHallUnavailableReturn"
	back.pressed.connect(func() -> void: GameManager.request_return_to_title())
	content.add_child(back)
