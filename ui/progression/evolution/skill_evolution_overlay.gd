class_name SkillEvolutionOverlay
extends Control

signal selection_changed(request_id: StringName, upgrade_id: StringName)
signal confirmation_requested(request_id: StringName, upgrade_id: StringName)
signal confirmation_finished(request_id: StringName, upgrade_id: StringName)

const REVEAL_SFX := preload(
	"res://asset/bruitage sort/MUSCPerc_Triangle 3 (ID 1689)_LaSonotheque.fr.mp3"
)

@export var reduced_motion := false

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var card_zone: CenterContainer = %CardZone
@onready var card_row: HBoxContainer = %CardRow
@onready var card_left: SkillEvolutionCard = %SkillEvolutionCardA
@onready var card_right: SkillEvolutionCard = %SkillEvolutionCardB
@onready var choice_details: Label = %ChoiceDetails
@onready var confirm_button: Button = %ConfirmButton
@onready var input_hints: Label = %InputHints
@onready var error_label: Label = %ErrorLabel

var _request: EvolutionRequest = null
var _choice: Dictionary = {}
var _upgrades: Array[SkillUpgradeData] = []
var _selected_upgrade_id: StringName = &""
var _locked := false
var _presented := false
var _cards: Array[SkillEvolutionCard] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PremiumUI.apply(self)
	_cards = [card_left, card_right]
	for card in _cards:
		card.choice_requested.connect(_on_card_choice_requested)
		card.hover_changed.connect(_on_card_hover_changed)
	confirm_button.pressed.connect(request_confirmation)
	resized.connect(_apply_responsive_layout)
	set_process_input(true)
	hide()


func present(
		request: EvolutionRequest,
		choice: Dictionary,
		use_reduced_motion: bool = false
	) -> bool:
	reset()
	reduced_motion = use_reduced_motion
	if not _is_valid_request_choice(request, choice):
		error_label.text = "Deux évolutions valides sont requises."
		error_label.show()
		show()
		return false
	_request = request
	_choice = choice.duplicate(true)
	for value in _choice.get("choices", []):
		_upgrades.append(value as SkillUpgradeData)
	title_label.text = "CHOISISSEZ UNE ÉVOLUTION"
	subtitle_label.text = "%s · %s · Niveau %d" % [
		str(_choice.get("character_name", request.character_id)),
		str(_choice.get("discipline_name", request.discipline_id)),
		request.pending_rank,
	]
	show()
	move_to_front()
	_presented = true
	for index in _cards.size():
		_cards[index].configure(_upgrades[index], index, reduced_motion)
		_cards[index].set_locked(false)
	_update_detail(0)
	_apply_responsive_layout()
	call_deferred("_configure_focus")
	for index in _cards.size():
		_cards[index].play_entrance(0.0 if reduced_motion else float(index) * 0.09)
	AudioManager.play_sfx(REVEAL_SFX, -11.0)
	return true


func reset() -> void:
	_request = null
	_choice.clear()
	_upgrades.clear()
	_selected_upgrade_id = &""
	_locked = false
	_presented = false
	confirm_button.disabled = true
	confirm_button.text = "CONFIRMER L’ÉVOLUTION"
	error_label.hide()
	for card in _cards:
		card.set_selected(false)
		card.set_peer_dimmed(false)
		card.set_locked(false)
		card.reset_visual_state()


func close_overlay() -> void:
	reset()
	hide()


func select_upgrade_by_id(
		upgrade_id: StringName,
		focus_card: bool = false
	) -> bool:
	if _locked or not _presented:
		return false
	var selected_index := _index_for_upgrade(upgrade_id)
	if selected_index < 0:
		return false
	_selected_upgrade_id = upgrade_id
	for index in _cards.size():
		_cards[index].set_selected(index == selected_index)
		_cards[index].set_peer_dimmed(index != selected_index)
	confirm_button.disabled = false
	_update_detail(selected_index)
	if focus_card:
		_cards[selected_index].grab_card_focus()
	selection_changed.emit(_request.request_id, upgrade_id)
	AudioManager.play_sfx(REVEAL_SFX, -16.0)
	return true


func request_confirmation() -> bool:
	if _locked or _selected_upgrade_id == &"" or _request == null:
		return false
	_locked = true
	confirm_button.disabled = true
	confirm_button.text = "APPLICATION EN COURS…"
	for card in _cards:
		card.set_locked(true)
	confirmation_requested.emit(_request.request_id, _selected_upgrade_id)
	return true


func resolve_confirmation(success: bool, error_message: String = "") -> void:
	if success:
		error_label.hide()
		confirm_button.text = "ÉVOLUTION ACQUISE"
		for card in _cards:
			card.play_confirmation(card.upgrade_id == _selected_upgrade_id)
		AudioManager.play_sfx(REVEAL_SFX, -7.0)
		_finish_confirmation_after_delay()
		return
	_locked = false
	confirm_button.disabled = _selected_upgrade_id == &""
	confirm_button.text = "RÉESSAYER"
	error_label.text = error_message if not error_message.is_empty() else "Évolution impossible."
	error_label.show()
	for card in _cards:
		card.set_locked(false)


func get_selected_upgrade_id() -> StringName:
	return _selected_upgrade_id


func get_request_id() -> StringName:
	return _request.request_id if _request != null else &""


func get_available_upgrade_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for upgrade in _upgrades:
		if upgrade != null:
			result.append(upgrade.upgrade_id)
	return result


func get_card(index: int) -> SkillEvolutionCard:
	return _cards[index] if index >= 0 and index < _cards.size() else null


func get_card_count() -> int:
	return 2 if _presented else 0


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
		"card_layouts": [card_left.get_layout_snapshot(), card_right.get_layout_snapshot()],
		"selected_upgrade_id": _selected_upgrade_id,
		"confirm_disabled": confirm_button.disabled,
		"reduced_motion": reduced_motion,
	}


func _input(event: InputEvent) -> void:
	if not visible or not _presented or _locked:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		select_upgrade_by_id(_upgrades[0].upgrade_id, true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		select_upgrade_by_id(_upgrades[1].upgrade_id, true)
		get_viewport().set_input_as_handled()


func _on_card_choice_requested(upgrade_id: StringName) -> void:
	select_upgrade_by_id(upgrade_id)


func _on_card_hover_changed(card_index: int, hovered: bool) -> void:
	if _locked:
		return
	if _selected_upgrade_id == &"":
		for index in _cards.size():
			_cards[index].set_peer_dimmed(hovered and index != card_index)
		_update_detail(card_index if hovered else 0)


func _update_detail(index: int) -> void:
	if index < 0 or index >= _upgrades.size() or _upgrades[index] == null:
		choice_details.text = ""
		return
	var upgrade := _upgrades[index]
	choice_details.text = "%s — %s" % [upgrade.display_name, upgrade.description]


func _apply_responsive_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	var presentation_scale := clampf(
		minf(size.x / 1920.0, size.y / 1080.0),
		1.0,
		1.14
	)
	var card_height := clampf(
		size.y * 0.57,
		338.0,
		620.0 * presentation_scale
	)
	var vertical_allowance := maxf(300.0, size.y - 304.0 * presentation_scale)
	card_height = minf(card_height, vertical_allowance)
	var compact_cards := card_height <= 500.0 or size.x <= 1320.0
	var gap := clampf(size.x * 0.045, 42.0, 82.0 * presentation_scale)
	var maximum_width := maxf(210.0, (size.x - gap - 96.0) * 0.5)
	card_row.add_theme_constant_override("separation", int(gap))
	for card in _cards:
		card.set_compact_mode(compact_cards)
		card.set_presentation_scale(presentation_scale)
		card.set_card_height(card_height, maximum_width)
	card_zone.offset_top = (
		118.0 if size.y <= 760.0 else 130.0 * presentation_scale
	)
	card_zone.offset_bottom = (
		-166.0 if size.y <= 760.0 else -174.0 * presentation_scale
	)
	title_label.add_theme_font_size_override(
		"font_size",
		24 if size.y <= 760.0 else roundi(30.0 * presentation_scale)
	)
	subtitle_label.add_theme_font_size_override(
		"font_size",
		12 if size.y <= 760.0 else roundi(14.0 * presentation_scale)
	)
	choice_details.add_theme_font_size_override(
		"font_size",
		11 if size.y <= 760.0 else roundi(13.0 * presentation_scale)
	)
	confirm_button.add_theme_font_size_override(
		"font_size",
		13 if compact_cards else roundi(15.0 * presentation_scale)
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
	confirm_button.focus_neighbor_left = card_left.interaction.get_path()
	confirm_button.focus_neighbor_right = card_right.interaction.get_path()
	card_left.interaction.focus_neighbor_bottom = confirm_button.get_path()
	card_right.interaction.focus_neighbor_bottom = confirm_button.get_path()
	card_left.grab_card_focus()


func _is_valid_request_choice(
		request: EvolutionRequest,
		choice: Dictionary
	) -> bool:
	if request == null or not request.is_valid() or choice.is_empty():
		return false
	if StringName(choice.get("character_id", &"")) != request.character_id \
			or StringName(choice.get("discipline_id", &"")) != request.discipline_id \
			or int(choice.get("rank", 0)) != request.pending_rank:
		return false
	var values := choice.get("choices", []) as Array
	if values.size() != 2:
		return false
	var first := values[0] as SkillUpgradeData
	var second := values[1] as SkillUpgradeData
	return first != null and second != null \
		and first.upgrade_id != &"" and second.upgrade_id != &"" \
		and first.upgrade_id != second.upgrade_id


func _index_for_upgrade(upgrade_id: StringName) -> int:
	for index in _upgrades.size():
		if _upgrades[index] != null and _upgrades[index].upgrade_id == upgrade_id:
			return index
	return -1


func _finish_confirmation_after_delay() -> void:
	var request_id := get_request_id()
	var upgrade_id := _selected_upgrade_id
	var delay := 0.22 if reduced_motion else 0.62
	await get_tree().create_timer(delay, true, false, true).timeout
	confirmation_finished.emit(request_id, upgrade_id)
