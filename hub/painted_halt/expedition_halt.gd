extends "res://hub/painted_halt/living_halt.gd"
## Uses the existing session/save transition boundary, including failed saves.
var _resources: Label
var _save_retry: Button
var _return_queued := false


func _ready() -> void:
	preview_mode = false
	manifest_path = GameManager.get_painted_halt_manifest()
	if manifest_path.is_empty():
		_error = "Cette halte n’est pas disponible dans l’expédition actuelle."
		_build_error()
		return
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
	await super._ready()
	if not is_inside_tree():
		return
	GameManager.expedition_save_status_changed.connect(_on_halt_state_changed, CONNECT_DEFERRED)
	var persistent := GameManager.get_persistent_run_ui()
	if persistent != null:
		persistent.inventory_screen.screen_closed.connect(_on_halt_state_changed, CONNECT_DEFERRED)


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 2
	add_child(canvas)
	_interface = Control.new()
	canvas.add_child(_interface)
	_interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interface.theme = _theme()
	var margin := MarginContainer.new()
	_interface.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.offset_left = 18
	margin.offset_right = -18
	margin.offset_top = 12
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211c18f2")
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)
	var title := Label.new()
	title.text = str(definition.title)
	title.add_theme_font_override("font", TITLE)
	title.add_theme_font_size_override("font_size", 20)
	names.add_child(title)
	_resources = Label.new()
	_resources.add_theme_font_size_override("font_size", 14)
	names.add_child(_resources)
	for index in definition.landmarks.size():
		_button(row, str(definition.landmarks[index].title), interactions.request.bind(index))
	_button(row, "Parchemin", _open_parchment)
	_save_retry = _button(row, "Réessayer l’enregistrement", _retry_save)
	_update_status()


func _update_status() -> void:
	if _resources == null or GameManager.expedition == null:
		return
	var pending := bool(GameManager.get_expedition_save_status().get("pending", false))
	if pending:
		_resources.text = str(GameManager.get_expedition_save_status().get("message", ""))
	else:
		var balance: int = GameManager.expedition.gold
		_resources.text = "%d oboles · Clic pour explorer · Approchez des lieux pour interagir" % balance
	_save_retry.visible = pending


func _on_halt_state_changed(_status: Dictionary = { }) -> void:
	if interactions != null and interactions.active:
		interactions.refresh()
	_update_status()
	# Departure may already be applied when its checkpoint failed. A successful
	# inventory save must finish the return without claiming the halt twice.
	if (
		not _return_queued and GameManager.expedition != null
		and GameManager.expedition.route.phase == "map"
		and not bool(GameManager.get_expedition_save_status().get("pending", false))
	):
		_return_queued = true
		call_deferred("_return_to_map")


func _return_to_map() -> void:
	if not is_inside_tree():
		_return_queued = false
		return
	var scene_tree := get_tree()
	# Let the normal departure/retry replace this scene before recovering a
	# checkpoint completed by a different action, such as closing inventory.
	await scene_tree.process_frame
	if is_inside_tree() and scene_tree.current_scene == self:
		_recover_saved_destination()
	_return_queued = false


func _recover_saved_destination() -> void:
	if (
		GameManager.run_active and GameManager.expedition != null
		and GameManager.expedition.route.phase == "map"
		and not bool(GameManager.get_expedition_save_status().get("pending", false))
	):
		GameManager.open_expedition_workshop()


func _open_parchment() -> void:
	interactions.cancel()
	stop_movement()
	GameManager.open_expedition_workshop()


func _retry_save() -> void:
	GameManager.retry_expedition_save()


func _input(event: InputEvent) -> void:
	var persistent := GameManager.get_persistent_run_ui()
	if persistent != null and persistent.has_active_modal():
		return
	if (
		interactions != null and interactions.active and event is InputEventKey
		and event.pressed and event.keycode == KEY_ESCAPE
	):
		interactions.close()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# PersistentRunUI owns inventory, map and pause shortcuts in production.
	if event is InputEventMouseButton:
		super._unhandled_input(event)
