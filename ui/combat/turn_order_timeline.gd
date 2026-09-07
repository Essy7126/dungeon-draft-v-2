class_name TurnOrderTimeline
extends CanvasLayer

const CARD_SCENE := preload("res://ui/combat/turn_order_card.tscn")
const VISUAL_THEME_FACTORY := preload(
	"res://ui/recraft_hud_v1/theme/hud_visual_theme_factory.gd"
)
const DEFAULT_VISUAL_SKIN: HudVisualSkinData = preload(
	"res://data/ui/hud_visual_skin_neutral_v1.tres"
)
const CARD_GAP_RATIO := 0.0054
const WIDTH_RATIOS := [0.08, 0.065, 0.06, 0.057]
const HEIGHT_RATIOS := [0.06, 0.05, 0.044, 0.039]
const PREMIUM_REFERENCE_SIZE := Vector2(1672.0, 941.0)
const TURN_TITLE_MAX_FONT_SIZE := 18
const TURN_TITLE_MIN_FONT_SIZE := 13
const TURN_TITLE_SHADOW_PADDING := 2.0
const PREMIUM_CARD_SIZES := [
	Vector2(76.0, 64.0),
	Vector2(70.0, 58.0),
	Vector2(66.0, 54.0),
	Vector2(62.0, 50.0),
]

signal unit_selected(unit: Unit)

@export_range(0.05, 1.0, 0.05) var scroll_duration := 0.32
@export var visual_skin: HudVisualSkinData = DEFAULT_VISUAL_SKIN

@onready var cards_layer: Control = %CardsLayer
@onready var turn_header: Control = %TurnHeader
@onready var turn_header_title: Label = %Title

var _queue: TurnQueue = null
var _cards: Dictionary = {}
var _display_order: Array = []
var _layout_tween: Tween = null
var _tactical_focus := false
var _reduced_motion := false


func _ready() -> void:
	visible = false
	turn_header_title.resized.connect(_fit_turn_header_title)
	_apply_skin_to_chrome()
	_update_timeline_geometry()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func apply_visual_skin(skin: HudVisualSkinData) -> void:
	visual_skin = skin
	if not is_node_ready():
		return
	_apply_skin_to_chrome()
	for card_variant in _cards.values():
		var card := card_variant as TurnOrderCard
		if is_instance_valid(card):
			card.apply_visual_skin(visual_skin)
	_update_timeline_geometry()
	_apply_layout(false)
	_refresh_turn_header(_queue.get_current_unit() if _queue != null else null)


func bind_queue(queue: TurnQueue) -> void:
	_unbind_queue()
	_queue = queue
	if _queue == null:
		visible = false
		return
	_queue.turn_started.connect(_on_turn_started)
	_queue.queue_changed.connect(_on_queue_changed)
	visible = true
	_sync_cards(false)
	_refresh_turn_header(_queue.get_current_unit())


func clear_queue() -> void:
	_unbind_queue()
	if _layout_tween != null and _layout_tween.is_valid():
		_layout_tween.kill()
	_layout_tween = null
	for card_variant in _cards.values():
		var card = card_variant
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()
	_display_order.clear()
	_refresh_turn_header(null)
	visible = false


func get_display_order() -> Array:
	return _display_order.duplicate()


func get_card_count() -> int:
	return _cards.size()


func is_animating() -> bool:
	return _layout_tween != null and _layout_tween.is_valid()


func finish_animation_for_test() -> void:
	if is_animating():
		_layout_tween.custom_step(scroll_duration + 0.1)


func set_tactical_focus(active: bool) -> void:
	_tactical_focus = active
	if is_instance_valid(cards_layer):
		cards_layer.modulate.a = 0.28 if active else 1.0


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled and _layout_tween != null and _layout_tween.is_valid():
		_layout_tween.kill()
		_layout_tween = null
		_apply_layout(false)


func is_reduced_motion_enabled() -> bool:
	return _reduced_motion


func is_tactical_focus_active() -> bool:
	return _tactical_focus


func _unbind_queue() -> void:
	if _queue == null:
		return
	if _queue.turn_started.is_connected(_on_turn_started):
		_queue.turn_started.disconnect(_on_turn_started)
	if _queue.queue_changed.is_connected(_on_queue_changed):
		_queue.queue_changed.disconnect(_on_queue_changed)
	_queue = null


func _on_turn_started(unit: Unit) -> void:
	_sync_cards(not _display_order.is_empty())
	_refresh_turn_header(unit)


func _on_queue_changed() -> void:
	_sync_cards(not _display_order.is_empty())
	_refresh_turn_header(_queue.get_current_unit() if _queue != null else null)


func _sync_cards(animate: bool) -> void:
	if _queue == null or not is_instance_valid(cards_layer):
		return
	var next_order := _queue.get_upcoming_order()
	var should_animate := animate and not _reduced_motion and next_order != _display_order
	_remove_obsolete_cards(next_order)
	for unit_variant in next_order:
		var unit := unit_variant as Unit
		if unit == null or _cards.has(unit):
			continue
		var card = CARD_SCENE.instantiate()
		cards_layer.add_child(card)
		card.apply_visual_skin(visual_skin)
		card.configure(unit)
		card.unit_requested.connect(_on_card_unit_requested)
		_cards[unit] = card
	_display_order = next_order.duplicate()
	_apply_layout(should_animate)


func _remove_obsolete_cards(next_order: Array) -> void:
	for unit_variant in _cards.keys():
		var unit := unit_variant as Unit
		if next_order.has(unit):
			continue
		var card = _cards.get(unit)
		_cards.erase(unit)
		if is_instance_valid(card):
			card.queue_free()


func _apply_layout(animate: bool) -> void:
	if _layout_tween != null and _layout_tween.is_valid():
		_layout_tween.kill()
	_layout_tween = null
	var targets := _build_layout_targets(_display_order.size())
	if animate:
		_layout_tween = create_tween().set_parallel(true)
		_layout_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for rank in range(_display_order.size()):
		var unit := _display_order[rank] as Unit
		var card = _cards.get(unit)
		if not is_instance_valid(card):
			continue
		var target := targets[rank] as Dictionary
		card.set_visual_rank(rank)
		card.z_index = _display_order.size() - rank
		if animate:
			var duration := (
				visual_skin.motion_duration(&"panel", _reduced_motion)
				if visual_skin != null
				else scroll_duration
			)
			_layout_tween.tween_property(
				card,
				"position",
				target["position"],
				duration,
			)
			_layout_tween.tween_property(
				card,
				"size",
				target["size"],
				duration,
			)
			_layout_tween.tween_property(
				card,
				"custom_minimum_size",
				target["size"],
				duration,
			)
		else:
			card.position = target["position"]
			card.custom_minimum_size = target["size"]
			card.size = target["size"]


func _build_layout_targets(count: int) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if count <= 0:
		return targets
	var unscaled_total := 0.0
	var card_gap := (
		6.0 * _premium_scale()
		if _premium_skin_active()
		else get_viewport().get_visible_rect().size.y * CARD_GAP_RATIO
	)
	for rank in range(count):
		unscaled_total += _base_size_for_rank(rank).y
	unscaled_total += card_gap * maxi(0, count - 1)
	var viewport_height := get_viewport().get_visible_rect().size.y
	var viewport_available := maxf(1.0, viewport_height - 230.0)
	var available_height := maxf(360.0, maxf(cards_layer.size.y, viewport_available))
	var scale_factor := minf(1.0, available_height / unscaled_total)
	var y := 0.0
	for rank in range(count):
		var card_size := _base_size_for_rank(rank) * scale_factor
		targets.append({
			"position": Vector2(0.0, y),
			"size": card_size,
		})
		y += card_size.y + card_gap * scale_factor
	return targets


func _base_size_for_rank(rank: int) -> Vector2:
	if _premium_skin_active():
		var premium_index := mini(rank, PREMIUM_CARD_SIZES.size() - 1)
		var card_size: Vector2 = PREMIUM_CARD_SIZES[premium_index] * _premium_scale()
		if rank >= PREMIUM_CARD_SIZES.size():
			var extra_rank := float(rank - PREMIUM_CARD_SIZES.size() + 1)
			card_size.x = maxf(48.0 * _premium_scale(), card_size.x - 2.0 * extra_rank)
			card_size.y = maxf(42.0 * _premium_scale(), card_size.y - 2.0 * extra_rank)
		return card_size
	var viewport_size := get_viewport().get_visible_rect().size
	var metric_index := mini(rank, WIDTH_RATIOS.size() - 1)
	var width: float = viewport_size.x * float(WIDTH_RATIOS[metric_index])
	var height: float = viewport_size.y * float(HEIGHT_RATIOS[metric_index])
	if rank >= WIDTH_RATIOS.size():
		var extra_rank := float(rank - WIDTH_RATIOS.size() + 1)
		width = maxf(viewport_size.x * 0.05, width - viewport_size.x * 0.002 * extra_rank)
		height = maxf(viewport_size.y * 0.034, height - viewport_size.y * 0.001 * extra_rank)
	return Vector2(width, height)


func _on_card_unit_requested(unit: Unit) -> void:
	unit_selected.emit(unit)


func _on_viewport_size_changed() -> void:
	_update_timeline_geometry()
	_apply_layout(false)


func _update_timeline_geometry() -> void:
	if not is_instance_valid(cards_layer):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if _premium_skin_active():
		var scale := _premium_scale()
		cards_layer.offset_left = 20.0 * scale
		cards_layer.offset_top = 20.0 * scale
		cards_layer.offset_right = cards_layer.offset_left + 84.0 * scale
		cards_layer.offset_bottom = -120.0 * scale
		var header_width := 360.0 * scale
		var header_top := 10.0 * scale
		turn_header.offset_left = -header_width * 0.5
		turn_header.offset_top = header_top
		turn_header.offset_right = header_width * 0.5
		turn_header.offset_bottom = header_top + 64.0 * scale
		return
	cards_layer.offset_left = viewport_size.x * 0.004
	cards_layer.offset_top = viewport_size.y * 0.055
	cards_layer.offset_right = viewport_size.x * 0.084
	cards_layer.offset_bottom = -viewport_size.y * 0.12


func _apply_skin_to_chrome() -> void:
	if visual_skin != null:
		cards_layer.theme = VISUAL_THEME_FACTORY.build(visual_skin)
		turn_header_title.add_theme_font_override("font", visual_skin.font_emphasis)
		turn_header_title.add_theme_color_override("font_color", visual_skin.text_primary)
	turn_header.visible = _premium_skin_active() and _queue != null
	_fit_turn_header_title()


func _refresh_turn_header(unit: Unit) -> void:
	if not is_instance_valid(turn_header):
		return
	turn_header.visible = _premium_skin_active() and _queue != null
	if unit == null:
		turn_header_title.text = "ORDRE DU TOUR"
		_fit_turn_header_title()
		return
	turn_header_title.text = _turn_title(unit.unit_name)
	_fit_turn_header_title()


func _fit_turn_header_title() -> void:
	if not is_instance_valid(turn_header_title):
		return
	var font := turn_header_title.get_theme_font("font")
	if font == null:
		return
	var available_width := maxf(turn_header_title.size.x - TURN_TITLE_SHADOW_PADDING, 1.0)
	var available_height := maxf(turn_header_title.size.y - TURN_TITLE_SHADOW_PADDING, 1.0)
	var font_size := TURN_TITLE_MAX_FONT_SIZE
	while font_size > TURN_TITLE_MIN_FONT_SIZE:
		var text_size := font.get_string_size(
			turn_header_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
		)
		if text_size.x <= available_width and text_size.y <= available_height:
			break
		font_size -= 1
	if turn_header_title.get_theme_font_size("font_size") != font_size:
		turn_header_title.add_theme_font_size_override("font_size", font_size)
	# Keep a readable lower bound for unusually long names; the complete title
	# remains available through its tooltip if even the minimum does not fit.
	var fitted_width := font.get_string_size(
		turn_header_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	).x
	turn_header_title.tooltip_text = turn_header_title.text \
		if fitted_width > available_width else ""
	turn_header_title.mouse_filter = Control.MOUSE_FILTER_PASS \
		if fitted_width > available_width else Control.MOUSE_FILTER_IGNORE


func _turn_title(unit_name: String) -> String:
	var display_name := unit_name.strip_edges().to_upper()
	if display_name.is_empty():
		return "TOUR EN COURS"
	var first_letter := display_name.substr(0, 1)
	if first_letter in ["A", "À", "Â", "Ä", "E", "É", "È", "Ê", "Ë", "I", "Î", "Ï", "O", "Ô", "Ö", "U", "Ù", "Û", "Ü", "Y", "H"]:
		return "TOUR D’%s" % display_name
	return "TOUR DE %s" % display_name


func _premium_skin_active() -> bool:
	return visual_skin != null and not visual_skin.neutral_grayscale


func _premium_scale() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return clampf(
		minf(
			viewport_size.x / PREMIUM_REFERENCE_SIZE.x,
			viewport_size.y / PREMIUM_REFERENCE_SIZE.y,
		),
		0.72,
		1.1,
	)
