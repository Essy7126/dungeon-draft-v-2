class_name PostCombatScreen
extends Control

const CHARACTER_PREVIEW_SCENE := preload(
	"res://ui/characters/CharacterPreview3D.tscn"
)
const PRESENTATION_IMPACT_SFX := preload(
	"res://asset/bruitage sort/MUSCPerc_Triangle 3 (ID 1689)_LaSonotheque.fr.mp3"
)

enum Phase {
	VICTORY_REVEAL,
	ROOM_DECISION,
	COMBAT_STATS,
	PROGRESSION,
	REWARD_SELECTION,
	COMPLETED,
	TRANSITIONING,
}

@export var victory_reveal_duration := 0.85
@export var stats_reveal_duration := 0.45
@export var progression_step_duration := 0.24
@export var threshold_pause_duration := 0.14
@export var transition_duration := 0.42

@onready var background: TextureRect = %Background
@onready var background_dim: ColorRect = %BackgroundDim
@onready var transition_layer: ColorRect = %TransitionLayer
@onready var safe_margin: MarginContainer = %SafeMargin
@onready var reward_overlay: EquipmentRewardOverlay = %EquipmentRewardOverlay
@onready var room_label: Label = %RoomLabel
@onready var phase_title: Label = %PhaseTitle
@onready var victory_panel: Control = %VictoryPanel
@onready var victory_title: Label = %VictoryTitle
@onready var decision_panel: Control = %DecisionPanel
@onready var decision_detail: Label = %DecisionDetail
@onready var decision_risk: Label = %DecisionRisk
@onready var stats_panel: Control = %CombatStatsPanel
@onready var stats_cards: HBoxContainer = %StatsCards
@onready var progression_panel: Control = %ProgressionPanel
@onready var progression_cards: HBoxContainer = %ProgressionCards
@onready var rewards_panel: Control = %RewardsPanel
@onready var reward_cards: HBoxContainer = %RewardCards
@onready var recipient_panel: VBoxContainer = %RecipientPanel
@onready var recipient_cards: HBoxContainer = %RecipientCards
@onready var comparison_label: Label = %ComparisonLabel
@onready var reward_error: Label = %RewardError
@onready var status_label: Label = %StatusLabel
@onready var push_wave_button: Button = %PushWaveButton
@onready var continue_button: Button = %ContinueButton

var phase: Phase = Phase.VICTORY_REVEAL
var report: CombatReport = null
var _reward_options: Array[Dictionary] = []
var _selected_reward_id: StringName = &""
var _selected_target_character_id: StringName = &""
var _reward_buttons: Dictionary = {}
var _recipient_buttons: Dictionary = {}
var _progress_rows: Array[Dictionary] = []
var _animation_active := false
var _sequence_generation := 0
var _current_tween: Tween = null
var _reward_applied := false
var _transition_requested := false
var _final_room := false
var _decision_snapshot: Dictionary = {}


func _ready() -> void:
	continue_button.pressed.connect(advance_or_skip)
	push_wave_button.pressed.connect(choose_continue_room)
	reward_overlay.selection_changed.connect(_on_overlay_selection_changed)
	reward_overlay.confirmation_requested.connect(_on_overlay_confirmation_requested)
	reward_overlay.confirmation_finished.connect(_on_overlay_confirmation_finished)
	report = GameManager.get_current_combat_report()
	if report == null or not report.finalized or not report.victory:
		_show_fatal_error("Le rapport de victoire est indisponible.")
		return
	_final_room = GameManager.is_final_room()
	_decision_snapshot = GameManager.get_post_combat_decision_snapshot()
	_configure_background()
	room_label.text = "%s · Vague %d/%d" % [
		report.room_name,
		int(_decision_snapshot.get("wave_number", 1)),
		maxi(1, int(_decision_snapshot.get("wave_count", 1))),
	]
	_build_stat_cards()
	_build_progression_cards()
	_build_reward_cards()
	_enter_phase(Phase.VICTORY_REVEAL)


func _unhandled_input(event: InputEvent) -> void:
	if phase in [
		Phase.ROOM_DECISION,
		Phase.REWARD_SELECTION,
		Phase.COMPLETED,
		Phase.TRANSITIONING,
	]:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance_or_skip()
	elif event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		advance_or_skip()


func advance_or_skip() -> void:
	if _animation_active:
		_finish_current_animation()
		return
	match phase:
		Phase.VICTORY_REVEAL:
			if bool(_decision_snapshot.get("can_continue", false)):
				_enter_phase(Phase.ROOM_DECISION)
			else:
				_enter_phase(Phase.COMBAT_STATS)
		Phase.ROOM_DECISION:
			choose_leave_room()
		Phase.COMBAT_STATS:
			_enter_phase(Phase.PROGRESSION)
		Phase.PROGRESSION:
			if _final_room:
				_begin_transition()
			else:
				_enter_phase(Phase.REWARD_SELECTION)
		Phase.REWARD_SELECTION:
			confirm_selected_reward()
		Phase.COMPLETED:
			_begin_transition()


func choose_continue_room() -> bool:
	if phase != Phase.ROOM_DECISION or _transition_requested:
		return false
	_transition_requested = true
	phase = Phase.TRANSITIONING
	phase_title.text = "NOUVELLE VAGUE"
	status_label.text = "La salle se renforce…"
	push_wave_button.disabled = true
	continue_button.disabled = true
	transition_layer.show()
	transition_layer.modulate.a = 0.0
	_current_tween = create_tween()
	_current_tween.tween_property(
		transition_layer,
		"modulate:a",
		1.0,
		transition_duration,
	)
	await _current_tween.finished
	if GameManager.continue_current_room_combat(report.report_id):
		return true
	_transition_requested = false
	transition_layer.hide()
	push_wave_button.disabled = false
	continue_button.disabled = false
	_enter_phase(Phase.ROOM_DECISION)
	status_label.text = "La nouvelle vague n'a pas pu être chargée."
	return false


func choose_leave_room() -> bool:
	if phase != Phase.ROOM_DECISION or _transition_requested:
		return false
	if not GameManager.select_current_room_exit(report.report_id):
		status_label.text = "Impossible de sécuriser la salle."
		return false
	_enter_phase(Phase.COMBAT_STATS)
	return true


func get_phase_name() -> StringName:
	return StringName(Phase.keys()[phase])


func get_stat_card_count() -> int:
	return stats_cards.get_child_count()


func get_progression_panel_count() -> int:
	return progression_cards.get_child_count()


func get_reward_card_count() -> int:
	return reward_overlay.get_card_count()


func select_reward_by_id(reward_id: StringName) -> bool:
	for option in _reward_options:
		if StringName(option.get("reward_id", &"")) != reward_id:
			continue
		return reward_overlay.select_item_by_id(reward_id)
	return false


func select_recipient_by_id(character_id: StringName) -> bool:
	if _selected_reward_id == &"":
		return false
	var option := _find_reward_option(_selected_reward_id)
	if option.is_empty():
		return false
	var compatible_ids := option.get("compatible_character_ids", []) as Array
	if not compatible_ids.has(character_id):
		return false
	_selected_target_character_id = character_id
	return true


func confirm_selected_reward() -> bool:
	if phase != Phase.REWARD_SELECTION or _reward_applied:
		return false
	if _selected_reward_id == &"":
		reward_overlay.resolve_confirmation(false, "Sélectionnez un équipement avant de confirmer.")
		return false
	if _selected_target_character_id == &"":
		var selected_option := _find_reward_option(_selected_reward_id)
		var compatible_ids := selected_option.get("compatible_character_ids", []) as Array
		if not compatible_ids.is_empty():
			_selected_target_character_id = StringName(compatible_ids[0])
	if _selected_target_character_id == &"":
		reward_overlay.resolve_confirmation(false, "Aucun héros ne peut utiliser cet équipement.")
		return false
	var result := GameManager.confirm_post_combat_equipment(
		_selected_reward_id,
		_selected_target_character_id,
	)
	if not result.get("success", false):
		reward_overlay.resolve_confirmation(
			false,
			str(result.get("error", "Application impossible.")),
		)
		return false
	_reward_applied = true
	phase = Phase.COMPLETED
	phase_title.text = "RÉCOMPENSE OBTENUE"
	status_label.text = "La récompense est enregistrée pour la run."
	continue_button.disabled = true
	reward_error.hide()
	reward_overlay.resolve_confirmation(true)
	return true


func get_progression_visual_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in _progress_rows:
		var bar := row.get("bar") as ProgressBar
		var rank_label := row.get("rank_label") as Label
		var node_label := row.get("node_label") as Label
		var delta := row.get("delta") as DisciplineProgressDelta
		result.append({
			"character_id": delta.character_id,
			"discipline_id": delta.discipline_id,
			"value": bar.value,
			"xp_after": delta.xp_after,
			"rank_text": rank_label.text,
			"node_text": node_label.text,
		})
	return result


func apply_viewport_size_for_test(viewport_size: Vector2) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = viewport_size
	reward_overlay.apply_viewport_size_for_test(viewport_size)


func _enter_phase(next_phase: Phase) -> void:
	_sequence_generation += 1
	phase = next_phase
	_animation_active = false
	_set_phase_visibility()
	reward_error.hide()
	match phase:
		Phase.VICTORY_REVEAL:
			_start_victory_reveal()
		Phase.ROOM_DECISION:
			_start_room_decision()
		Phase.COMBAT_STATS:
			_start_stats_reveal()
		Phase.PROGRESSION:
			_start_progression_reveal()
		Phase.REWARD_SELECTION:
			safe_margin.hide()
			background_dim.hide()
			if reward_overlay.present(_reward_options, reward_overlay.reduced_motion):
				var persisted_selection := GameManager.get_selected_post_combat_equipment()
				if persisted_selection != &"":
					reward_overlay.select_item_by_id(persisted_selection)


func _set_phase_visibility() -> void:
	safe_margin.visible = phase not in [
		Phase.REWARD_SELECTION,
		Phase.COMPLETED,
		Phase.TRANSITIONING,
	]
	reward_overlay.visible = phase in [Phase.REWARD_SELECTION, Phase.COMPLETED]
	victory_panel.visible = phase == Phase.VICTORY_REVEAL
	decision_panel.visible = phase == Phase.ROOM_DECISION
	stats_panel.visible = phase == Phase.COMBAT_STATS
	progression_panel.visible = phase == Phase.PROGRESSION
	rewards_panel.visible = false
	push_wave_button.visible = phase == Phase.ROOM_DECISION


func _start_room_decision() -> void:
	var current_wave := int(_decision_snapshot.get("wave_number", 1))
	var wave_count := maxi(1, int(_decision_snapshot.get("wave_count", 1)))
	var reward_multiplier := float(
		_decision_snapshot.get("reward_multiplier", 1.0)
	)
	phase_title.text = "DÉCISION DE SALLE"
	decision_detail.text = (
		"Vague %d/%d vaincue · Récompenses cumulées ×%.2f\n"
		+ "La vague %d sera plus dangereuse."
	) % [current_wave, wave_count, reward_multiplier, current_wave + 1]
	decision_risk.text = (
		"Continuer conserve vos blessures et retarde la progression, "
		+ "l'équipement et l'utilisation des objets."
	)
	status_label.text = "Quittez maintenant ou poussez votre chance."
	push_wave_button.text = "CONTINUER LE COMBAT"
	push_wave_button.disabled = false
	continue_button.text = (
		"TERMINER LA RUN" if _final_room else "PASSER À LA SALLE SUIVANTE"
	)
	continue_button.disabled = false
	push_wave_button.grab_focus()


func _start_victory_reveal() -> void:
	phase_title.text = "COMBAT ACHEVÉ"
	status_label.text = "Le champ de bataille est sécurisé."
	continue_button.text = "CONTINUER"
	continue_button.disabled = false
	victory_title.modulate.a = 0.0
	victory_title.scale = Vector2(0.82, 0.82)
	victory_title.pivot_offset = victory_title.size * 0.5
	AudioManager.play_sfx(PRESENTATION_IMPACT_SFX, -5.0)
	_animation_active = true
	_current_tween = create_tween().set_parallel(true)
	_current_tween.tween_property(
		victory_title,
		"modulate:a",
		1.0,
		victory_reveal_duration,
	)
	_current_tween.tween_property(
		victory_title,
		"scale",
		Vector2.ONE,
		victory_reveal_duration,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var generation := _sequence_generation
	_current_tween.finished.connect(func():
		if generation == _sequence_generation:
			_animation_active = false
			continue_button.grab_focus()
	)


func _start_stats_reveal() -> void:
	phase_title.text = "RAPPORT DE COMBAT"
	status_label.text = "Statistiques enregistrées depuis les événements réels."
	continue_button.text = "VOIR LA PROGRESSION"
	continue_button.disabled = false
	stats_cards.modulate.a = 0.0
	_animation_active = true
	_current_tween = create_tween()
	_current_tween.tween_property(
		stats_cards,
		"modulate:a",
		1.0,
		stats_reveal_duration,
	)
	var generation := _sequence_generation
	_current_tween.finished.connect(func():
		if generation == _sequence_generation:
			_animation_active = false
			continue_button.grab_focus()
	)


func _start_progression_reveal() -> void:
	phase_title.text = "PROGRESSION DES DISCIPLINES"
	status_label.text = "Récapitulatif — aucun nouveau choix n’est demandé."
	continue_button.text = (
		"TERMINER LA RUN" if _final_room else "VOIR LES RÉCOMPENSES"
	)
	continue_button.disabled = false
	_prepare_progression_initial_values()
	_animation_active = true
	_animate_progression(_sequence_generation)


func _animate_progression(generation: int) -> void:
	var changed := false
	for row in _progress_rows:
		if generation != _sequence_generation:
			return
		var delta := row.get("delta") as DisciplineProgressDelta
		if delta == null or not delta.has_progress():
			_set_progress_row_final(row)
			continue
		changed = true
		var targets: Array[int] = []
		for threshold in delta.thresholds:
			var threshold_xp := int(threshold.get("required_total_xp", -1))
			if threshold_xp > delta.xp_before and threshold_xp <= delta.xp_after:
				targets.append(threshold_xp)
		if targets.is_empty() or targets.back() != delta.xp_after:
			targets.append(delta.xp_after)
		for target_xp in targets:
			var bar := row.get("bar") as ProgressBar
			_current_tween = create_tween()
			_current_tween.tween_property(
				bar,
				"value",
				target_xp,
				progression_step_duration,
			).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			await _current_tween.finished
			if generation != _sequence_generation:
				return
			_update_progress_row_at_xp(row, target_xp)
			if target_xp != delta.xp_after:
				AudioManager.play_sfx(PRESENTATION_IMPACT_SFX, -9.0)
				await get_tree().create_timer(threshold_pause_duration).timeout
				if generation != _sequence_generation:
					return
		_set_progress_row_final(row)
	if not changed:
		await get_tree().create_timer(0.12).timeout
	if generation == _sequence_generation:
		_animation_active = false
		continue_button.grab_focus()


func _finish_current_animation() -> void:
	_sequence_generation += 1
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.custom_step(99.0)
	match phase:
		Phase.VICTORY_REVEAL:
			victory_title.modulate.a = 1.0
			victory_title.scale = Vector2.ONE
		Phase.COMBAT_STATS:
			stats_cards.modulate.a = 1.0
		Phase.PROGRESSION:
			for row in _progress_rows:
				_set_progress_row_final(row)
	_animation_active = false
	continue_button.grab_focus()


func _begin_transition() -> void:
	if _transition_requested or (not _final_room and not _reward_applied):
		return
	_transition_requested = true
	phase = Phase.TRANSITIONING
	phase_title.text = "RUN TERMINÉE" if _final_room else "VERS LA SALLE SUIVANTE"
	status_label.text = (
		"Validation de la victoire finale…"
		if _final_room
		else "Préparation du prochain combat…"
	)
	continue_button.disabled = true
	transition_layer.show()
	transition_layer.modulate.a = 0.0
	_current_tween = create_tween()
	_current_tween.tween_property(
		transition_layer,
		"modulate:a",
		1.0,
		transition_duration,
	)
	await _current_tween.finished
	if not GameManager.complete_post_combat_transition(report.report_id):
		_transition_requested = false
		phase = Phase.COMPLETED
		transition_layer.hide()
		continue_button.disabled = false
		reward_error.text = "La transition a été refusée. La récompense reste enregistrée."
		reward_error.show()


func _configure_background() -> void:
	background.texture = GameManager.get_post_combat_background_texture()
	var room := GameManager.get_current_room()
	if background.texture == null and room != null:
		background.texture = room.background_image
		if background.texture == null and room.painted_map_visual_data != null:
			background.texture = room.painted_map_visual_data.load_background_texture()
	background_dim.color = Color(0.015, 0.02, 0.024, 0.82)


func _build_stat_cards() -> void:
	_clear_container(stats_cards)
	for character in report.character_reports:
		stats_cards.add_child(_make_stat_card(character))


func _make_stat_card(character: CharacterCombatReport) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SkillTreeCharacterHeader"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 12)
	content.add_child(identity)
	var state := GameManager.get_character_state(character.character_id)
	identity.add_child(_make_character_visual(state))
	var title := Label.new()
	title.text = character.display_name.to_upper()
	title.add_theme_font_size_override("font_size", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity.add_child(title)
	var values := [
		["Dégâts infligés", character.damage_dealt],
		["Dégâts subis", character.damage_taken],
		["Soins", character.healing_done],
		["Boucliers", character.shield_applied],
		["Éliminations", character.kills],
		["Sorts lancés", character.spells_cast_total],
		["Cases parcourues", character.cells_moved],
	]
	for entry in values:
		var line := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = entry[0]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label := Label.new()
		value_label.text = str(entry[1])
		value_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.36))
		value_label.add_theme_font_size_override("font_size", 18)
		line.add_child(name_label)
		line.add_child(value_label)
		content.add_child(line)
	return panel


func _make_character_visual(state: CharacterRunState) -> Control:
	var theme_data := (
		CharacterHUDThemeCatalog.resolve_refined(state.unit)
		if state != null and state.unit != null
		else null
	)
	if theme_data != null and theme_data.portrait_texture != null:
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(74, 74)
		portrait.texture = theme_data.portrait_texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return portrait
	if state != null \
			and state.unit != null \
			and state.unit.character_data != null \
			and state.unit.character_data.preview_visual_scene != null:
		var preview := CHARACTER_PREVIEW_SCENE.instantiate() as CharacterPreview3D
		preview.custom_minimum_size = Vector2(92, 78)
		preview.unit_data = state.unit.character_data
		return preview
	var fallback := TextureRect.new()
	fallback.custom_minimum_size = Vector2(74, 74)
	fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if state != null and state.unit != null and state.unit.sprite_frames != null:
		var animation := state.unit.idle_animation
		if not state.unit.sprite_frames.has_animation(animation):
			animation = state.unit.sprite_frames.get_animation_names()[0]
		if state.unit.sprite_frames.get_frame_count(animation) > 0:
			fallback.texture = state.unit.sprite_frames.get_frame_texture(animation, 0)
	return fallback


func _build_progression_cards() -> void:
	_clear_container(progression_cards)
	_progress_rows.clear()
	for character in report.character_reports:
		progression_cards.add_child(_make_progression_card(character))


func _make_progression_card(character: CharacterCombatReport) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SkillTreeCanvasSurface"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var title := Label.new()
	title.text = character.display_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	for delta in character.discipline_deltas:
		var row := _make_progression_row(delta)
		content.add_child(row["control"])
		_progress_rows.append(row)
	return panel


func _make_progression_row(delta: DisciplineProgressDelta) -> Dictionary:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SkillTreeDetailReadingSurface"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.texture = delta.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var name_label := Label.new()
	name_label.text = delta.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var rank_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 15)
	rank_label.text = "Rang %d" % delta.rank_before
	rank_label.add_theme_color_override("font_color", Color(0.91, 0.72, 0.31))
	header.add_child(rank_label)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"SkillTreeXpProgress"
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = _progress_bar_max(delta)
	bar.value = delta.xp_before
	content.add_child(bar)
	var footer := HBoxContainer.new()
	content.add_child(footer)
	var xp_label := Label.new()
	xp_label.text = "%d XP" % delta.xp_before
	xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_label.add_theme_font_size_override("font_size", 12)
	footer.add_child(xp_label)
	var node_label := Label.new()
	node_label.text = ""
	node_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	node_label.add_theme_font_size_override("font_size", 12)
	node_label.add_theme_color_override("font_color", Color(0.55, 0.91, 0.66))
	footer.add_child(node_label)
	return {
		"control": panel,
		"delta": delta,
		"bar": bar,
		"rank_label": rank_label,
		"xp_label": xp_label,
		"node_label": node_label,
	}


func _prepare_progression_initial_values() -> void:
	for row in _progress_rows:
		var delta := row.get("delta") as DisciplineProgressDelta
		(row.get("bar") as ProgressBar).value = delta.xp_before
		(row.get("rank_label") as Label).text = "Rang %d" % delta.rank_before
		(row.get("xp_label") as Label).text = "%d XP" % delta.xp_before
		(row.get("node_label") as Label).text = ""


func _update_progress_row_at_xp(row: Dictionary, current_xp: int) -> void:
	var delta := row.get("delta") as DisciplineProgressDelta
	var current_rank := delta.rank_before
	for threshold in delta.thresholds:
		if current_xp >= int(threshold.get("required_total_xp", 0)):
			current_rank = maxi(current_rank, int(threshold.get("rank", current_rank)))
	(row.get("rank_label") as Label).text = "Rang %d" % current_rank
	(row.get("xp_label") as Label).text = "%d XP" % current_xp
	var acquired_names: Array[String] = []
	for acquired in delta.acquired_nodes:
		if int(acquired.get("rank", 0)) <= current_rank:
			acquired_names.append(str(acquired.get("display_name", "")))
	(row.get("node_label") as Label).text = " · ".join(acquired_names)


func _set_progress_row_final(row: Dictionary) -> void:
	var delta := row.get("delta") as DisciplineProgressDelta
	(row.get("bar") as ProgressBar).value = delta.xp_after
	(row.get("rank_label") as Label).text = "Rang %d" % delta.rank_after
	(row.get("xp_label") as Label).text = "%d → %d XP" % [
		delta.xp_before,
		delta.xp_after,
	]
	var acquired_names: Array[String] = []
	for acquired in delta.acquired_nodes:
		acquired_names.append(str(acquired.get("display_name", "")))
	(row.get("node_label") as Label).text = (
		" · ".join(acquired_names) if not acquired_names.is_empty() else ""
	)


func _progress_bar_max(delta: DisciplineProgressDelta) -> int:
	var result := maxi(maxi(delta.xp_after, delta.xp_before), 1)
	if delta.next_threshold_after > 0:
		result = maxi(result, delta.next_threshold_after)
	for threshold in delta.thresholds:
		result = maxi(result, int(threshold.get("required_total_xp", 0)))
	return result


func _build_reward_cards() -> void:
	_clear_container(reward_cards)
	_clear_container(recipient_cards)
	_reward_buttons.clear()
	_recipient_buttons.clear()
	recipient_panel.hide()
	_reward_options = GameManager.get_post_combat_reward_options()
	_selected_reward_id = &""
	_selected_target_character_id = &""


func _on_overlay_selection_changed(item_id: StringName) -> void:
	if phase != Phase.REWARD_SELECTION or _reward_applied:
		return
	if not GameManager.select_post_combat_equipment(item_id):
		reward_overlay.resolve_confirmation(
			false,
			"Cette sélection n’est plus disponible.",
		)
		return
	_selected_reward_id = item_id
	_selected_target_character_id = &""
	var option := _find_reward_option(item_id)
	var compatible_ids := option.get("compatible_character_ids", []) as Array
	if not compatible_ids.is_empty():
		_selected_target_character_id = StringName(compatible_ids[0])


func _on_overlay_confirmation_requested(item_id: StringName) -> void:
	if item_id != _selected_reward_id:
		return
	confirm_selected_reward()


func _on_overlay_confirmation_finished() -> void:
	if phase == Phase.COMPLETED and _reward_applied:
		_begin_transition()


func _make_reward_button(option: Dictionary) -> Button:
	var definition := option.get("definition") as ItemDefinition
	var button := Button.new()
	button.theme_type_variation = &"SkillTreeAcquireButton"
	button.custom_minimum_size = Vector2(320, 275)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.clip_contents = true
	button.text = ""
	button.tooltip_text = definition.description if definition != null else ""
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	button.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(150, 150)
	icon.texture = _visible_item_texture(definition.icon) if definition != null else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var title := Label.new()
	title.text = definition.display_name.to_upper() if definition != null else "OBJET INVALIDE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.58))
	title.add_theme_font_size_override("font_size", 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	var category := Label.new()
	category.text = (
		"%s · %s" % [
			_category_display_name(definition.category),
			EquipmentLoadout.get_slot_display_name(definition.equipment_slot),
		]
		if definition != null
		else ""
	)
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category.add_theme_color_override("font_color", Color(0.64, 0.72, 0.7))
	category.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(category)
	var description := Label.new()
	description.text = definition.description if definition != null else ""
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(description)
	var target := Label.new()
	target.text = "Compatible : %s" % _compatible_hero_names(option)
	target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target.add_theme_color_override("font_color", Color(0.64, 0.72, 0.7))
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(target)
	button.pressed.connect(_select_reward.bind(option))
	return button


func _visible_item_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	var used := _non_black_content_rect(image)
	if used.size.x <= 0 or used.size.y <= 0 \
			or used.size == Vector2i(image.get_width(), image.get_height()):
		return source
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = Rect2(used)
	return cropped


func _non_black_content_rect(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.01 or maxf(pixel.r, maxf(pixel.g, pixel.b)) <= 0.025:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	var padding := 8
	minimum -= Vector2i.ONE * padding
	maximum += Vector2i.ONE * padding
	minimum.x = maxi(0, minimum.x)
	minimum.y = maxi(0, minimum.y)
	maximum.x = mini(image.get_width() - 1, maximum.x)
	maximum.y = mini(image.get_height() - 1, maximum.y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _select_reward(option: Dictionary) -> void:
	if phase != Phase.REWARD_SELECTION or _reward_applied:
		return
	_selected_reward_id = StringName(option.get("reward_id", &""))
	_selected_target_character_id = &""
	for reward_id in _reward_buttons:
		var button := _reward_buttons[reward_id] as Button
		button.button_pressed = StringName(reward_id) == _selected_reward_id
		button.self_modulate = (
			Color(1.08, 1.02, 0.82)
			if StringName(reward_id) == _selected_reward_id
			else Color(0.72, 0.74, 0.74)
		)
	_build_recipient_buttons(option)
	reward_error.hide()
	status_label.text = "Objet sélectionné — choisissez maintenant son porteur."
	continue_button.disabled = true
	_focus_first_compatible_recipient(option)


func _focus_first_reward() -> void:
	if _reward_options.is_empty():
		reward_error.text = "Aucune récompense valide n’est disponible."
		reward_error.show()
		continue_button.disabled = true
		return
	var first_id := StringName(_reward_options[0].get("reward_id", &""))
	var first_button := _reward_buttons.get(first_id) as Button
	if first_button != null:
		first_button.grab_focus()


func _build_recipient_buttons(option: Dictionary) -> void:
	_clear_container(recipient_cards)
	_recipient_buttons.clear()
	recipient_panel.show()
	comparison_label.text = "Sélectionnez un héros compatible pour comparer l’emplacement."
	var compatible_ids := option.get("compatible_character_ids", []) as Array
	for state in GameManager.get_ordered_character_states():
		if state == null:
			continue
		var button := Button.new()
		button.theme_type_variation = &"SkillTreeAcquireButton"
		button.custom_minimum_size = Vector2(210, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.text = _recipient_button_text(state, compatible_ids.has(state.character_id))
		button.disabled = not compatible_ids.has(state.character_id)
		button.pressed.connect(_select_recipient.bind(state.character_id))
		recipient_cards.add_child(button)
		_recipient_buttons[state.character_id] = button


func _recipient_button_text(state: CharacterRunState, compatible: bool) -> String:
	var definition := _selected_item_definition()
	var hero_name := state.unit.unit_name if state.unit != null else str(state.character_id)
	if not compatible or definition == null:
		return "%s\nIncompatible" % hero_name
	var comparison := GameManager.get_equipment_reward_comparison(
		definition.item_id,
		state.character_id,
	)
	return "%s\nActuel : %s\n%s" % [
		hero_name,
		str(comparison.get("current_item_name", "Aucun")),
		_format_stat_deltas(comparison.get("stat_deltas", {}) as Dictionary),
	]


func _select_recipient(character_id: StringName) -> void:
	if phase != Phase.REWARD_SELECTION or _reward_applied:
		return
	var option := _find_reward_option(_selected_reward_id)
	if option.is_empty():
		return
	var compatible_ids := option.get("compatible_character_ids", []) as Array
	if not compatible_ids.has(character_id):
		return
	_selected_target_character_id = character_id
	for recipient_id in _recipient_buttons:
		var button := _recipient_buttons[recipient_id] as Button
		button.button_pressed = StringName(recipient_id) == character_id
	var comparison := GameManager.get_equipment_reward_comparison(
		_selected_reward_id,
		character_id,
	)
	comparison_label.text = "Remplace : %s · Variation exacte : %s\n%s" % [
		str(comparison.get("current_item_name", "Aucun")),
		_format_stat_deltas(comparison.get("stat_deltas", {}) as Dictionary),
		str(comparison.get("new_description", "")),
	]
	reward_error.hide()
	status_label.text = "Porteur sélectionné — confirmez l’équipement."
	continue_button.disabled = false
	continue_button.grab_focus()


func _focus_first_compatible_recipient(option: Dictionary) -> void:
	var compatible_ids := option.get("compatible_character_ids", []) as Array
	for state in GameManager.get_ordered_character_states():
		if state != null and compatible_ids.has(state.character_id):
			var button := _recipient_buttons.get(state.character_id) as Button
			if button != null:
				button.grab_focus()
			return


func _selected_item_definition() -> ItemDefinition:
	var option := _find_reward_option(_selected_reward_id)
	return option.get("definition") as ItemDefinition if not option.is_empty() else null


func _find_reward_option(reward_id: StringName) -> Dictionary:
	for option in _reward_options:
		if StringName(option.get("reward_id", &"")) == reward_id:
			return option
	return {}


func _compatible_hero_names(option: Dictionary) -> String:
	var names: Array[String] = []
	var compatible_ids := option.get("compatible_character_ids", []) as Array
	for state in GameManager.get_ordered_character_states():
		if state != null and compatible_ids.has(state.character_id):
			names.append(
				state.unit.unit_name if state.unit != null else str(state.character_id)
			)
	return ", ".join(names) if not names.is_empty() else "aucun héros"


func _category_display_name(category: int) -> String:
	match category:
		ItemDefinition.Category.WEAPON:
			return "Arme"
		ItemDefinition.Category.ARMOR:
			return "Armure"
		ItemDefinition.Category.ACCESSORY:
			return "Accessoire"
		_:
			return "Objet"


func _format_stat_deltas(deltas: Dictionary) -> String:
	if deltas.is_empty():
		return "aucune statistique de base"
	var parts: Array[String] = []
	var stat_ids := deltas.keys()
	stat_ids.sort()
	for stat_id in stat_ids:
		var value := float(deltas[stat_id])
		if is_zero_approx(value):
			continue
		parts.append("%s %+.0f" % [str(stat_id), value])
	return ", ".join(parts) if not parts.is_empty() else "aucune variation"


func _show_fatal_error(message: String) -> void:
	safe_margin.show()
	reward_overlay.hide()
	phase_title.text = "APRÈS-COMBAT INDISPONIBLE"
	status_label.text = message
	continue_button.disabled = true
	victory_panel.hide()
	stats_panel.hide()
	progression_panel.hide()
	rewards_panel.hide()


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
