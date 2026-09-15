extends Control

const CATABASE_ART := preload("res://ui/expedition/catabase_ui_theme.gd")

const DEFEAT_COLOR := Color(0.94, 0.48, 0.36, 1.0)
const VICTORY_COLOR := Color(0.94, 0.78, 0.42, 1.0)

@onready var background: TextureRect = %Background
@onready var panel: PanelContainer = %Panel
@onready var main_margin: MarginContainer = %MainMargin
@onready var content: VBoxContainer = %Content
@onready var crest: TextureRect = %Crest
@onready var register_label: Label = %Register
@onready var result_label: Label = %Result
@onready var run_name_label: Label = %RunName
@onready var location_panel: PanelContainer = %LocationPanel
@onready var location_eyebrow: Label = %LocationEyebrow
@onready var location_label: Label = %Location
@onready var progression_label: Label = %Progression
@onready var stats: HBoxContainer = %Stats
@onready var depth_value: Label = %DepthValue
@onready var cleared_value: Label = %ClearedValue
@onready var combats_value: Label = %CombatsValue
@onready var level_value: Label = %LevelValue
@onready var narrative_panel: PanelContainer = %NarrativePanel
@onready var hero_status_label: Label = %HeroStatus
@onready var epitaph_label: Label = %Epitaph
@onready var seed_label: Label = %Seed
@onready var new_attempt_button: Button = %NewAttemptButton
@onready var menu_button: Button = %MenuButton
@onready var return_button: Button = %MenuButton
@onready var navigation_feedback: Label = %NavigationFeedback

var _default_crest: Texture2D
var _fallback_background: Texture2D
var _is_catabase := false
var _navigation_pending := false
var _entry_tween: Tween


func _ready() -> void:
	_default_crest = crest.texture
	_fallback_background = background.texture
	PremiumUI.apply(self)
	_apply_result(GameManager.get_last_run_result())
	new_attempt_button.pressed.connect(_on_new_attempt_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	if not GameManager.reduced_motion_changed.is_connected(_on_reduced_motion_changed):
		GameManager.reduced_motion_changed.connect(_on_reduced_motion_changed)
	_apply_responsive_layout()
	_play_entry_motion()
	_focus_primary_action.call_deferred()


## Applies only the supplied snapshot. Keeping this method independent from the
## live run makes both victory and defeat layouts testable with factual fixtures.
func _apply_result(result: Dictionary) -> void:
	var victory := bool(result.get("victory", false))
	_is_catabase = bool(result.get("is_catabase", false))
	var is_expedition := _is_catabase and bool(result.get("is_expedition", false))
	_navigation_pending = false
	navigation_feedback.hide()
	_configure_theme(victory)
	_configure_background()
	_configure_identity(result, victory)
	_configure_progress(result, is_expedition, victory)
	_configure_hero_and_epitaph(result, victory)
	_configure_metadata(result)
	_configure_actions()
	_apply_responsive_layout()


func is_navigation_pending() -> bool:
	return _navigation_pending


func _configure_theme(victory: bool) -> void:
	if _is_catabase:
		CATABASE_ART.apply(self)
		CATABASE_ART.apply_button(new_attempt_button, true, false, "continue")
		CATABASE_ART.apply_button(menu_button, false, false, "home")
	else:
		PremiumUI.apply(self)
		_reset_button_art(new_attempt_button)
		_reset_button_art(menu_button)
	crest.texture = _default_crest
	if _is_catabase:
		var icon_name := "victory" if victory else "defeat"
		var result_icon := CATABASE_ART.icon("resources", icon_name)
		if result_icon != null:
			crest.texture = result_icon
	crest.modulate = Color.WHITE if _is_catabase else (
		Color.WHITE if victory else Color(0.78, 0.42, 0.36, 0.78)
	)


func _configure_background() -> void:
	var captured: Texture2D = null
	if GameManager.has_method("get_post_combat_background_texture"):
		captured = GameManager.get_post_combat_background_texture()
	background.texture = captured if captured != null else _fallback_background
	background.modulate = Color(0.76, 0.78, 0.78, 1.0) if captured != null else Color.WHITE


func _configure_identity(result: Dictionary, victory: bool) -> void:
	var run_name := str(result.get("run_name", "")).strip_edges()
	var hero_name := str(result.get("featured_hero_name", "")).strip_edges()
	if _is_catabase:
		register_label.text = "CATABASE · VICTOIRE" if victory else "CATABASE · DÉFAITE"
		result_label.text = (
			"LA TRAVERSÉE EST ACCOMPLIE" if victory else "LE FIL SE ROMPT"
		)
		result_label.modulate = VICTORY_COLOR if victory else DEFEAT_COLOR
		run_name_label.text = (
			"%s DANS LA CATABASE" % hero_name.to_upper()
			if not hero_name.is_empty() else "CATABASE"
		)
	else:
		register_label.text = "REGISTRE DE L’ARCHIVISTE"
		result_label.text = "Victoire" if victory else "Défaite"
		result_label.modulate = PremiumUI.SKIN.text_primary if victory else DEFEAT_COLOR
		run_name_label.text = (
			"Run : %s" % run_name if not run_name.is_empty() else "Run terminé"
		)


func _configure_progress(
		result: Dictionary,
		is_expedition: bool,
		victory: bool,
	) -> void:
	var reached_name := str(result.get("reached_room_name", "")).strip_edges()
	location_eyebrow.text = (
		"ULTIME SEUIL" if victory and _is_catabase else
		"DERNIER LIEU" if _is_catabase else
		"SALLE ATTEINTE"
	)
	location_label.text = reached_name if not reached_name.is_empty() else "Lieu non disponible"
	if is_expedition:
		var depth_reached := maxi(0, int(result.get("depth_reached", 0)))
		var depth_total := maxi(0, int(result.get("depth_total", 0)))
		var depths_cleared := maxi(0, int(result.get("depths_cleared", 0)))
		var combats_won := maxi(0, int(result.get("combats_won", 0)))
		var hero_level := maxi(0, int(result.get("hero_level", 0)))
		progression_label.text = (
			"Profondeur atteinte · %d / %d  ·  %d étapes franchies"
			% [depth_reached, depth_total, depths_cleared]
		)
		depth_value.text = "%d / %d" % [depth_reached, depth_total]
		cleared_value.text = str(depths_cleared)
		combats_value.text = str(combats_won)
		level_value.text = str(hero_level)
		stats.show()
		return
	var rooms_cleared := maxi(0, int(result.get("rooms_cleared", 0)))
	var room_total := maxi(0, int(result.get("room_total", 0)))
	var reached_room := maxi(0, int(result.get("reached_room_number", 0)))
	var parts: Array[String] = ["Salles franchies : %d/%d" % [rooms_cleared, room_total]]
	if reached_room > 0:
		parts.append("Salle atteinte : %d/%d" % [reached_room, room_total])
	progression_label.text = "  ·  ".join(parts)
	stats.hide()


func _configure_hero_and_epitaph(result: Dictionary, victory: bool) -> void:
	var hero_name := str(result.get("featured_hero_name", "")).strip_edges()
	var hero_states: Array = result.get("hero_states", [])
	hero_status_label.visible = not hero_name.is_empty() or not hero_states.is_empty()
	if not hero_states.is_empty() and hero_states[0] is Dictionary:
		var hero: Dictionary = hero_states[0]
		if hero_name.is_empty():
			hero_name = str(hero.get("name", "")).strip_edges()
		var maximum_hp := maxi(0, int(hero.get("max_hp", 0)))
		var current_hp := clampi(int(hero.get("current_hp", 0)), 0, maximum_hp)
		hero_status_label.text = (
			"%s  ·  %d / %d PV" % [hero_name.to_upper(), current_hp, maximum_hp]
			if maximum_hp > 0 else hero_name.to_upper()
		)
	else:
		hero_status_label.text = hero_name.to_upper()
	var epitaph := str(result.get("epitaph", "")).strip_edges()
	if _is_catabase and "archiviste" in epitaph.to_lower():
		epitaph = ""
	if epitaph.is_empty():
		epitaph = _fallback_epitaph(result, victory)
	epitaph_label.text = epitaph


func _fallback_epitaph(result: Dictionary, victory: bool) -> String:
	if _is_catabase:
		if victory:
			return "La Catabase a été traversée."
		var place := str(result.get("reached_room_name", "")).strip_edges()
		return (
			"La traversée s’arrête ici, dans « %s »." % place
			if not place.is_empty() else "Cette traversée s’arrête ici."
		)
	return "L’Archiviste ne dispose d’aucun fait sur cette tentative."


func _configure_metadata(result: Dictionary) -> void:
	var metadata: Array[String] = []
	if _is_catabase and result.has("difficulty_id"):
		metadata.append("DIFFICULTÉ · %s" % _difficulty_name(
			str(result.get("difficulty_id", ""))
		).to_upper())
	if bool(result.get("seed_available", false)):
		metadata.append("GRAINE DU DESTIN · %d" % int(result.get("seed", 0)))
	seed_label.text = "     ◆     ".join(metadata)
	seed_label.visible = not metadata.is_empty()


func _difficulty_name(difficulty_id: String) -> String:
	match difficulty_id.to_lower():
		"easy":
			return "Facile"
		"normal":
			return "Normal"
		_:
			return difficulty_id if not difficulty_id.is_empty() else "Non disponible"


func _configure_actions() -> void:
	new_attempt_button.visible = _is_catabase
	new_attempt_button.text = "Nouvelle tentative"
	menu_button.text = "Menu principal" if _is_catabase else "Retour au menu principal"
	new_attempt_button.disabled = false
	menu_button.disabled = false


func _on_new_attempt_pressed() -> void:
	if not _is_catabase or not _begin_navigation():
		return
	if not GameManager.request_new_catabase_attempt():
		_recover_navigation(
			"La nouvelle tentative n’a pas pu être ouverte. Réessayez."
		)


func _on_menu_pressed() -> void:
	if not _begin_navigation():
		return
	if not GameManager.request_return_to_title():
		_recover_navigation("Le menu principal n’a pas pu être ouvert. Réessayez.")


func _begin_navigation() -> bool:
	if _navigation_pending:
		return false
	_navigation_pending = true
	new_attempt_button.disabled = true
	menu_button.disabled = true
	navigation_feedback.hide()
	return true


func _recover_navigation(message: String) -> void:
	_navigation_pending = false
	new_attempt_button.disabled = false
	menu_button.disabled = false
	navigation_feedback.text = message
	navigation_feedback.show()
	_focus_primary_action.call_deferred()


func _focus_primary_action() -> void:
	if _is_catabase and new_attempt_button.visible and not new_attempt_button.disabled:
		new_attempt_button.grab_focus()
	elif not menu_button.disabled:
		menu_button.grab_focus()


func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.y < 820.0
	var outer_margin := 18 if compact else 28
	var panel_height := clampf(
		viewport_size.y - float(outer_margin * 2),
		600.0,
		760.0,
	)
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - float(outer_margin * 2), 760.0, 1040.0),
		panel_height,
	)
	for side in ["left", "right"]:
		main_margin.add_theme_constant_override("margin_%s" % side, 24 if compact else 42)
	for side in ["top", "bottom"]:
		main_margin.add_theme_constant_override("margin_%s" % side, 18 if compact else 28)
	content.add_theme_constant_override("separation", 7 if compact else 11)
	crest.custom_minimum_size.y = 68.0 if compact else 92.0
	result_label.add_theme_font_size_override("font_size", 38 if compact else 48)
	location_panel.custom_minimum_size.y = 66.0 if compact else 78.0
	stats.custom_minimum_size.y = 72.0 if compact else 88.0
	narrative_panel.custom_minimum_size.y = 78.0 if compact else 96.0
	new_attempt_button.custom_minimum_size.y = 50.0 if compact else 56.0
	menu_button.custom_minimum_size.y = 50.0 if compact else 56.0


func _play_entry_motion() -> void:
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	panel.modulate = Color.WHITE
	if GameManager.is_reduced_motion_enabled():
		return
	panel.modulate.a = 0.0
	_entry_tween = create_tween()
	_entry_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_entry_tween.tween_property(panel, "modulate:a", 1.0, 0.24)


func _on_reduced_motion_changed(enabled: bool) -> void:
	CATABASE_ART.bind_button_motion(new_attempt_button, not enabled and _is_catabase)
	CATABASE_ART.bind_button_motion(menu_button, not enabled and _is_catabase)
	if not enabled:
		return
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	panel.modulate = Color.WHITE


func _reset_button_art(button: Button) -> void:
	button.icon = null
	button.expand_icon = false
	button.remove_theme_constant_override("icon_max_width")
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.remove_theme_stylebox_override(state)
