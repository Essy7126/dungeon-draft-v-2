extends Control

const COMPACT_WIDTH := 1440.0
const COMPACT_HEIGHT := 820.0
const TRANSITION_FADE_DURATION := 0.16
const ENTRY_DURATION := 0.24

@onready var fond_image: TextureRect = %FondImage
@onready var fond_overlay: ColorRect = %FondOverlay
@onready var atmosphere: Node = %Atmosphere
@onready var safe_margin: MarginContainer = %SafeMargin
@onready var dossier: PanelContainer = %Dossier
@onready var dossier_margin: MarginContainer = %DossierMargin
@onready var content: VBoxContainer = %Contenu
@onready var room_number_label: Label = %RoomNumber
@onready var nom_salle: Label = %Nomsalle
@onready var description: Label = %Description
@onready var run_eyebrow: Label = %RunEyebrow
@onready var intel_grid: GridContainer = %IntelGrid
@onready var hero_card: PanelContainer = %HeroCard
@onready var heroes_container: VBoxContainer = %Heroes
@onready var hero_condition: Label = %HeroCondition
@onready var threat_card: PanelContainer = %ThreatCard
@onready var threat_value: Label = %ThreatValue
@onready var threat_detail: Label = %ThreatDetail
@onready var progress_panel: PanelContainer = %ProgressPanel
@onready var progress_value: Label = %ProgressValue
@onready var route_progress: ProgressBar = %RouteProgress
@onready var progress_steps: HBoxContainer = %ProgressSteps
@onready var bouton: Button = %BoutonContinuer
@onready var input_hint: Label = %InputHint
@onready var status_label: Label = %StatusLabel
@onready var transition_layer: ColorRect = %TransitionLayer

var _reduced_motion := false
var _transition_committed := false
var _battle_start_invoked := false
var _room_available := false
var _layout_profile := &"compact"
var _entry_tween: Tween = null
var _transition_tween: Tween = null
var _start_battle_action: Callable
var _active_snapshot: Dictionary = {}


func _ready() -> void:
	PremiumUI.apply(self)
	_reduced_motion = GameManager.is_reduced_motion_enabled()
	_start_battle_action = Callable(GameManager, "start_next_battle")
	if not bouton.pressed.is_connected(request_continue):
		bouton.pressed.connect(request_continue)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	var room := GameManager.get_current_room()
	_configure_runtime_particles(room)
	_apply_snapshot(_build_runtime_snapshot(room))
	_play_entry_transition()


func _exit_tree() -> void:
	_kill_tween(_entry_tween)
	_kill_tween(_transition_tween)


func _unhandled_input(event: InputEvent) -> void:
	if _transition_committed or not _room_available or bouton.disabled:
		return
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		request_continue()


## Point d'entrée unique du clic, d'Entrée et du bouton A de la manette.
## Le booléen facilite les validations sans dépendre d'un changement de scène.
func request_continue() -> bool:
	if _transition_committed or not _room_available or bouton.disabled:
		return false
	_transition_committed = true
	bouton.disabled = true
	bouton.release_focus()
	input_hint.visible = false
	status_label.visible = true
	status_label.text = "OUVERTURE DU PASSAGE…"
	_kill_tween(_entry_tween)
	if _reduced_motion or not is_inside_tree():
		_invoke_start_battle()
		return true
	transition_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_layer.modulate.a = 0.0
	_transition_tween = create_tween()
	_transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition_tween.tween_property(
		transition_layer,
		"modulate:a",
		1.0,
		TRANSITION_FADE_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.finished.connect(_invoke_start_battle)
	return true


func _invoke_start_battle() -> void:
	if _battle_start_invoked:
		return
	_battle_start_invoked = true
	if _start_battle_action.is_valid():
		_start_battle_action.call()


func _build_runtime_snapshot(room: RoomData) -> Dictionary:
	if room == null:
		return {
			"available": false,
			"error": "La prochaine salle est indisponible.",
		}
	var run_data := GameManager.get_active_run_data()
	var hero_snapshots: Array[Dictionary] = []
	for hero_value in GameManager.get_living_heroes():
		var hero := hero_value as Unit
		if hero == null:
			continue
		hero_snapshots.append({
			"name": hero.unit_name,
			"current_hp": hero.current_hp,
			"max_hp": hero.max_hp.get_int(),
		})
	var wave_count := room.get_wave_count()
	var enemy_count := _get_enemy_count(room)
	return {
		"available": room.battle_scene != null,
		"error": (
			"Aucun combat n’est associé à cette salle."
			if room.battle_scene == null else ""
		),
		"run_name": run_data.run_name if run_data != null else "Run",
		"room_name": room.room_name,
		"room_number": GameManager.current_room_index + 1,
		"room_total": GameManager.rooms.size(),
		"enemy_count": enemy_count,
		"wave_count": wave_count,
		"heroes": hero_snapshots,
		"background": _resolve_room_background(room),
	}


func _apply_snapshot(snapshot: Dictionary) -> void:
	_active_snapshot = snapshot.duplicate(true)
	_transition_committed = false
	_battle_start_invoked = false
	transition_layer.modulate.a = 0.0
	transition_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_available = bool(snapshot.get("available", false))
	var room_number := maxi(1, int(snapshot.get("room_number", 1)))
	var room_total := maxi(room_number, int(snapshot.get("room_total", room_number)))
	var run_name := str(snapshot.get("run_name", "Run")).strip_edges()
	var full_room_name := str(snapshot.get("room_name", "Salle")).strip_edges()
	var display_room_name := _strip_room_prefix(full_room_name)
	run_eyebrow.text = _build_run_eyebrow(run_name)
	room_number_label.text = "SALLE %s / %s" % [
		_to_roman(room_number),
		_to_roman(room_total),
	]
	nom_salle.text = display_room_name.to_upper()
	description.text = (
		"Le seuil est ouvert. Préparez votre entrée."
		if _room_available
		else str(snapshot.get("error", "Salle indisponible."))
	)
	var background := snapshot.get("background") as Texture2D
	fond_image.texture = background
	fond_image.visible = background != null
	_build_heroes(snapshot.get("heroes", []) as Array)
	_configure_threat(
		int(snapshot.get("enemy_count", 0)),
		maxi(0, int(snapshot.get("wave_count", 0))),
	)
	_build_progress(room_number, room_total)
	bouton.text = "ENTRER DANS LA SALLE %s" % _to_roman(room_number)
	bouton.disabled = not _room_available
	input_hint.visible = _room_available
	status_label.visible = not _room_available
	status_label.text = (
		"PASSAGE INDISPONIBLE"
		if not _room_available else ""
	)
	if _room_available:
		_focus_cta.call_deferred()


func _build_heroes(hero_snapshots: Array) -> void:
	_clear_children(heroes_container)
	if hero_snapshots.is_empty():
		var empty_label := Label.new()
		empty_label.theme_type_variation = &"PremiumMuted"
		empty_label.text = "Aucun héros apte au combat"
		heroes_container.add_child(empty_label)
		hero_condition.theme_type_variation = &"PremiumDanger"
		hero_condition.text = "ÉTAT CRITIQUE"
		return
	var lowest_ratio := 1.0
	for hero_value in hero_snapshots:
		var hero := hero_value as Dictionary
		var hero_name := str(hero.get("name", "Héros")).strip_edges()
		var maximum := maxi(1, int(hero.get("max_hp", 1)))
		var current := clampi(int(hero.get("current_hp", 0)), 0, maximum)
		lowest_ratio = minf(lowest_ratio, float(current) / float(maximum))
		heroes_container.add_child(_create_hero_row(hero_name, current, maximum))
	if lowest_ratio <= 0.25:
		hero_condition.theme_type_variation = &"PremiumDanger"
		hero_condition.text = "BLESSURES CRITIQUES"
	elif lowest_ratio <= 0.55:
		hero_condition.theme_type_variation = &"PremiumEyebrow"
		hero_condition.text = "VIGILANCE RECOMMANDÉE"
	else:
		hero_condition.theme_type_variation = &"PremiumPositive"
		hero_condition.text = "PRÊT À COMBATTRE"


func _create_hero_row(hero_name: String, current: int, maximum: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Hero_%s" % hero_name.validate_node_name()
	row.add_theme_constant_override(&"separation", 10)
	var name_label := Label.new()
	name_label.custom_minimum_size.x = 96.0
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.theme_type_variation = &"PremiumSubtitle"
	name_label.text = hero_name
	row.add_child(name_label)
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(132.0, 18.0)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.theme_type_variation = &"PremiumProgress"
	hp_bar.min_value = 0.0
	hp_bar.max_value = float(maximum)
	hp_bar.value = float(current)
	hp_bar.show_percentage = false
	row.add_child(hp_bar)
	var hp_label := Label.new()
	hp_label.custom_minimum_size.x = 82.0
	hp_label.theme_type_variation = &"PremiumBody"
	hp_label.text = "%d / %d PV" % [current, maximum]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(hp_label)
	return row


func _configure_threat(enemy_count: int, wave_count: int) -> void:
	var has_intel := enemy_count > 0 or wave_count > 0
	threat_card.visible = has_intel
	if not has_intel:
		return
	var score := enemy_count + maxi(0, wave_count - 1) * 2
	var level := "CONTENUE"
	if score >= 5:
		level = "MAJEURE"
	elif score >= 3:
		level = "ÉLEVÉE"
	elif score >= 2:
		level = "SIGNIFICATIVE"
	threat_value.text = "MENACE · %s" % level
	var enemy_word := "adversaire" if enemy_count == 1 else "adversaires"
	var engagement_word := "engagement" if wave_count == 1 else "engagements"
	threat_detail.text = "%d %s · %d %s" % [
		enemy_count,
		enemy_word,
		maxi(1, wave_count),
		engagement_word,
	]


func _build_progress(room_number: int, room_total: int) -> void:
	progress_value.text = "%d / %d" % [room_number, room_total]
	route_progress.max_value = float(maxi(1, room_total))
	route_progress.value = float(room_number)
	_clear_children(progress_steps)
	for index in room_total:
		var step_number := index + 1
		var step := Label.new()
		step.text = "%s %s" % [
			"◆" if step_number == room_number else ("✓" if step_number < room_number else "◇"),
			_to_roman(step_number),
		]
		step.theme_type_variation = (
			&"PremiumSelectionBadge"
			if step_number == room_number else &"PremiumMuted"
		)
		progress_steps.add_child(step)


func _get_enemy_count(room: RoomData) -> int:
	if room.encounter_definition != null:
		return room.encounter_definition.get_initial_enemy_count()
	if not room.waves.is_empty():
		var first_wave := room.get_encounter_for_wave(0)
		if first_wave != null:
			return first_wave.get_initial_enemy_count()
	return room.enemies.size()


func _resolve_room_background(room: RoomData) -> Texture2D:
	if room.background_image != null:
		return room.background_image
	if room.painted_map_visual_data != null:
		return room.painted_map_visual_data.load_background_texture()
	return null


func _configure_runtime_particles(room: RoomData) -> void:
	if room == null or room.particles_scene == null:
		return
	var particles := room.particles_scene.instantiate()
	atmosphere.add_child(particles)
	if particles is Control:
		particles.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _play_entry_transition() -> void:
	_kill_tween(_entry_tween)
	dossier.pivot_offset = dossier.size * 0.5
	if _reduced_motion:
		dossier.modulate.a = 1.0
		dossier.scale = Vector2.ONE
		return
	dossier.modulate.a = 0.0
	dossier.scale = Vector2(0.975, 0.975)
	_entry_tween = create_tween().set_parallel(true)
	_entry_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_entry_tween.tween_property(
		dossier,
		"modulate:a",
		1.0,
		ENTRY_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_entry_tween.tween_property(
		dossier,
		"scale",
		Vector2.ONE,
		ENTRY_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_responsive_layout() -> void:
	_apply_layout_for_size(get_viewport_rect().size)


func _apply_layout_for_size(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact := viewport_size.x < COMPACT_WIDTH or viewport_size.y < COMPACT_HEIGHT
	_layout_profile = &"compact" if compact else &"wide"
	var horizontal_margin := 20 if compact else 48
	var vertical_margin := 16 if compact else 34
	_set_margin(safe_margin, horizontal_margin, vertical_margin)
	var available := viewport_size - Vector2(
		float(horizontal_margin * 2),
		float(vertical_margin * 2),
	)
	var desired_width := clampf(viewport_size.x * 0.68, 720.0, 980.0)
	var desired_height := clampf(viewport_size.y * 0.90, 600.0, 720.0)
	dossier.custom_minimum_size = Vector2(
		minf(desired_width, available.x),
		minf(desired_height, available.y),
	)
	var content_horizontal := 24 if compact else 38
	var content_vertical := 18 if compact else 28
	_set_margin(dossier_margin, content_horizontal, content_vertical)
	content.add_theme_constant_override(&"separation", 8 if compact else 12)
	nom_salle.add_theme_font_size_override(&"font_size", 34 if compact else 44)
	room_number_label.add_theme_font_size_override(&"font_size", 18 if compact else 21)
	intel_grid.columns = 2 if available.x >= 900.0 else 1
	intel_grid.custom_minimum_size.y = 136.0 if compact else 158.0
	hero_card.custom_minimum_size = Vector2(340.0, intel_grid.custom_minimum_size.y)
	threat_card.custom_minimum_size = Vector2(340.0, intel_grid.custom_minimum_size.y)
	progress_panel.custom_minimum_size.y = 82.0 if compact else 98.0
	bouton.custom_minimum_size = Vector2(360.0, 54.0 if compact else 62.0)


func _set_margin(container: MarginContainer, horizontal: int, vertical: int) -> void:
	container.add_theme_constant_override(&"margin_left", horizontal)
	container.add_theme_constant_override(&"margin_top", vertical)
	container.add_theme_constant_override(&"margin_right", horizontal)
	container.add_theme_constant_override(&"margin_bottom", vertical)


func _focus_cta() -> void:
	if is_inside_tree() and _room_available and not bouton.disabled:
		bouton.grab_focus()


func _build_run_eyebrow(run_name: String) -> String:
	if run_name.to_lower() == "catabase":
		return "DOSSIER DE L’ARCHIVISTE · CATABASE"
	if run_name.is_empty() or run_name.to_lower() == "run":
		return "DOSSIER DE ROUTE"
	return "DOSSIER DE ROUTE · %s" % run_name.to_upper()


func _strip_room_prefix(full_name: String) -> String:
	if full_name.is_empty():
		return "SALLE INCONNUE"
	var em_dash := full_name.find("—")
	if em_dash >= 0 and em_dash + 1 < full_name.length():
		return full_name.substr(em_dash + 1).strip_edges()
	if full_name.to_lower().begins_with("salle "):
		var separator := full_name.find(" - ")
		if separator >= 0 and separator + 3 < full_name.length():
			return full_name.substr(separator + 3).strip_edges()
	return full_name


func _to_roman(value: int) -> String:
	if value <= 0:
		return str(value)
	var remaining := value
	var result := ""
	var values := [10, 9, 5, 4, 1]
	var glyphs := ["X", "IX", "V", "IV", "I"]
	for index in values.size():
		while remaining >= values[index]:
			remaining -= values[index]
			result += glyphs[index]
	return result


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.free()


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


# --- Seams de validation, sans rendu GPU ni mutation de GameManager. ---
func apply_runtime_snapshot_for_test(
		snapshot: Dictionary,
		reduced_motion := true
	) -> void:
	_reduced_motion = reduced_motion
	_kill_tween(_entry_tween)
	_kill_tween(_transition_tween)
	_apply_snapshot(snapshot)
	_play_entry_transition()


func apply_viewport_size_for_test(viewport_size: Vector2) -> Dictionary:
	_apply_layout_for_size(viewport_size)
	return get_layout_snapshot_for_test()


func set_start_battle_callable_for_test(action: Callable) -> void:
	_start_battle_action = action


func get_presentation_snapshot_for_test() -> Dictionary:
	return {
		"room_number": room_number_label.text,
		"room_name": nom_salle.text,
		"run_eyebrow": run_eyebrow.text,
		"hero_count": heroes_container.get_child_count(),
		"hero_condition": hero_condition.text,
		"threat_visible": threat_card.visible,
		"threat": threat_value.text,
		"threat_detail": threat_detail.text,
		"progress": progress_value.text,
		"progress_step_count": progress_steps.get_child_count(),
		"cta": bouton.text,
		"cta_disabled": bouton.disabled,
		"transition_committed": _transition_committed,
		"battle_start_invoked": _battle_start_invoked,
	}


func get_layout_snapshot_for_test() -> Dictionary:
	return {
		"profile": _layout_profile,
		"dossier_minimum": dossier.custom_minimum_size,
		"safe_left": safe_margin.get_theme_constant(&"margin_left"),
		"safe_top": safe_margin.get_theme_constant(&"margin_top"),
		"title_font_size": nom_salle.get_theme_font_size(&"font_size"),
		"cta_minimum": bouton.custom_minimum_size,
		"background_stretch_mode": int(fond_image.stretch_mode),
		"overlay_alpha": fond_overlay.color.a,
	}
