class_name TurnOrderTimeline
extends CanvasLayer

const CARD_SCENE := preload("res://ui/combat/turn_order_card.tscn")
const CARD_GAP_RATIO := 0.0054
const WIDTH_RATIOS := [0.08, 0.065, 0.06, 0.057]
const HEIGHT_RATIOS := [0.06, 0.05, 0.044, 0.039]

signal unit_selected(unit: Unit)

@export_range(0.05, 1.0, 0.05) var scroll_duration := 0.32

@onready var cards_layer: Control = %CardsLayer

var _queue: TurnQueue = null
var _cards: Dictionary = {}
var _display_order: Array = []
var _layout_tween: Tween = null
var _tactical_focus := false


func _ready() -> void:
	visible = false
	_update_timeline_geometry()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


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


func _on_turn_started(_unit: Unit) -> void:
	_sync_cards(not _display_order.is_empty())


func _on_queue_changed() -> void:
	_sync_cards(not _display_order.is_empty())


func _sync_cards(animate: bool) -> void:
	if _queue == null or not is_instance_valid(cards_layer):
		return
	var next_order := _queue.get_upcoming_order()
	var should_animate := animate and next_order != _display_order
	_remove_obsolete_cards(next_order)
	for unit_variant in next_order:
		var unit := unit_variant as Unit
		if unit == null or _cards.has(unit):
			continue
		var card = CARD_SCENE.instantiate()
		cards_layer.add_child(card)
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
			_layout_tween.tween_property(
				card,
				"position",
				target["position"],
				scroll_duration,
			)
			_layout_tween.tween_property(
				card,
				"size",
				target["size"],
				scroll_duration,
			)
			_layout_tween.tween_property(
				card,
				"custom_minimum_size",
				target["size"],
				scroll_duration,
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
	var card_gap := get_viewport().get_visible_rect().size.y * CARD_GAP_RATIO
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
	cards_layer.offset_left = viewport_size.x * 0.004
	cards_layer.offset_top = viewport_size.y * 0.055
	cards_layer.offset_right = viewport_size.x * 0.084
	cards_layer.offset_bottom = -viewport_size.y * 0.12
