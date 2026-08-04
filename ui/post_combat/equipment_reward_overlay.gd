class_name EquipmentRewardOverlay
extends Control

signal selection_changed(item_id: StringName)
signal confirmation_requested(item_id: StringName)
signal confirmation_finished

const REVEAL_SFX := preload(
	"res://asset/bruitage sort/MUSCPerc_Triangle 3 (ID 1689)_LaSonotheque.fr.mp3"
)
const CARD_ASPECT := 0.535

@export var reduced_motion := false

@onready var title_label: Label = %TitleLabel
@onready var card_zone: CenterContainer = %CardZone
@onready var card_row: HBoxContainer = %CardRow
@onready var card_left: RewardCardChoice = %RewardCardChoiceA
@onready var card_right: RewardCardChoice = %RewardCardChoiceB
@onready var confirm_button: Button = %ConfirmButton
@onready var input_hints: Label = %InputHints
@onready var error_label: Label = %ErrorLabel

var _options: Array[Dictionary] = []
var _selected_item_id: StringName = &""
var _locked := false
var _presented := false
var _cards: Array[RewardCardChoice] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cards = [card_left, card_right]
	for card in _cards:
		card.choice_requested.connect(_on_card_choice_requested)
		card.hover_changed.connect(_on_card_hover_changed)
	confirm_button.pressed.connect(request_confirmation)
	resized.connect(_apply_responsive_layout)
	visible = false
	set_process_input(true)


func present(options: Array[Dictionary], use_reduced_motion: bool = false) -> bool:
	reset()
	reduced_motion = use_reduced_motion
	if options.size() != 2:
		error_label.text = "Deux équipements valides sont requis."
		error_label.show()
		visible = true
		return false
	var first_id := StringName(options[0].get("item_id", &""))
	var second_id := StringName(options[1].get("item_id", &""))
	if first_id == &"" or second_id == &"" or first_id == second_id:
		error_label.text = "L’offre de récompense est invalide."
		error_label.show()
		visible = true
		return false
	_options = options.duplicate(true)
	visible = true
	_presented = true
	for index in _cards.size():
		_cards[index].configure(_options[index], index, reduced_motion)
		_cards[index].set_locked(false)
	_apply_responsive_layout()
	call_deferred("_configure_focus")
	for index in _cards.size():
		_cards[index].play_entrance(0.0 if reduced_motion else float(index) * 0.09)
	AudioManager.play_sfx(REVEAL_SFX, -11.0)
	return true


func reset() -> void:
	_options.clear()
	_selected_item_id = &""
	_locked = false
	_presented = false
	confirm_button.disabled = true
	confirm_button.text = "CONFIRMER"
	error_label.hide()
	for card in _cards:
		card.set_selected(false)
		card.set_peer_dimmed(false)
		card.set_locked(false)
		card.modulate.a = 1.0


func select_item_by_id(item_id: StringName, focus_card: bool = false) -> bool:
	if _locked or not _presented:
		return false
	var selected_index := -1
	for index in _options.size():
		if StringName(_options[index].get("item_id", &"")) == item_id:
			selected_index = index
			break
	if selected_index < 0:
		return false
	_selected_item_id = item_id
	for index in _cards.size():
		_cards[index].set_selected(index == selected_index)
		_cards[index].set_peer_dimmed(index != selected_index)
	confirm_button.disabled = false
	if focus_card:
		_cards[selected_index].grab_card_focus()
	selection_changed.emit(item_id)
	AudioManager.play_sfx(REVEAL_SFX, -16.0)
	return true


func request_confirmation() -> bool:
	if _locked or _selected_item_id == &"":
		return false
	_locked = true
	confirm_button.disabled = true
	confirm_button.text = "ATTRIBUTION…"
	for card in _cards:
		card.set_locked(true)
	confirmation_requested.emit(_selected_item_id)
	return true


func resolve_confirmation(success: bool, error_message: String = "") -> void:
	if success:
		error_label.hide()
		confirm_button.text = "ÉQUIPEMENT OBTENU"
		for card in _cards:
			card.play_confirmation(card.item_id == _selected_item_id)
		AudioManager.play_sfx(REVEAL_SFX, -7.0)
		_finish_confirmation_after_delay()
		return
	_locked = false
	confirm_button.disabled = _selected_item_id == &""
	confirm_button.text = "RÉESSAYER"
	error_label.text = error_message if not error_message.is_empty() else "Attribution impossible."
	error_label.show()
	for card in _cards:
		card.set_locked(false)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if _presented:
		var current_options := _options.duplicate(true)
		present(current_options, value)


func get_selected_item_id() -> StringName:
	return _selected_item_id


func get_card_count() -> int:
	return 2 if _presented else 0


func get_card(card_index: int) -> RewardCardChoice:
	return _cards[card_index] if card_index >= 0 and card_index < _cards.size() else null


func focus_first_card() -> void:
	if _presented:
		card_left.grab_card_focus()


func apply_viewport_size_for_test(viewport_size: Vector2) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = viewport_size
	_apply_responsive_layout()


func get_visual_snapshot() -> Dictionary:
	return {
		"overlay_rect": get_global_rect(),
		"card_rects": [card_left.get_global_rect(), card_right.get_global_rect()],
		"card_sizes": [card_left.size, card_right.size],
		"card_scales": [card_left.visual_root.scale, card_right.visual_root.scale],
		"selected_item_id": _selected_item_id,
		"confirm_disabled": confirm_button.disabled,
		"legacy_panel_visible": false,
		"reduced_motion": reduced_motion,
	}


func _input(event: InputEvent) -> void:
	if not visible or not _presented or _locked:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		select_item_by_id(StringName(_options[0].get("item_id", &"")), true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		select_item_by_id(StringName(_options[1].get("item_id", &"")), true)
		get_viewport().set_input_as_handled()


func _on_card_choice_requested(item_id: StringName) -> void:
	select_item_by_id(item_id)


func _on_card_hover_changed(card_index: int, hovered: bool) -> void:
	if _locked or _selected_item_id != &"":
		return
	for index in _cards.size():
		_cards[index].set_peer_dimmed(hovered and index != card_index)


func _apply_responsive_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	var card_height := clampf(size.y * 0.655, 410.0, 735.0)
	var vertical_allowance := maxf(330.0, size.y - 224.0)
	card_height = minf(card_height, vertical_allowance)
	var gap := clampf(size.x * 0.055, 56.0, 110.0)
	var card_width := card_height * CARD_ASPECT
	var horizontal_allowance := maxf(220.0, (size.x - gap - 96.0) * 0.5)
	if card_width > horizontal_allowance:
		card_width = horizontal_allowance
		card_height = card_width / CARD_ASPECT
	card_row.add_theme_constant_override("separation", int(gap))
	for card in _cards:
		card.set_card_size(Vector2(card_width, card_height))
	card_zone.offset_top = 104.0 if size.y <= 760.0 else 118.0
	card_zone.offset_bottom = -104.0 if size.y <= 760.0 else -118.0
	title_label.add_theme_font_size_override(
		"font_size",
		26 if size.y <= 760.0 else 34,
	)


func _configure_focus() -> void:
	if not _presented:
		return
	card_left.set_focus_neighbors(
		card_right.interaction.get_path(),
		card_right.interaction.get_path(),
	)
	card_right.set_focus_neighbors(
		card_left.interaction.get_path(),
		card_left.interaction.get_path(),
	)
	confirm_button.focus_neighbor_top = card_left.interaction.get_path()
	card_left.interaction.focus_neighbor_bottom = confirm_button.get_path()
	card_right.interaction.focus_neighbor_bottom = confirm_button.get_path()
	card_left.grab_card_focus()


func _finish_confirmation_after_delay() -> void:
	var delay := 0.22 if reduced_motion else 0.62
	await get_tree().create_timer(delay, true, false, true).timeout
	confirmation_finished.emit()
