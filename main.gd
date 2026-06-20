# main.gd — Point d'entrée temporaire. Lance un run directement.
extends Node

func _ready() -> void:
	GameManager.start_run()
