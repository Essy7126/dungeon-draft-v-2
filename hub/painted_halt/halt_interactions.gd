extends Node
## Local approach points dispatch common services. The modal owns input while
## open; a transaction is never repeated when only its checkpoint needs retrying.
const BRIDGE := preload("res://hub/painted_halt/halt_session_bridge.gd")
var hall
var bridge := BRIDGE.new()
var pending := -1
var selected := -1
var active := false
var awakened: Dictionary = { }
var _busy := false
var _overlay: ColorRect
var _title: Label
var _balance: Label
var _body: VBoxContainer
var _result: Label
var _close: Button
var _previous_focus: WeakRef


func configure(owner_hall, preview: bool) -> void:
	hall = owner_hall
	bridge.configure(preview, null if preview else GameManager)
	_build_panel()


func blocked() -> bool:
	if active or _busy or bridge.blocked():
		return true
	if not bridge.preview:
		var persistent = GameManager.get_persistent_run_ui()
		return persistent != null and persistent.has_active_modal()
	return false


func request(index: int) -> bool:
	if blocked() or hall.paused or index < 0 or index >= hall.definition.landmarks.size():
		return false
	var destination: Vector2 = hall.point(hall.definition.landmarks[index].point)
	# A floor request cancels the preceding interaction; assign only on success.
	if not hall.request_move(destination):
		return false
	pending = index
	return true


func cancel() -> void:
	pending = -1


func after_movement() -> void:
	if pending < 0 or hall.is_player_moving() or hall.paused:
		return
	var index := pending
	pending = -1
	var at: Vector2 = hall.point(hall.definition.landmarks[index].point)
	if hall.player.position.distance_to(at) < 2.0:
		open(index)


func hit_test(at: Vector2) -> int:
	for index: int in hall.definition.landmarks.size():
		var landmark: Dictionary = hall.definition.landmarks[index]
		var focus: Vector2 = hall.point(landmark.get("focus", landmark.point))
		var delta := Vector2(at.x - focus.x, (at.y - focus.y) * 1.4)
		if delta.length() <= float(landmark.get("radius", 0.045)) * hall.world_size.x:
			return index
	return -1


func open(index: int) -> void:
	if not active or selected != index:
		AudioManager.play_feedback(&"open")
	selected = index
	active = true
	hall.stop_movement()
	var focus: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_overlay.show()
	_result.text = ""
	refresh()
	_close.grab_focus()


func close() -> void:
	if active:
		AudioManager.play_feedback(&"close")
	active = false
	_overlay.hide()
	if _previous_focus != null:
		var previous: Control = _previous_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree():
			previous.grab_focus()


func refresh() -> void:
	if selected < 0:
		return
	var landmark: Dictionary = hall.definition.landmarks[selected]
	_title.text = str(landmark.title)
	var context: Dictionary = bridge.context()
	_balance.text = "%d oboles%s" % [
		context.get("balance", 0),
		" · visite d’essai" if bridge.preview else "",
	]
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var action := str(landmark.get("action", "dialogue"))
	if action == "exit":
		_label("Reprendre le chemin termine les préparatifs de cette halte.")
		var leave := _button(
			"Terminer la visite" if bridge.preview else "Reprendre le chemin",
			"LeavePaintedHalt",
		)
		leave.disabled = bridge.blocked()
		leave.pressed.connect(_leave)
	else:
		_label(
			str(landmark.get("description", "Les pierres gardent le souvenir de votre passage."))
		)
		var preferred := {
			"sanctuary": "sanctuary",
			"merchant": "merchant",
			"dialogue": "lore",
			"rest": "hub",
		}.get(action, "") as String
		var offers: Array = context.get("services", []).duplicate(true)
		offers.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.kind) == preferred and str(b.kind) != preferred,
		)
		# Every existing halt service remains accessible. Landmark purpose sets order.
		for service: Dictionary in offers:
			var row := VBoxContainer.new()
			_body.add_child(row)
			var used := bool(service.get("used", false))
			var button := Button.new()
			button.name = "Service_" + str(service.id).replace(":", "_")
			button.text = "%s · %s" % [
				service.title,
				"Accompli" if used else ("%d oboles" % int(service.get("cost", 0))),
			]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.disabled = used or not bool(service.get("available", false)) or bridge.blocked()
			row.add_child(button)
			button.pressed.connect(activate.bind(str(service.id)))
			var description := Label.new()
			description.text = str(service.get("description", ""))
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			description.add_theme_font_size_override("font_size", 14)
			row.add_child(description)
	if bridge.blocked() and not bridge.preview:
		var retry := _button("Réessayer l’enregistrement", "RetryHaltSave")
		retry.pressed.connect(
			func():
				var result := bridge.retry_save()
				_result.text = str(result.get("message", ""))
				refresh(),
		)


func activate(service_id: String) -> Dictionary:
	if not active or _busy or hall.paused:
		return { "success": false }
	_busy = true
	var result := bridge.use_service(service_id)
	AudioManager.play_feedback(&"confirm" if bool(result.get("success", false)) else &"error")
	_busy = false
	if bool(result.get("success", false)):
		awakened[str(hall.definition.landmarks[selected].id)] = true
	_result.text = str(result.get("message", ""))
	refresh()
	return result


func _leave() -> void:
	if _busy or hall.paused:
		return
	_busy = true
	var result := bridge.leave()
	_busy = false
	_result.text = str(result.get("message", ""))
	if bool(result.get("success", false)):
		hall.visit_finished.emit()
	refresh()


func _button(text: String, id: String) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	_body.add_child(button)
	return button


func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)


func _build_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 8
	add_child(canvas)
	_overlay = ColorRect.new()
	_overlay.name = "HaltInteractionModal"
	_overlay.color = Color(0.06, 0.05, 0.04, 0.76)
	_overlay.theme = hall._theme()
	canvas.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	_overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -270
	panel.offset_bottom = 270
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211c18")
	style.border_color = Color("8b714c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	stack.add_child(_title)
	_balance = Label.new()
	_balance.modulate = Color("d6c185")
	stack.add_child(_balance)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	scroll.add_child(_body)
	_result = Label.new()
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.modulate = Color("e2cd91")
	stack.add_child(_result)
	_close = Button.new()
	_close.text = "Revenir au lieu"
	_close.name = "CloseHaltInteraction"
	_close.pressed.connect(close)
	stack.add_child(_close)
	_overlay.hide()
