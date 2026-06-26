class_name KeywordTooltipLayer
extends CanvasLayer

const Glossary = preload("res://ui/combat_glossary.gd")

var _panel: PanelContainer
var _label: RichTextLabel
var _pinned: bool = false
var _hide_queued: bool = false

func _ready() -> void:
	layer = 120
	add_to_group("keyword_tooltip_layer")
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.custom_minimum_size = Vector2(300, 0)
	_label.add_theme_font_size_override("normal_font_size", 13)
	_label.meta_hover_started.connect(_on_meta_hover_started)
	_label.meta_clicked.connect(_on_meta_clicked)
	margin.add_child(_label)

func show_keyword(id: String, global_pos: Vector2, pin: bool = false) -> void:
	show_bbcode(Glossary.definition_bbcode(id), global_pos, pin)

func show_spell(caster, spell: Spell, imprinted: bool, unusable_reason: String, global_pos: Vector2) -> void:
	show_bbcode(Glossary.spell_card_bbcode(caster, spell, imprinted, unusable_reason), global_pos, false)

func show_text(title: String, body: String, global_pos: Vector2, pin: bool = false) -> void:
	var bbcode := "[b]%s[/b]\n%s" % [_escape_bbcode(title), Glossary.render_keywords(body)]
	show_bbcode(bbcode, global_pos, pin)

func show_bbcode(bbcode: String, global_pos: Vector2, pin: bool = false) -> void:
	_pinned = pin
	_hide_queued = false
	_panel.visible = false
	_label.text = bbcode
	_panel.visible = true
	await get_tree().process_frame
	_panel.size = _panel.get_combined_minimum_size()
	_place(global_pos)

func request_hide() -> void:
	if _pinned:
		return
	_hide_queued = true
	await get_tree().create_timer(0.08).timeout
	if _hide_queued and not _pinned:
		_panel.visible = false

func hide_all() -> void:
	_pinned = false
	_hide_queued = false
	_panel.visible = false

func _place(global_pos: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var desired := global_pos + Vector2(18, 18)
	var size := _panel.get_combined_minimum_size()
	if size.x <= 1.0 or size.y <= 1.0:
		size = Vector2(300, 80)
	if desired.x + size.x > viewport_size.x - 8.0:
		desired.x = global_pos.x - size.x - 18.0
	if desired.y + size.y > viewport_size.y - 8.0:
		desired.y = viewport_size.y - size.y - 8.0
	desired.x = clampf(desired.x, 8.0, maxf(8.0, viewport_size.x - size.x - 8.0))
	desired.y = clampf(desired.y, 8.0, maxf(8.0, viewport_size.y - size.y - 8.0))
	_panel.position = desired

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and _panel.visible:
			_pinned = not _pinned
		elif event.button_index == MOUSE_BUTTON_LEFT and _pinned:
			if not _panel.get_global_rect().has_point(event.position):
				hide_all()

func _on_meta_hover_started(meta) -> void:
	var value := str(meta)
	if value.begins_with("kw:"):
		show_keyword(value.trim_prefix("kw:"), get_viewport().get_mouse_position(), false)

func _on_meta_clicked(meta) -> void:
	var value := str(meta)
	if value.begins_with("kw:"):
		show_keyword(value.trim_prefix("kw:"), get_viewport().get_mouse_position(), true)

func _escape_bbcode(text: String) -> String:
	var escaped := text.replace("[", "__CODEX_LB__").replace("]", "__CODEX_RB__")
	return escaped.replace("__CODEX_LB__", "[lb]").replace("__CODEX_RB__", "[rb]")
