extends "res://addons/dungeon_draft_arena_studio/encounter/test/encounter_workspace_g6.gd"

## Runner de clôture : réutilise la suite graphique G6 complète, ajoute les
## événements clavier réels et écrit toutes ses preuves dans le dossier dédié.


func _ready() -> void:
	output_root = "res://artifacts/encounter_g6_closure"
	root = get_tree().root
	call_deferred("_run")
