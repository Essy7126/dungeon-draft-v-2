@tool
class_name RoomDraftSaveService
extends RefCounted

## Enregistrement local d'un **brouillon de salle complet** : terrain et
## rencontres dans un seul fichier, sous `user://`. Rien n'est écrit sous
## `res://` : ni salle, ni partie, ni EncounterDefinition. La publication reste
## l'affaire exclusive de « Intégrer à la partie ».
##
## Le fichier écrit n'est pas une seconde autorité : c'est une reprise de
## travail. À la relecture, il reconstruit l'ArenaDefinition du brouillon, sa
## sélection et son état modifié.

const SCHEMA_VERSION := 1


static func draft_path(session_key: String) -> String:
	return RoomDraftAuthority.draft_path_for(session_key).trim_suffix(".tres") + ".json"


static func plan(draft_room: RoomData, session_key: String) -> Dictionary:
	if draft_room == null:
		return {"ok": false, "error": "no_room_draft"}
	var path := draft_path(session_key)
	return {
		"ok": true,
		"path": path,
		"replaces_existing": FileAccess.file_exists(path),
		"summary": "Enregistrer le brouillon complet de « %s » dans votre dossier personnel." \
			% draft_room.room_name,
		"guarantees": PackedStringArray([
			"Aucune partie n'est modifiée.",
			"Aucune rencontre n'est créée sous res://data/encounters.",
			"Vous pourrez reprendre le terrain et les affrontements plus tard.",
		]),
	}


static func save(
		draft_room: RoomData,
		session_key: String,
		state := {}
	) -> Dictionary:
	if draft_room == null:
		return {"ok": false, "error": "no_room_draft"}
	var path := draft_path(session_key)
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return {"ok": false, "error": "directory_failed", "path": path}
	var payload := {
		"_schema_version": SCHEMA_VERSION,
		"_studio_product_version": StudioVersion.PRODUCT_VERSION,
		"_saved_at": Time.get_datetime_string_from_system(true),
		"session_key": session_key,
		"terrain": (draft_room as ArenaDefinition).to_snapshot() \
			if draft_room is ArenaDefinition else {},
		"gameplay": gameplay_snapshot(draft_room),
		"state": (state as Dictionary).duplicate(true),
	}
	var temporary := absolute + ".%d.tmp" % Time.get_ticks_usec()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "open_failed", "path": path}
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(temporary))
	if written != JSON.parse_string(JSON.stringify(payload)):
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "verification_failed", "path": path}
	var existed := FileAccess.file_exists(absolute)
	var backup := temporary + ".previous"
	if existed:
		if DirAccess.copy_absolute(absolute, backup) != OK \
				or FileAccess.get_md5(absolute) != FileAccess.get_md5(backup):
			DirAccess.remove_absolute(temporary)
			return {"ok": false, "error": "backup_failed", "path": path}
		if DirAccess.remove_absolute(absolute) != OK:
			DirAccess.remove_absolute(temporary)
			return {"ok": false, "error": "replace_failed", "path": path}
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		DirAccess.remove_absolute(temporary)
		var restored := not existed or (DirAccess.copy_absolute(backup, absolute) == OK \
			and FileAccess.get_md5(backup) == FileAccess.get_md5(absolute))
		return {"ok": false, "error": "commit_failed", "path": path, "rollback_ok": restored}
	var verified: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if verified != written:
		var restored := DirAccess.copy_absolute(backup, absolute) == OK if existed \
			else DirAccess.remove_absolute(absolute) == OK
		return {"ok": false, "error": "verification_failed", "path": path, "rollback_ok": restored}
	if existed:
		DirAccess.remove_absolute(backup)
	return {"ok": true, "path": path, "summary": "Brouillon de salle enregistré : %s" % path}


static func load_draft(session_key: String) -> Dictionary:
	var path := draft_path(session_key)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "not_found", "path": path}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {"ok": false, "error": "unreadable", "path": path}
	var payload := parsed as Dictionary
	var room := ArenaDefinition.new()
	if not room.restore_snapshot(payload.get("terrain", {}) as Dictionary):
		return {"ok": false, "error": "terrain_restore_failed", "path": path}
	restore_gameplay_snapshot(room, payload.get("gameplay", {}) as Dictionary)
	return {
		"ok": true,
		"path": path,
		"room": room,
		"state": (payload.get("state", {}) as Dictionary).duplicate(true),
		"saved_at": str(payload.get("_saved_at", "")),
	}


static func has_draft(session_key: String) -> bool:
	return FileAccess.file_exists(draft_path(session_key))


static func remove(session_key: String) -> bool:
	var absolute := ProjectSettings.globalize_path(draft_path(session_key))
	if not FileAccess.file_exists(absolute):
		return true
	return DirAccess.remove_absolute(absolute) == OK


## --- Sérialisation de la moitié Rencontres ---------------------------------

static func gameplay_snapshot(room: RoomData) -> Dictionary:
	if room == null:
		return {}
	var waves: Array = []
	var identities := {}
	var root_id := _encounter_id(room.encounter_definition, identities)
	for wave in room.waves:
		if wave == null:
			continue
		waves.append({
			"encounter_id": _encounter_id(wave.encounter_definition, identities),
			"wave_name": wave.wave_name,
			"enemy_health_multiplier": wave.enemy_health_multiplier,
			"enemy_attack_multiplier": wave.enemy_attack_multiplier,
			"reward_multiplier": wave.reward_multiplier,
			"encounter": encounter_snapshot(wave.encounter_definition),
			"encounter_path": wave.encounter_definition.resource_path \
				if wave.encounter_definition != null else "",
		})
	return {
		"encounter_id": root_id,
		"encounter": encounter_snapshot(room.encounter_definition),
		"encounter_path": room.encounter_definition.resource_path \
			if room.encounter_definition != null else "",
		"waves": waves,
		"minimum_wave_count": room.minimum_wave_count,
		"maximum_wave_count": room.maximum_wave_count,
		"ultimate_reward_base_chance": room.ultimate_reward_base_chance,
		"ultimate_reward_min_gain_per_wave": room.ultimate_reward_min_gain_per_wave,
		"ultimate_reward_max_gain_per_wave": room.ultimate_reward_max_gain_per_wave,
	}


static func restore_gameplay_snapshot(room: RoomData, data: Dictionary) -> bool:
	if room == null or data.is_empty():
		return false
	var encounters := {}
	room.encounter_definition = _restore_encounter(data, encounters)
	var waves: Array[RoomWaveData] = []
	for entry_value in data.get("waves", []):
		var entry := entry_value as Dictionary
		var wave := RoomWaveData.new()
		wave.wave_name = str(entry.get("wave_name", "Affrontement"))
		wave.enemy_health_multiplier = float(entry.get("enemy_health_multiplier", 1.0))
		wave.enemy_attack_multiplier = float(entry.get("enemy_attack_multiplier", 1.0))
		wave.reward_multiplier = float(entry.get("reward_multiplier", 1.0))
		wave.encounter_definition = _restore_encounter(entry, encounters)
		waves.append(wave)
	room.waves = waves
	room.minimum_wave_count = int(data.get("minimum_wave_count", 1))
	room.maximum_wave_count = int(data.get("maximum_wave_count", 1))
	room.ultimate_reward_base_chance = int(data.get("ultimate_reward_base_chance", 10))
	room.ultimate_reward_min_gain_per_wave = int(
		data.get("ultimate_reward_min_gain_per_wave", 2)
	)
	room.ultimate_reward_max_gain_per_wave = int(
		data.get("ultimate_reward_max_gain_per_wave", 5)
	)
	return true


static func encounter_snapshot(encounter: EncounterDefinition) -> Dictionary:
	return EncounterCopyService.encounter_snapshot(encounter)


## Identité de parcours persistante : préserver le partage du brouillon sans
## jamais déduire le partage de contenus égaux ou d'identifiants mémoire.
static func _encounter_id(encounter: EncounterDefinition, identities: Dictionary) -> int:
	if encounter == null:
		return -1
	if not identities.has(encounter):
		identities[encounter] = identities.size()
	return int(identities[encounter])


static func _restore_encounter(entry: Dictionary, encounters: Dictionary) -> EncounterDefinition:
	# Les anciens brouillons sans identifiants gardent leur comportement.
	var identity := int(entry.get("encounter_id", -1))
	if identity >= 0 and encounters.has(identity):
		return encounters[identity]
	var encounter := encounter_from_snapshot(entry.get("encounter", {}) as Dictionary)
	if identity >= 0:
		encounters[identity] = encounter
	return encounter


static func encounter_from_snapshot(data: Dictionary) -> EncounterDefinition:
	if data.is_empty():
		return null
	var encounter := EncounterDefinition.new()
	encounter.room_index = int(data.get("room_index", 1))
	var units: Array[UnitData] = []
	for path_value in data.get("roster_paths", []):
		var path := str(path_value)
		var unit := ResourceLoader.load(
			path, "", ResourceLoader.CACHE_MODE_REUSE
		) as UnitData if not path.is_empty() and ResourceLoader.exists(path) else null
		if unit != null:
			units.append(unit)
	encounter.roster_units = units
	var counts := PackedInt32Array()
	for count_value in data.get("roster_counts", []):
		counts.append(int(count_value))
	encounter.roster_counts = counts
	var spawn_groups: Array[StringName] = []
	for value in data.get("allowed_spawn_groups", []):
		spawn_groups.append(StringName(value))
	encounter.allowed_spawn_groups = spawn_groups
	var formations: Array[StringName] = []
	for value in data.get("formation_profiles", []):
		formations.append(StringName(value))
	encounter.formation_profiles = formations
	encounter.living_enemy_cap = int(data.get("living_enemy_cap", 0))
	encounter.shared_normal_summon_budget = int(
		data.get("shared_normal_summon_budget", 0)
	)
	encounter.shared_chief_summon_budget = int(
		data.get("shared_chief_summon_budget", 0)
	)
	var disabled: Array[StringName] = []
	for value in data.get("disabled_ability_ids", []):
		disabled.append(StringName(value))
	encounter.disabled_ability_ids = disabled
	encounter.maximum_formation_attempts = int(
		data.get("maximum_formation_attempts", 7)
	)
	encounter.minimum_path_distance_by_role = _string_name_keys(
		data.get("minimum_path_distance_by_role", {})
	)
	encounter.maximum_path_distance_by_role = _string_name_keys(
		data.get("maximum_path_distance_by_role", {})
	)
	encounter.summon_free_neighbor_requirement = int(
		data.get("summon_free_neighbor_requirement", 1)
	)
	var forbidden: Array[Vector2i] = []
	for value in data.get("forbidden_initial_spawn_cells", []):
		if value is Array and (value as Array).size() >= 2:
			forbidden.append(Vector2i(int(value[0]), int(value[1])))
	encounter.forbidden_initial_spawn_cells = forbidden
	return encounter


static func _string_name_keys(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for key in value as Dictionary:
			result[StringName(key)] = int((value as Dictionary)[key])
	return result
