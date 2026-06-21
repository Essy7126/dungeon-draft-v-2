# main.gd — Point d'entrée. Lance un run selon le RunData assigné.
extends Node

@export var run_data: RunData

func _ready() -> void:
	GameManager.start_run(run_data)
	DebugLogger.info(DebugLogger.LogCategory.SYSTEM, "Run démarré !")
