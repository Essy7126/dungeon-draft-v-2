extends CanvasLayer

@onready var log_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/LogContainer
@onready var scroll: ScrollContainer = $Panel/VBoxContainer/ScrollContainer
@onready var panel: Panel = $Panel
@onready var entry_count_label: Label = $Panel/VBoxContainer/Footer/CountLabel

var _category_filters: Dictionary = {}
var _level_filter: int = 1
var _auto_scroll: bool = true

const MAX_VISIBLE_LABELS := 100

func _ready() -> void:
	print("DebugOverlay _ready appelé")
	print("Panel : ", panel)
	panel.visible = false
	_build_category_buttons()
	_build_level_filter()
	_refresh_log()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	DebugLogger.log_added.connect(_on_log_added)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		print("Touche : ", event.keycode, " pressed : ", event.pressed)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			panel.visible = not panel.visible
			if panel.visible:
				_refresh_log()
func _build_category_buttons() -> void:
	var hbox: HBoxContainer = $Panel/VBoxContainer/CategoryFilters
	for cat in DebugLogger.LogCategory.values():
		_category_filters[cat] = true
		var btn := Button.new()
		btn.text = DebugLogger.CATEGORY_LABELS[cat].trim_prefix("[").trim_suffix("]")
		btn.toggle_mode = true
		btn.button_pressed = true
		var cat_copy: int = cat
		btn.toggled.connect(func(active: bool): _toggle_category(cat_copy, active))
		hbox.add_child(btn)

func _build_level_filter() -> void:
	var opt: OptionButton = $Panel/VBoxContainer/LevelFilter
	for lbl in ["TRACE", "DEBUG", "INFO", "WARN", "ERROR"]:
		opt.add_item(lbl)
	opt.selected = 1
	opt.item_selected.connect(func(idx: int):
		_level_filter = idx
		_refresh_log()
	)

func _toggle_category(cat: int, active: bool) -> void:
	_category_filters[cat] = active
	_refresh_log()

func _refresh_log() -> void:
	for child in log_container.get_children():
		child.queue_free()

	var active_cats: Array = _category_filters.keys().filter(func(c): return _category_filters[c])
	var filtered: Array = DebugLogger.get_filtered(_level_filter, active_cats)
	var to_show: Array = filtered.slice(max(0, filtered.size() - MAX_VISIBLE_LABELS))

	for entry in to_show:
		_add_label(entry)

	entry_count_label.text = "%d / %d entrees" % [to_show.size(), filtered.size()]

	if _auto_scroll:
		await get_tree().process_frame
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _add_label(entry: Dictionary) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size = Vector2(470, 0)          # ← largeur fixe : le texte a la place de s'afficher
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # ← remplit la largeur dispo

	var color: Color = DebugLogger.LEVEL_COLORS[entry.level]
	var hex: String = "#%s" % color.to_html(false)
	var prefix: String = "[T%02d][%s]%s " % [
		entry.turn,
		DebugLogger.LEVEL_LABELS[entry.level],
		DebugLogger.CATEGORY_LABELS[entry.category]
	]
	var ctx_str: String = ""
	if not entry.context.is_empty():
		ctx_str = " [color=#888888]| %s[/color]" % str(entry.context)

	lbl.text = "[color=%s]%s%s[/color]%s" % [hex, prefix, entry.message, ctx_str]
	log_container.add_child(lbl)

func _on_log_added(entry: Dictionary) -> void:
	if not panel.visible:
		return
	var cat_ok: bool = _category_filters.get(entry.category, true)
	var lvl_ok: bool = entry.level >= _level_filter
	if cat_ok and lvl_ok:
		_add_label(entry)
		entry_count_label.text = "..."
		if _auto_scroll:
			await get_tree().process_frame
			scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _on_clear_pressed() -> void:
	DebugLogger.clear()
	_refresh_log()
