extends Node

@export var debug_run: RunData=preload("res://data/runs/mountain_pass_blockout_debug_run.tres")

func _ready() -> void:
	if debug_run==null:push_error("Run debug absent.");return
	if not GameManager._prepare_preconfigured_run(debug_run,GameManager.PRODUCTION_HERO_DATA_PATHS):return
	GameManager.current_room_index=0
	GameManager.start_next_battle()
