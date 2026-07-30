class_name DarkMenuButton
extends Button

@export var minimum_button_size := Vector2(450.0, 58.0):
	set(value):
		minimum_button_size = value
		custom_minimum_size = value

var _emphasis_tween: Tween = null
var _hover_style: StyleBox = null


func _ready() -> void:
	custom_minimum_size = minimum_button_size
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hover_style = get_theme_stylebox(&"hover")
	mouse_entered.connect(_sync_emphasis)
	mouse_exited.connect(_sync_emphasis)
	focus_entered.connect(_sync_emphasis)
	focus_exited.connect(_sync_emphasis)
	resized.connect(_update_pivot)
	_update_pivot()


func configure(label_text: String, available: bool = true) -> void:
	text = label_text
	disabled = not available
	tooltip_text = (
		""
		if available
		else "Cette section n'est pas encore disponible."
	)
	_sync_emphasis()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _sync_emphasis() -> void:
	var emphasized := not disabled and (is_hovered() or has_focus())
	if emphasized and _hover_style != null:
		add_theme_stylebox_override(&"normal", _hover_style)
	elif has_theme_stylebox_override(&"normal"):
		remove_theme_stylebox_override(&"normal")
	if _emphasis_tween != null and _emphasis_tween.is_valid():
		_emphasis_tween.kill()
	_emphasis_tween = create_tween()
	_emphasis_tween.set_trans(Tween.TRANS_QUAD)
	_emphasis_tween.set_ease(Tween.EASE_OUT)
	_emphasis_tween.tween_property(
		self,
		"scale",
		Vector2.ONE * (1.012 if emphasized else 1.0),
		0.08
	)
