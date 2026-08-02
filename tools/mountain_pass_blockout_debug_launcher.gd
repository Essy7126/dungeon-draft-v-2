extends Node

## Scene de lancement direct reservee au debug. Elle prepare le trio standard
## puis ouvre la salle sans modifier le flux de production ni project.godot.

@export var debug_run: RunData = preload(
	"res://data/runs/mountain_pass_blockout_debug_run.tres"
)


func _ready() -> void:
	if debug_run == null:
		push_error("Run de debug du blockout introuvable.")
		return
	if not GameManager._prepare_preconfigured_run(
		debug_run,
		GameManager.PRODUCTION_HERO_DATA_PATHS
	):
		return
	GameManager.current_room_index = 0
	GameManager.start_next_battle()
