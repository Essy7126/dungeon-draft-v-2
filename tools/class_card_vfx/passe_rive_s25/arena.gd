extends "res://tools/class_card_vfx/passe_rive_assignments.gd"
var capture_prefix := "base_"


func _exercise() -> void:
	var automated := capture_mode
	capture_mode = false
	current_id = "g04"
	await super._exercise()
	get_window().title = "Passe-Rive — Ramener au front · crochet spectral"
	selector.select(CASES.find("g04"))
	label.text = "RAMENER AU FRONT\nCrochet spectral · traction du buste\n1 PA · attire d’une case"
	record_card = "g04"
	capture_mode = automated
	print("PASSE_RIVE_S25_READY")
	if automated:
		await _play_current("g04")
		capture_prefix = "upgraded_"
		record_card = ""
		session.cards.upgraded_ids.append("g04")
		await _play_current("g04")
		_finish()


func _capture(id: String) -> void:
	await super._capture(capture_prefix + id)
