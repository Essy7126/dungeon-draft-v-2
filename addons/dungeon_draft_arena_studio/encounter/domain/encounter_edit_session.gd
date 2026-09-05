@tool
class_name EncounterEditSession
extends RefCounted

const RECOVERY_ROOT := "user://dungeon_draft_studio/encounter_studio/recovery"

## Point d'injection des tests et des environnements isolés. La production
## conserve RECOVERY_ROOT ; aucune suite ne doit partager cette autorité.
var recovery_root := RECOVERY_ROOT
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
var opening_fingerprint := ""
var saved_fingerprint := ""

## --- Mode brouillon de salle ------------------------------------------------
## Dans ce mode, l'autorité éditée n'est pas une RunData canonique mais le
## brouillon de salle de Terrain (une ArenaDefinition, qui hérite de RoomData).
## `working_run` n'est alors qu'un porteur en mémoire — voir RoomDraftAuthority.
## Aucune écriture canonique n'est possible tant que ce mode est actif.
var room_draft_mode := false
var draft_room: RoomData = null
var context_run: RunData = null
var context_run_path := ""
## Copie profonde de la moitié Rencontres à l'ouverture puis au dernier
## brouillon confirmé. DISCARD restaure ce point sans relire de fichier.
var _draft_opening_room: RoomData = null
var _draft_opening_to_canonical := {}
var _runtime_room: RoomData = null
var _runtime_room_fingerprint := ""


## Ouvre le brouillon de salle courant. `draft` est **l'instance même** éditée
## par Terrain : les deux domaines écrivent dans une seule autorité, sans
## synchronisation implicite au changement d'onglet. `context` n'est lu que pour
## ses règles de partie et n'est jamais modifié.
func open_room_draft(
		draft: RoomData,
		context: RunData,
		context_path := "",
		gameplay_mapping := {}
	) -> bool:
	if draft == null:
		return false
	var carrier := RoomDraftAuthority.build_context_run(draft, context)
	if carrier == null:
		return false
	room_draft_mode = true
	draft_room = draft
	context_run = context
	context_run_path = context_path if not context_path.is_empty() else (
		context.resource_path if context != null else ""
	)
	source_run = null
	source_run_path = ""
	working_run = carrier
	source_to_work = (gameplay_mapping.get("source_to_work", {}) as Dictionary).duplicate()
	work_to_source = (gameplay_mapping.get("work_to_source", {}) as Dictionary).duplicate()
	selected_room_index = 0
	selected_wave_index = 0
	dirty_resources.clear()
	new_resource_paths.clear()
	shared_edit_acknowledged.clear()
	validation_messages.clear()
	_capture_sources()
	_capture_draft_checkpoint()
	_capture_opening_fingerprint()
	return true


func _capture_draft_checkpoint() -> void:
	_draft_opening_room = RoomData.new()
	var opening := RoomDraftAuthority.isolate_gameplay_into(_draft_opening_room, draft_room)
	_draft_opening_to_canonical.clear()
	var opening_to_draft := opening.get("work_to_source", {}) as Dictionary
	for opening_resource in opening_to_draft:
		var draft_resource: Variant = opening_to_draft[opening_resource]
		if work_to_source.has(draft_resource):
			_draft_opening_to_canonical[opening_resource] = work_to_source[draft_resource]


func close_room_draft() -> void:
	room_draft_mode = false
	draft_room = null
	context_run = null
	context_run_path = ""
	_draft_opening_room = null
	_draft_opening_to_canonical.clear()


func open(run: RunData, run_path := "") -> bool:
	if run == null:
		return false
	var copied := EncounterCopyService.copy_run(run)
	if copied.is_empty():
		return false
	close_room_draft()
	source_run = run
	working_run = copied["run"]
	source_to_work = copied["source_to_work"]
	work_to_source = copied["work_to_source"]
	_coalesce_external_encounters()
	source_run_path = run_path if not run_path.is_empty() else run.resource_path
	selected_room_index = 0
	selected_wave_index = 0
	dirty_resources.clear()
	new_resource_paths.clear()
	shared_edit_acknowledged.clear()
	validation_messages.clear()
	_capture_sources()
	_capture_opening_fingerprint()
	return true


## IGNORE_DEEP peut charger plusieurs instances d'un même fichier externe.
## Elles désignent néanmoins une seule rencontre canonique. Conserver ce
## partage dans la copie sans fusionner les rencontres embarquées sans chemin.
func _coalesce_external_encounters() -> void:
	var by_path := {}
	var replacements := {}
	for source in source_to_work.keys():
		if not source is EncounterDefinition or source.resource_path.is_empty() \
				or "::" in source.resource_path:
			continue
		var work: Resource = source_to_work[source]
		if by_path.has(source.resource_path):
			replacements[work] = by_path[source.resource_path]
			source_to_work[source] = by_path[source.resource_path]
			work_to_source.erase(work)
		else:
			by_path[source.resource_path] = work
	for room in working_run.rooms:
		if room == null:
			continue
		room.encounter_definition = replacements.get(room.encounter_definition, room.encounter_definition)
		for wave in room.waves:
			if wave != null:
				wave.encounter_definition = replacements.get(wave.encounter_definition, wave.encounter_definition)


func discard() -> bool:
	if room_draft_mode:
		# Le brouillon reste l'autorité : on rétablit sa moitié Rencontres telle
		# qu'elle était à l'ouverture, sans jamais recharger de fichier canonique.
		if draft_room == null or _draft_opening_room == null:
			return false
		var restored := RoomDraftAuthority.isolate_gameplay_into(
			draft_room, _draft_opening_room
		)
		source_to_work.clear()
		work_to_source.clear()
		var restored_to_opening := restored.get("work_to_source", {}) as Dictionary
		for restored_resource in restored_to_opening:
			var opening_resource: Variant = restored_to_opening[restored_resource]
			if _draft_opening_to_canonical.has(opening_resource):
				var canonical: Variant = _draft_opening_to_canonical[opening_resource]
				source_to_work[canonical] = restored_resource
				work_to_source[restored_resource] = canonical
		dirty_resources.clear()
		new_resource_paths.clear()
		shared_edit_acknowledged.clear()
		validation_messages.clear()
		selected_wave_index = 0
		select(0, 0)
		_capture_sources()
		saved_fingerprint = document_fingerprint()
		return true
	return open(source_run, source_run_path) if source_run != null else false


func restore_recovery(
		recovered_run: RunData,
		canonical_run: RunData,
		canonical_path: String,
		manifest: Dictionary
	) -> bool:
	if recovered_run == null or canonical_run == null:
		return false
	var by_path := {}
	var canonical_copy := EncounterCopyService.copy_run(canonical_run)
	for source in canonical_copy.get("source_to_work", {}):
		if source != null and not source.resource_path.is_empty():
			by_path[source.resource_path] = source
	var room_sources: Array = manifest.get("room_sources", [])
	var encounter_sources: Dictionary = manifest.get("encounter_sources", {})
	for path in room_sources + encounter_sources.values():
		if not str(path).is_empty() and not by_path.has(path):
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
	for room_index in range(recovered_run.rooms.size()):
		var source_room: RoomData = by_path.get(room_sources[room_index]) \
			if room_index < room_sources.size() else (
				canonical_run.rooms[room_index] if room_index < canonical_run.rooms.size() else null)
		var work_room := recovered_run.rooms[room_index]
		if work_room == null:
			continue
		if source_room != null:
			source_to_work[source_room] = work_room
			work_to_source[work_room] = source_room
		var source_encounter: EncounterDefinition = by_path.get(encounter_sources.get(_usage_key(room_index, -1), "")) \
			if manifest.has("encounter_sources") else (source_room.encounter_definition if source_room != null else null)
		_restore_encounter_mapping(
			source_encounter, work_room.encounter_definition,
			room_index, -1, new_usage_paths
		)
		for wave_index in range(work_room.waves.size()):
			var source_wave: RoomWaveData = source_room.waves[wave_index] \
				if source_room != null and wave_index < source_room.waves.size() else null
			var work_wave := work_room.waves[wave_index]
			if work_wave == null:
				continue
			if source_wave != null:
				source_to_work[source_wave] = work_wave
				work_to_source[work_wave] = source_wave
			source_encounter = by_path.get(encounter_sources.get(_usage_key(room_index, wave_index), "")) \
				if manifest.has("encounter_sources") else (source_wave.encounter_definition if source_wave != null else null)
			_restore_encounter_mapping(
				source_encounter, work_wave.encounter_definition,
				room_index, wave_index, new_usage_paths
			)
	# Les nouvelles vagues n'ont pas d'équivalent canonique à parcourir.
	# Réappliquer leurs destinations depuis les usages du manifeste vérifié.
	for descriptor_value in manifest.get("new_encounters", []):
		var descriptor := descriptor_value as Dictionary
		for usage_value in descriptor.get("usages", []):
			var usage := usage_value as Dictionary
			var encounter := _encounter_at_usage(int(usage.room), int(usage.wave))
			if encounter != null:
				new_resource_paths[encounter] = str(descriptor.path)
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
		# JSON représente les nombres en flottants ; l'horodatage disque est
		# entier. Comparer le même type sans masquer un vrai conflit externe.
		for path in source_fingerprints:
			var fingerprint: Dictionary = source_fingerprints[path]
			if fingerprint.has("modified"):
				fingerprint["modified"] = int(fingerprint.modified)
	return true


func is_dirty() -> bool:
	return working_run != null and document_fingerprint() != saved_fingerprint


## Numérotation par parcours du graphe : deux copies indépendantes ont la même
## empreinte, mais partager une rencontre et en dupliquer le contenu diffèrent.
## Les identités mémoire servent seulement à reconnaître les arêtes du graphe,
## jamais à produire la valeur sérialisée.
func document_fingerprint() -> String:
	var root: Variant = RoomDraftAuthority.gameplay_state(draft_room) \
		if room_draft_mode else working_run
	return JSON.stringify(_document_value(root, {})).sha256_text()


func _document_value(value: Variant, seen: Dictionary) -> Variant:
	if value is Resource:
		var resource := value as Resource
		var editable := resource is RunData or resource is RoomData \
			or resource is RoomWaveData or resource is EncounterDefinition
		if not editable and not resource.resource_path.is_empty() \
				and not "::" in resource.resource_path:
			return {"external": resource.resource_path}
		if seen.has(resource):
			return {"ref": seen[resource]}
		var ordinal := seen.size()
		seen[resource] = ordinal
		var fields := {}
		var names := RoomIntegrationFieldPolicy.stored_property_names(resource)
		names.sort()
		for property in names:
			if property in [&"resource_name", &"resource_local_to_scene", &"resource_scene_unique_id"]:
				continue
			fields[str(property)] = _document_value(resource.get(property), seen)
		return {"id": ordinal, "fields": fields,
			"publication_path": str(new_resource_paths.get(resource, ""))}
	if value is Dictionary:
		var entries := []
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return var_to_str(a) < var_to_str(b))
		for key in keys:
			entries.append([_document_value(key, seen), _document_value(value[key], seen)])
		return {"dictionary": entries}
	if value is Array:
		var entries := []
		for entry in value:
			entries.append(_document_value(entry, seen))
		return entries
	return var_to_str(value)


func _capture_opening_fingerprint() -> void:
	opening_fingerprint = document_fingerprint()
	saved_fingerprint = opening_fingerprint


## Un brouillon confirmé devient le point propre sans oublier les fichiers
## restant à publier ni rafraîchir les empreintes des sources canoniques.
func confirm_draft_saved() -> void:
	saved_fingerprint = document_fingerprint()
	if room_draft_mode:
		_capture_draft_checkpoint()


func select(room_index: int, wave_index: int = 0) -> bool:
	if working_run == null or room_index < 0 or room_index >= working_run.rooms.size():
		return false
	selected_room_index = room_index
	var room := current_room()
	selected_wave_index = clampi(wave_index, 0, maxi(0, room.get_wave_count() - 1))
	return true


## Salle telle que les services runtime doivent la lire : grille, visuel et
## scène de combat reconstruits. Hors brouillon, c'est la salle elle-même.
## Cette lecture ne mute jamais l'autorité.
func runtime_room() -> RoomData:
	if not room_draft_mode or draft_room == null:
		return current_room()
	var fingerprint := RoomDraftAuthority.fingerprint(draft_room)
	if _runtime_room == null or _runtime_room_fingerprint != fingerprint:
		_runtime_room = RoomDraftAuthority.runtime_projection(draft_room)
		_runtime_room_fingerprint = fingerprint
	return _runtime_room


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
		var owner := _embedded_progression_owner(resource)
		if owner != null:
			dirty_resources[owner] = true


func mark_clean() -> void:
	dirty_resources.clear()
	new_resource_paths.clear()
	shared_edit_acknowledged.clear()
	_capture_sources()
	saved_fingerprint = document_fingerprint()


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


func _embedded_progression_owner(resource: Resource) -> EncounterDefinition:
	if working_run == null or resource == null:
		return null
	for room in working_run.rooms:
		if room == null:
			continue
		var encounters: Array[EncounterDefinition] = [room.encounter_definition]
		for wave in room.waves:
			if wave != null:
				encounters.append(wave.encounter_definition)
		for encounter in encounters:
			if encounter != null and encounter.glory_challenge == resource:
				return encounter
	return null
