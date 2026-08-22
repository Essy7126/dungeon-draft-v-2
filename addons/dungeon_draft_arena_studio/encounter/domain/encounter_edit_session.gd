@tool
class_name EncounterEditSession
extends RefCounted

const RECOVERY_ROOT := "user://dungeon_draft_studio/encounter_studio/recovery"

var source_run: RunData = null
var working_run: RunData = null
var source_run_path := ""
var source_to_work: Dictionary = {}
var work_to_source: Dictionary = {}
var source_fingerprints: Dictionary = {}
var source_snapshots: Dictionary = {}
var dirty_resources: Dictionary = {}
var new_resource_paths: Dictionary = {}
var validation_messages: Array[StudioValidationMessage] = []
var selected_room_index := 0
var selected_wave_index := 0
var shared_edit_acknowledged: Dictionary = {}
var last_save_report := {}


func open(run: RunData, run_path := "") -> bool:
	if run == null:
		return false
	var copied := EncounterCopyService.copy_run(run)
	if copied.is_empty():
		return false
	source_run = run
	working_run = copied["run"]
	source_to_work = copied["source_to_work"]
	work_to_source = copied["work_to_source"]
	source_run_path = run_path if not run_path.is_empty() else run.resource_path
	selected_room_index = 0
	selected_wave_index = 0
	dirty_resources.clear()
	new_resource_paths.clear()
	shared_edit_acknowledged.clear()
	validation_messages.clear()
	_capture_sources()
	return true


func discard() -> bool:
	return open(source_run, source_run_path) if source_run != null else false


func restore_recovery(
		recovered_run: RunData,
		canonical_run: RunData,
		canonical_path: String,
		manifest: Dictionary
	) -> bool:
	if recovered_run == null or canonical_run == null \
			or recovered_run.rooms.size() != canonical_run.rooms.size():
		return false
	if not open(canonical_run, canonical_path):
		return false
	working_run = recovered_run
	source_to_work.clear()
	work_to_source.clear()
	source_to_work[canonical_run] = recovered_run
	work_to_source[recovered_run] = canonical_run
	var new_usage_paths := {}
	for descriptor_value in manifest.get("new_encounters", []):
		var descriptor := descriptor_value as Dictionary
		for usage_value in descriptor.get("usages", []):
			var usage := usage_value as Dictionary
			new_usage_paths[_usage_key(
				int(usage.get("room", -1)), int(usage.get("wave", -2))
			)] = str(descriptor.get("path", ""))
	for room_index in range(canonical_run.rooms.size()):
		var source_room := canonical_run.rooms[room_index]
		var work_room := recovered_run.rooms[room_index]
		if source_room == null or work_room == null:
			continue
		source_to_work[source_room] = work_room
		work_to_source[work_room] = source_room
		_restore_encounter_mapping(
			source_room.encounter_definition, work_room.encounter_definition,
			room_index, -1, new_usage_paths
		)
		for wave_index in range(mini(source_room.waves.size(), work_room.waves.size())):
			var source_wave := source_room.waves[wave_index]
			var work_wave := work_room.waves[wave_index]
			if source_wave == null or work_wave == null:
				continue
			source_to_work[source_wave] = work_wave
			work_to_source[work_wave] = source_wave
			_restore_encounter_mapping(
				source_wave.encounter_definition, work_wave.encounter_definition,
				room_index, wave_index, new_usage_paths
			)
	dirty_resources.clear()
	for room_index_value in manifest.get("dirty_rooms", []):
		var room_index := int(room_index_value)
		if room_index >= 0 and room_index < working_run.rooms.size():
			mark_dirty(working_run.rooms[room_index])
	for usage_value in manifest.get("dirty_encounter_usages", []):
		var usage := usage_value as Dictionary
		var encounter := _encounter_at_usage(
			int(usage.get("room", -1)), int(usage.get("wave", -2))
		)
		mark_dirty(encounter)
	if manifest.get("dirty_run", false):
		mark_dirty(working_run)
	selected_room_index = clampi(
		int(manifest.get("selected_room", 0)), 0,
		maxi(0, working_run.rooms.size() - 1)
	)
	select(selected_room_index, int(manifest.get("selected_wave", 0)))
	var recovered_fingerprints = manifest.get("source_fingerprints", {})
	if recovered_fingerprints is Dictionary:
		source_fingerprints = recovered_fingerprints.duplicate(true)
	return true


func is_dirty() -> bool:
	return not dirty_resources.is_empty() or not new_resource_paths.is_empty()


func select(room_index: int, wave_index: int = 0) -> bool:
	if working_run == null or room_index < 0 or room_index >= working_run.rooms.size():
		return false
	selected_room_index = room_index
	var room := current_room()
	selected_wave_index = clampi(wave_index, 0, maxi(0, room.get_wave_count() - 1))
	return true


func current_room() -> RoomData:
	if working_run == null or selected_room_index < 0 \
			or selected_room_index >= working_run.rooms.size():
		return null
	return working_run.rooms[selected_room_index]


func current_wave() -> RoomWaveData:
	var room := current_room()
	return room.get_wave(selected_wave_index) if room != null else null


func current_encounter() -> EncounterDefinition:
	var room := current_room()
	return room.get_encounter_for_wave(selected_wave_index) if room != null else null


func source_for(work_resource: Resource) -> Resource:
	return work_to_source.get(work_resource) as Resource


func source_encounter() -> EncounterDefinition:
	return source_for(current_encounter()) as EncounterDefinition


func room_mode(room: RoomData = null) -> StringName:
	var value := room if room != null else current_room()
	if value == null:
		return &"missing"
	if not value.waves.is_empty():
		return &"data_driven"
	if value.encounter_definition != null:
		return &"legacy_encounter"
	if not value.enemies.is_empty():
		return &"legacy_enemies"
	return &"empty"


func room_mode_label(room: RoomData = null) -> String:
	match room_mode(room):
		&"data_driven": return "Vagues configurables"
		&"legacy_encounter": return "Rencontre unique historique"
		&"legacy_enemies": return "Liste d'ennemis historique"
	return "Salle sans rencontre"


func mark_dirty(resource: Resource) -> void:
	if resource != null:
		dirty_resources[resource] = true


func mark_clean() -> void:
	dirty_resources.clear()
	new_resource_paths.clear()
	shared_edit_acknowledged.clear()
	_capture_sources()


func set_current_encounter(encounter: EncounterDefinition) -> bool:
	var room := current_room()
	if room == null or encounter == null:
		return false
	var wave := current_wave()
	if wave != null:
		wave.encounter_definition = encounter
		mark_dirty(wave)
	else:
		room.encounter_definition = encounter
	mark_dirty(room)
	return true


func duplicate_current_encounter() -> EncounterDefinition:
	var source := current_encounter()
	var room := current_room()
	if source == null or room == null:
		return null
	var copy := EncounterCopyService.copy_encounter(source)
	var path := EncounterCopyService.suggested_path(room, selected_wave_index)
	new_resource_paths[copy] = path
	set_current_encounter(copy)
	mark_dirty(copy)
	return copy


func add_wave(copy_previous := true, share_encounter := false) -> RoomWaveData:
	var room := current_room()
	if room == null:
		return null
	var wave := RoomWaveData.new()
	wave.wave_name = "Affrontement %d" % (room.waves.size() + 1)
	if copy_previous and not room.waves.is_empty():
		var previous := room.waves.back() as RoomWaveData
		wave.enemy_health_multiplier = previous.enemy_health_multiplier
		wave.enemy_attack_multiplier = previous.enemy_attack_multiplier
		wave.reward_multiplier = previous.reward_multiplier
		wave.encounter_definition = previous.encounter_definition \
			if share_encounter else EncounterCopyService.copy_encounter(
				previous.encounter_definition
			)
	elif room.encounter_definition != null:
		wave.encounter_definition = room.encounter_definition \
			if share_encounter else EncounterCopyService.copy_encounter(
				room.encounter_definition
			)
	if wave.encounter_definition == null:
		wave.encounter_definition = EncounterDefinition.new()
		wave.encounter_definition.room_index = selected_room_index + 1
	if not work_to_source.has(wave.encounter_definition):
		new_resource_paths[wave.encounter_definition] = EncounterCopyService.suggested_path(
			room, room.waves.size()
		)
	room.waves.append(wave)
	selected_wave_index = room.waves.size() - 1
	mark_dirty(room)
	mark_dirty(wave)
	return wave


func duplicate_current_wave(independent_encounter := true) -> RoomWaveData:
	var room := current_room()
	var wave := current_wave()
	if room == null or wave == null:
		return null
	var copy := EncounterCopyService.copy_wave(wave)
	copy.wave_name = "%s — copie" % wave.wave_name
	if independent_encounter:
		copy.encounter_definition = EncounterCopyService.copy_encounter(
			wave.encounter_definition
		)
		new_resource_paths[copy.encounter_definition] = EncounterCopyService.suggested_path(
			room, selected_wave_index + 1
		)
	room.waves.insert(selected_wave_index + 1, copy)
	selected_wave_index += 1
	mark_dirty(room)
	mark_dirty(copy)
	return copy


func remove_current_wave() -> bool:
	var room := current_room()
	if room == null or room.waves.is_empty() \
			or selected_wave_index >= room.waves.size():
		return false
	room.waves.remove_at(selected_wave_index)
	selected_wave_index = clampi(
		selected_wave_index, 0, maxi(0, room.waves.size() - 1)
	)
	mark_dirty(room)
	return true


func move_current_wave(offset: int) -> bool:
	var room := current_room()
	if room == null:
		return false
	var target := selected_wave_index + offset
	if selected_wave_index < 0 or selected_wave_index >= room.waves.size() \
			or target < 0 or target >= room.waves.size():
		return false
	var wave := room.waves[selected_wave_index]
	room.waves.remove_at(selected_wave_index)
	room.waves.insert(target, wave)
	selected_wave_index = target
	mark_dirty(room)
	return true


func affected_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for resource_value in dirty_resources:
		var resource := resource_value as Resource
		# Les vagues sont des sous-ressources : le fichier atomique a annoncer,
		# sauvegarder et restaurer est toujours leur RoomData proprietaire.
		if resource is RoomWaveData:
			continue
		var source := source_for(resource)
		var path := source.resource_path if source != null else str(
			new_resource_paths.get(resource, resource.resource_path)
		)
		if not path.is_empty() and not paths.has(path):
			paths.append(path)
	paths.sort()
	return paths


func conflict_report() -> Dictionary:
	var changed := PackedStringArray()
	for path in source_fingerprints:
		if _fingerprint(path) != source_fingerprints[path]:
			changed.append(path)
	return {"conflict": not changed.is_empty(), "changed_paths": changed}


func source_is_untouched() -> bool:
	for source_resource in source_snapshots:
		if source_resource is EncounterDefinition and EncounterCopyService.encounter_snapshot(
			source_resource
		) != source_snapshots[source_resource]:
			return false
	return true


func _capture_sources() -> void:
	source_fingerprints.clear()
	source_snapshots.clear()
	for source_resource_value in source_to_work:
		var source_resource := source_resource_value as Resource
		if source_resource == null:
			continue
		if source_resource is EncounterDefinition:
			source_snapshots[source_resource] = EncounterCopyService.encounter_snapshot(
				source_resource
			)
		if not source_resource.resource_path.is_empty():
			source_fingerprints[source_resource.resource_path] = _fingerprint(
				source_resource.resource_path
			)
	if not source_run_path.is_empty():
		source_fingerprints[source_run_path] = _fingerprint(source_run_path)


func _fingerprint(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"exists": false}
	return {
		"exists": true,
		"modified": FileAccess.get_modified_time(path),
		"md5": FileAccess.get_md5(path),
	}


func _restore_encounter_mapping(
		source: EncounterDefinition,
		work: EncounterDefinition,
		room_index: int,
		wave_index: int,
		new_usage_paths: Dictionary
	) -> void:
	if work == null:
		return
	var key := _usage_key(room_index, wave_index)
	if new_usage_paths.has(key):
		new_resource_paths[work] = new_usage_paths[key]
		return
	if source != null and not source_to_work.has(source):
		source_to_work[source] = work
		work_to_source[work] = source


func _encounter_at_usage(room_index: int, wave_index: int) -> EncounterDefinition:
	if working_run == null or room_index < 0 or room_index >= working_run.rooms.size():
		return null
	var room := working_run.rooms[room_index]
	if room == null:
		return null
	return room.encounter_definition if wave_index == -1 \
		else room.get_encounter_for_wave(wave_index)


func _usage_key(room_index: int, wave_index: int) -> String:
	return "%d:%d" % [room_index, wave_index]
