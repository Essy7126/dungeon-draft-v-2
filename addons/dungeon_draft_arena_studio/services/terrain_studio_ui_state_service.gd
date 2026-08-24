@tool
class_name TerrainStudioUiStateService
extends RefCounted

## Etat d'interface du domaine Terrain : mode guide, etape courante, panneaux,
## guidage et terrains recemment ouverts. Il est persiste sous user:// et reste
## strictement separe des Resources metier : aucune ArenaDefinition, aucun
## RunData et aucun chemin de production n'y est serialise.

const STATE_PATH := "user://dungeon_draft_studio/ui_state/terrain_studio.json"
const SCHEMA_VERSION := 1
const MAX_RECENTS := 8

static var _cache := {}


static func default_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"guided": true,
		"step": TerrainWorkflowService.Step.START,
		"guidance_visible": true,
		"drawer_visible": false,
		"inspector_visible": true,
		"home_seen": false,
		"preview_view": 0,
		"recents": [],
	}


static func load_state() -> Dictionary:
	if not _cache.is_empty():
		return _cache.duplicate(true)
	var state := default_state()
	if FileAccess.file_exists(STATE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
		if parsed is Dictionary \
				and int((parsed as Dictionary).get("schema_version", 0)) == SCHEMA_VERSION:
			for key in state:
				if (parsed as Dictionary).has(key):
					state[key] = (parsed as Dictionary)[key]
	_cache = state.duplicate(true)
	return state


static func save_state(state: Dictionary) -> bool:
	var payload := state.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	_cache = payload.duplicate(true)
	var absolute := ProjectSettings.globalize_path(STATE_PATH)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	return DirAccess.rename_absolute(temporary, absolute) == OK


static func set_value(key: String, value: Variant) -> void:
	var state := load_state()
	state[key] = value
	save_state(state)


static func get_value(key: String, fallback: Variant = null) -> Variant:
	var state := load_state()
	return state.get(key, fallback)


## Un recent decrit uniquement ce que l'accueil doit afficher : un libelle, une
## cle de session et un chemin de ressource facultatif.
static func remember_recent(label: String, session_key: String, path := "") -> void:
	if label.strip_edges().is_empty() and session_key.strip_edges().is_empty():
		return
	var state := load_state()
	var recents: Array = state.get("recents", [])
	# Un même terrain rouvert dans une nouvelle session ne doit apparaître
	# qu'une fois : la liste est dédoublonnée par chemin, par clé de session et
	# par libellé visible.
	recents = recents.filter(func(value):
		var entry := value as Dictionary
		if str(entry.get("session_key", "")) == session_key:
			return false
		if not path.is_empty() and str(entry.get("path", "")) == path:
			return false
		return str(entry.get("label", "")) != label
	)
	recents.push_front({
		"label": label,
		"session_key": session_key,
		"path": path,
		"opened_at": Time.get_datetime_string_from_system(true),
	})
	while recents.size() > MAX_RECENTS:
		recents.pop_back()
	state["recents"] = recents
	save_state(state)


static func recents() -> Array:
	var stored: Array = load_state().get("recents", [])
	var result: Array = []
	for value in stored:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result


static func clear_cache() -> void:
	_cache = {}
