@tool
extends Control

@export var target_paths: Array[NodePath] = []
@export var debug_enabled := false:
	set(value):
		debug_enabled = value
		set_process(value)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(debug_enabled)


func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled


func _process(_delta: float) -> void:
	if debug_enabled:
		queue_redraw()


func _draw() -> void:
	if not debug_enabled:
		return
	for index in range(target_paths.size()):
		var target_path := target_paths[index]
		var target := get_node_or_null(target_path) as Control
		if target == null:
			continue
		var target_rect := target.get_global_rect()
		target_rect.position = target_rect.position - global_position
		if index >= 4:
			target_rect = target_rect.grow(-4.0)
		var color := Color.from_hsv(
			fmod(0.52 + float(index) * 0.137, 1.0),
			0.72,
			1.0,
			0.94
		)
		draw_rect(target_rect, color, false, 2.0)
		_draw_target_label(target_rect, target.name, color, index)


func _draw_target_label(
		rect: Rect2,
		label_text: String,
		color: Color,
		index: int
	) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 12
	var text_size := font.get_string_size(
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	)
	var label_rect := Rect2(
		rect.position + Vector2(2.0, 2.0 + float(index) * 16.0),
		text_size + Vector2(8.0, 4.0)
	)
	draw_rect(label_rect, Color(0.015, 0.02, 0.03, 0.88), true)
	draw_string(
		font,
		label_rect.position + Vector2(4.0, font_size + 1.0),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)
