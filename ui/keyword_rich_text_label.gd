class_name KeywordRichTextLabel
extends RichTextLabel

const Glossary = preload("res://ui/combat_glossary.gd")

func _ready() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	meta_hover_started.connect(_on_meta_hover_started)
	meta_clicked.connect(_on_meta_clicked)
	mouse_exited.connect(_on_mouse_exited)

func set_keyword_text(source: String) -> void:
	text = Glossary.render_keywords(source)

func _tooltip_layer():
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group("keyword_tooltip_layer")

func _on_meta_hover_started(meta) -> void:
	var value := str(meta)
	if not value.begins_with("kw:"):
		return
	var layer = _tooltip_layer()
	if layer != null:
		layer.show_keyword(value.trim_prefix("kw:"), get_viewport().get_mouse_position())

func _on_meta_clicked(meta) -> void:
	var value := str(meta)
	if not value.begins_with("kw:"):
		return
	var layer = _tooltip_layer()
	if layer != null:
		layer.show_keyword(value.trim_prefix("kw:"), get_viewport().get_mouse_position(), true)

func _on_mouse_exited() -> void:
	var layer = _tooltip_layer()
	if layer != null:
		layer.request_hide()