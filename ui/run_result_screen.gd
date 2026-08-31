extends Control

@onready var result_label: Label = $Background/Center/Panel/Content/Result
@onready var register_label: Label = $Background/Center/Panel/Content/Register
@onready var run_name_label: Label = $Background/Center/Panel/Content/RunName
@onready var progression_label: Label = $Background/Center/Panel/Content/Progression
@onready var seed_label: Label = $Background/Center/Panel/Content/Seed
@onready var epitaph_label: Label = $Background/Center/Panel/Content/EpitaphPanel/Epitaph
@onready var return_button: Button = $Background/Center/Panel/Content/ReturnButton

var _is_catabase := false


func _ready() -> void:
	_apply_result(GameManager.get_last_run_result())
	return_button.pressed.connect(_on_return_pressed)


func _apply_result(result: Dictionary) -> void:
	var victory := bool(result.get("victory", false))
	result_label.text = "Victoire" if victory else "Défaite"
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
