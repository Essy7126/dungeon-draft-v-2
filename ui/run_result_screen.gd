extends Control

@onready var result_label: Label = $Background/Center/Panel/Content/Result
@onready var panel: PanelContainer = %Panel
@onready var crest: TextureRect = $Background/Center/Panel/Content/Crest
@onready var register_label: Label = $Background/Center/Panel/Content/Register
@onready var run_name_label: Label = $Background/Center/Panel/Content/RunName
@onready var progression_label: Label = $Background/Center/Panel/Content/Progression
@onready var seed_label: Label = $Background/Center/Panel/Content/Seed
@onready var epitaph_label: Label = $Background/Center/Panel/Content/EpitaphPanel/Epitaph
@onready var return_button: Button = $Background/Center/Panel/Content/ReturnButton

var _is_catabase := false


func _ready() -> void:
	PremiumUI.apply(self)
	_apply_panel_margins()
	_apply_result(GameManager.get_last_run_result())
	return_button.pressed.connect(_on_return_pressed)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	return_button.grab_focus.call_deferred()


func _apply_result(result: Dictionary) -> void:
	var victory := bool(result.get("victory", false))
	result_label.text = "Victoire" if victory else "Défaite"
	result_label.modulate = (
		PremiumUI.SKIN.text_primary
		if victory else Color(0.92, 0.42, 0.31, 1.0)
	)
	crest.modulate = Color.WHITE if victory else Color(0.78, 0.42, 0.36, 0.78)
	var run_name := str(result.get("run_name", "")).strip_edges()
	var is_catabase := bool(result.get("is_catabase", false))
	_is_catabase = is_catabase
	register_label.text = (
		"REGISTRE DE L’ARCHIVISTE · CATABASE"
		if is_catabase else "REGISTRE DE L’ARCHIVISTE"
	)
	var featured_hero_name := str(
		result.get("featured_hero_name", "")
	).strip_edges()
	run_name_label.text = (
		(
			"Catabase — %s" % featured_hero_name
			if featured_hero_name != "" else "Catabase"
		)
		if is_catabase else (
			"Run : %s" % run_name if run_name != "" else "Run terminé"
		)
	)
	var rooms_cleared := maxi(0, int(result.get("rooms_cleared", 0)))
	var room_total := maxi(0, int(result.get("room_total", 0)))
	var reached_room := maxi(0, int(result.get("reached_room_number", 0)))
	var reached_name := str(result.get("reached_room_name", "")).strip_edges()
	var reached_text := "Salle atteinte : aucune"
	if reached_room > 0:
		reached_text = "Salle atteinte : %d/%d" % [reached_room, room_total]
		if reached_name != "":
			reached_text += " — %s" % reached_name
	progression_label.text = "Salles franchies : %d/%d\n%s" % [
		rooms_cleared,
		room_total,
		reached_text,
	]
	var seed_available := bool(result.get("seed_available", false))
	seed_label.visible = seed_available
	seed_label.text = "Graine du destin : %d" % int(result.get("seed", 0))
	var epitaph := str(result.get("epitaph", "")).strip_edges()
	epitaph_label.text = (
		epitaph
		if epitaph != ""
		else "L’Archiviste ne dispose d’aucun fait sur cette tentative."
	)
	return_button.text = (
		"Retourner auprès de l’Archiviste"
		if is_catabase else "Retour au menu principal"
	)


func _on_return_pressed() -> void:
	if _is_catabase:
		GameManager.return_to_hub()
	else:
		GameManager.return_to_title()


func _apply_panel_margins() -> void:
	var source := PremiumUI.get_theme().get_stylebox(&"panel", &"PremiumScreen")
	if source == null:
		return
	var style := source.duplicate() as StyleBox
	style.content_margin_left = 42.0
	style.content_margin_top = 28.0
	style.content_margin_right = 42.0
	style.content_margin_bottom = 30.0
	panel.add_theme_stylebox_override(&"panel", style)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 48.0, 620.0, 760.0),
		clampf(viewport_size.y - 40.0, 600.0, 680.0),
	)
