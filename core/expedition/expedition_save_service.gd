class_name ExpeditionSaveService
extends RefCounted
## Boundary saves; an interrupted fight restarts at its committed entry state.

const SAVE_PATH := "user://catabase_route_v2.json"


static func write_snapshot(snapshot: Dictionary, path: String = SAVE_PATH) -> bool:
	if snapshot.is_empty():
		return false
	var payload := JSON.stringify(snapshot)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"payload": payload, "sha256": payload.sha256_text()}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	# Never remove the previous checkpoint before its replacement is complete.
	if read_snapshot(path + ".tmp").is_empty():
		return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK


static func remove_snapshot(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return not DirAccess.dir_exists_absolute(path)
	return DirAccess.remove_absolute(path) == OK


static func fingerprint(path: String = SAVE_PATH) -> String:
	if not FileAccess.file_exists(path):
		return "absent"
	var digest := FileAccess.get_sha256(path)
	# An unreadable existing file must still require replacement confirmation.
	return digest if not digest.is_empty() else "unreadable"


static func read_snapshot(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2_000_000:
		return {}
	var envelope: Variant = JSON.parse_string(file.get_as_text())
	if not envelope is Dictionary or not envelope.get("payload") is String:
		return {}
	if envelope.get("sha256") != str(envelope.payload).sha256_text():
		return {}
	var parsed: Variant = JSON.parse_string(envelope.payload)
	return parsed if parsed is Dictionary else {}


## Every resolver operates on detached objects; failed restore cannot harm a run.
static func prepare(snapshot: Dictionary) -> Dictionary:
	if int(snapshot.get("version", 0)) != 2 or snapshot.get("mode") != "catabase_route":
		return {}
	var variants: Variant = snapshot.get("hero_visual_variants", {})
	if not variants is Dictionary or not RunHeroVisualVariants.validation_errors(variants).is_empty():
		return {}
	for key in ["session", "inventory", "equipment", "progression"]:
		if not snapshot.get(key) is Dictionary:
			return {}
	var route := ExpeditionRouteState.new()
	if not snapshot.session.get("route") is Dictionary or not route.restore_snapshot(snapshot.session.route) or route.phase == "complete":
		return {}
	var run_data := ExpeditionRunFactory.create(route.seed, variants)
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run_data, false)
	if not resolution.is_valid() or resolution.heroes.size() != 1:
		return {}
	var data: UnitData = resolution.heroes[0]
	var state := CharacterRunState.new()
	if not state.initialize(Unit.from_data(data), data, 4, RunContentCatalogService.progression_profile_for(run_data, &"achilles")):
		state.dispose()
		return {}
	var inventory := RunInventory.new()
	var catalog: ItemCatalog = run_data.economy_profile.item_catalog
	if not inventory.initialize(catalog, 24) or not inventory.restore_snapshot(snapshot.inventory):
		state.dispose()
		return {}
	if not state.equipment_loadout.restore_snapshot(snapshot.equipment, catalog):
		state.dispose()
		return {}
	var seen := {}
	for instance in inventory.get_slots() + state.equipment_loadout.get_equipped_items():
		if instance == null:
			continue
		if seen.has(instance.instance_id):
			state.dispose()
			return {}
		seen[instance.instance_id] = true
	var equipment := EquipmentService.new()
	if not equipment.initialize(catalog) or not equipment.rebuild_state(state):
		state.dispose()
		return {}
	# HP includes expedition modifiers, restored after its build has been rebuilt.
	var progression: Dictionary = snapshot.progression.duplicate(true)
	if not progression.get("champion_progression") is Dictionary:
		state.dispose()
		return {}
	progression.champion_progression.current_hp = 0
	if not state.restore_progression_snapshot(progression):
		state.dispose()
		return {}
	var session := ExpeditionSession.new()
	session.initialize(state, route.seed)
	if not session.restore_snapshot(snapshot.session):
		state.dispose()
		return {}
	if not session.reward_item_id.is_empty():
		var item := catalog.get_definition(StringName(session.reward_item_id))
		if item == null or not item.is_equippable() or not item.is_compatible_with(&"achilles"):
			state.dispose()
			return {}
	var saved_hp := int(snapshot.get("current_hp", -1))
	if saved_hp <= 0 or saved_hp > state.unit.max_hp.get_int():
		state.dispose()
		return {}
	state.unit.current_hp = saved_hp
	state.unit.is_alive = true
	state.champion_progression.current_hp = saved_hp
	return {"run_data": run_data, "state": state, "inventory": inventory, "session": session}
