extends Control

@onready var result_label: Label = $Background/Center/Panel/Content/Result
@onready var run_name_label: Label = $Background/Center/Panel/Content/RunName
@onready var return_button: Button = $Background/Center/Panel/Content/ReturnButton


func _ready() -> void:
	_apply_result(GameManager.get_last_run_result())
	return_button.pressed.connect(GameManager.return_to_title)


func _apply_result(result: Dictionary) -> void:
	var victory := bool(result.get("victory", false))
	result_label.text = "Victoire" if victory else "Défaite"
	var run_name := str(result.get("run_name", "")).strip_edges()
	run_name_label.text = "Run : %s" % run_name if run_name != "" else "Run terminé"
