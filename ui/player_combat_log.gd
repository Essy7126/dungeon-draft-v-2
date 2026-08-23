extends CanvasLayer

var _panel: PanelContainer
var _entries: VBoxContainer
var _scroll: ScrollContainer
var _toggle_btn: Button
var _collapse_btn: Button
var _detailed: bool = false
var _expanded: bool = true
var _layout_initialized := false
var _tactical_focus := false
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _current_round: int = -1
var _max_entries: int = 90

func _ready() -> void:
	layer = 35
	_build_ui()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	DebugLogger.log_added.connect(_on_log_added)


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.disconnect(_apply_responsive_layout)
	if DebugLogger.log_added.is_connected(_on_log_added):
		DebugLogger.log_added.disconnect(_on_log_added)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 520)
	_panel.custom_minimum_size = Vector2(340, 250)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	_panel.add_child(root)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_input)
	root.add_child(header)

	var title := Label.new()
	title.text = "Historique"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_toggle_btn = Button.new()
	_toggle_btn.text = "Joueur"
	_toggle_btn.custom_minimum_size = Vector2(86, 28)
	_toggle_btn.tooltip_text = "Basculer entre log joueur et log detaille."
	_toggle_btn.pressed.connect(_toggle_mode)
	header.add_child(_toggle_btn)

	_collapse_btn = Button.new()
	_collapse_btn.text = "Fermer"
	_collapse_btn.custom_minimum_size = Vector2(72, 28)
	_collapse_btn.tooltip_text = "Replier ou ouvrir l'historique du combat."
	_collapse_btn.pressed.connect(_toggle_expanded)
	header.add_child(_collapse_btn)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(350, 200)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)

	_entries = VBoxContainer.new()
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_theme_constant_override("separation", 3)
	_scroll.add_child(_entries)


func _toggle_expanded() -> void:
	_expanded = not _expanded
	_apply_responsive_layout()


func set_tactical_focus(active: bool) -> void:
	if _tactical_focus == active:
		return
	_tactical_focus = active
	_apply_responsive_layout()


func get_layout_snapshot() -> Dictionary:
	return {
		"panel": Rect2(_panel.position, _panel.size),
		"expanded": _expanded and not _tactical_focus,
		"tactical_focus": _tactical_focus,
		"scroll_visible": _scroll.visible,
	}


func _apply_responsive_layout() -> void:
	if not is_instance_valid(_panel) or not is_instance_valid(_scroll):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.y <= 800.0 or viewport_size.x <= 1366.0
	if not _layout_initialized:
		_expanded = not compact
		_layout_initialized = true
	var effective_expanded := _expanded and not _tactical_focus
	var panel_width := clampf(
		viewport_size.x * (0.25 if compact else 0.22),
		300.0,
		370.0,
	)
	var panel_height := (
		clampf(viewport_size.y * 0.25, 180.0, 250.0)
		if effective_expanded
		else 44.0
	)
	_scroll.visible = effective_expanded
	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.size = Vector2(panel_width, panel_height)
	var reserved_bottom := 124.0 if compact else 160.0
	_panel.position = Vector2(
		12.0,
		maxf(12.0, viewport_size.y - reserved_bottom - panel_height - 12.0),
	)
	_panel.modulate.a = 0.72 if _tactical_focus else 1.0
	_collapse_btn.text = "Fermer" if effective_expanded else "Ouvrir"

func _toggle_mode() -> void:
	_detailed = not _detailed
	_toggle_btn.text = "Detail" if _detailed else "Joueur"
	_clear()
	_current_round = -1
	for entry in DebugLogger.entries:
		_add_entry_if_visible(entry)

func _on_log_added(entry: Dictionary) -> void:
	_add_entry_if_visible(entry)

func _add_entry_if_visible(entry: Dictionary) -> void:
	if not _should_show(entry):
		return
	var round_number: int = int(entry.get("turn", 0))
	if round_number != _current_round and round_number > 0:
		_current_round = round_number
		_add_round_header(round_number)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(330, 0)
	label.add_theme_font_size_override("normal_font_size", 12)
	label.tooltip_text = _detail_text(entry)
	label.text = _entry_bbcode(entry)
	_entries.add_child(label)
	_trim_entries()
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _should_show(entry: Dictionary) -> bool:
	var cat: int = int(entry.get("category", -1))
	var msg: String = str(entry.get("message", ""))
	if cat == DebugLogger.LogCategory.TURN and msg.begins_with("Round "):
		return false
	if _detailed:
		return true
	if int(entry.get("level", 0)) < DebugLogger.LogLevel.INFO:
		return false
	return cat in [DebugLogger.LogCategory.COMBAT, DebugLogger.LogCategory.STATS, DebugLogger.LogCategory.SPELL, DebugLogger.LogCategory.TERRAIN, DebugLogger.LogCategory.TURN]

func _entry_bbcode(entry: Dictionary) -> String:
	var cat: int = int(entry.get("category", DebugLogger.LogCategory.SYSTEM))
	var msg: String = str(entry.get("message", ""))
	var prefix := _prefix_for_category(cat)
	var color := _color_for_category(cat).to_html(false)
	return "[color=#%s][b]%s[/b][/color] %s" % [color, prefix, _escape_bbcode(msg)]

func _prefix_for_category(cat: int) -> String:
	match cat:
		DebugLogger.LogCategory.COMBAT:
			return "[COMBAT]"
		DebugLogger.LogCategory.STATS:
			return "[STATUT]"
		DebugLogger.LogCategory.SPELL:
			return "[SORT]"
		DebugLogger.LogCategory.TERRAIN:
			return "[TERRAIN]"
		DebugLogger.LogCategory.TURN:
			return "[TOUR]"
		DebugLogger.LogCategory.AI:
			return "[IA]"
	return "[SYS]"

func _color_for_category(cat: int) -> Color:
	match cat:
		DebugLogger.LogCategory.COMBAT:
			return Color(1.0, 0.55, 0.42)
		DebugLogger.LogCategory.STATS:
			return Color(0.95, 0.72, 1.0)
		DebugLogger.LogCategory.SPELL:
			return Color(0.54, 0.78, 1.0)
		DebugLogger.LogCategory.TERRAIN:
			return Color(0.55, 0.95, 0.62)
		DebugLogger.LogCategory.TURN:
			return Color(1.0, 0.82, 0.45)
		DebugLogger.LogCategory.AI:
			return Color(0.85, 0.85, 0.85)
	return Color(0.75, 0.75, 0.75)

func _detail_text(entry: Dictionary) -> String:
	var ctx: Dictionary = entry.get("context", {})
	if ctx.is_empty():
		return "Aucun detail de calcul disponible pour cette ligne."
	var parts: Array = []
	for key in ctx:
		parts.append("%s: %s" % [str(key), str(ctx[key])])
	return "\n".join(parts)

func _add_round_header(round_number: int) -> void:
	var label := Label.new()
	label.text = "Round %d" % round_number
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entries.add_child(label)

func _trim_entries() -> void:
	while _entries.get_child_count() > _max_entries:
		var child := _entries.get_child(0)
		_entries.remove_child(child)
		child.queue_free()

func _clear() -> void:
	for child in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()

func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = get_viewport().get_mouse_position() - _panel.position
	elif event is InputEventMouseMotion and _dragging:
		var viewport_size := get_viewport().get_visible_rect().size
		var pos := get_viewport().get_mouse_position() - _drag_offset
		pos.x = clampf(pos.x, 0.0, viewport_size.x - _panel.size.x)
		pos.y = clampf(pos.y, 0.0, viewport_size.y - _panel.size.y)
		_panel.position = pos

func _escape_bbcode(text: String) -> String:
	var escaped := text.replace("[", "__CODEX_LB__").replace("]", "__CODEX_RB__")
	return escaped.replace("__CODEX_LB__", "[lb]").replace("__CODEX_RB__", "[rb]")
