@tool
class_name StudioWorkspace
extends DungeonDraftStudioMain

## Contenu actif unique de Dungeon Draft Studio. Les hosts integre et natif
## ne construisent jamais de second workspace : ils reparentent cette instance.

var workspace_instance_id := ""


func _init() -> void:
	workspace_instance_id = "%s-%s" % [Time.get_ticks_usec(), get_instance_id()]


func _ready() -> void:
	super()
	if arena_studio != null:
		arena_studio.set_shell_toolbar_visible(false)


func active_session_identity() -> Dictionary:
	# EncounterEditSession identifie sa source par `source_run_path` : lire
	# `source_path` levait une erreur des qu'une session d'encounter existait.
	return {
		"workspace_instance_id": workspace_instance_id,
		"arena_session": arena_studio.edit_session.session_key \
			if arena_studio != null and arena_studio.edit_session != null else "",
		"encounter_session": encounter_studio.session.source_run_path \
			if encounter_studio != null and encounter_studio.session != null else "",
	}
