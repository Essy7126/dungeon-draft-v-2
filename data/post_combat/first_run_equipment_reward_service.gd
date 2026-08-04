class_name FirstRunEquipmentRewardService
extends RefCounted

const POOL_TAG: StringName = &"first_run_equipment_reward"

var _catalog: ItemCatalog = null
var _deck: Array[StringName] = []
var _eligible_ids: Array[StringName] = []
var _offered_ids: Array[StringName] = []
var _discarded_ids: Array[StringName] = []
var _options_by_report: Dictionary = {}
var _applied_report_ids: Dictionary = {}


func reset(catalog: ItemCatalog = null, run_seed: int = 0) -> bool:
	_catalog = catalog
	_deck.clear()
	_eligible_ids.clear()
	_offered_ids.clear()
	_discarded_ids.clear()
	_options_by_report.clear()
	_applied_report_ids.clear()
	if _catalog == null or not _catalog.rebuild_index():
		return false
	for definition in _catalog.get_definitions():
		if definition != null and definition.is_equippable() \
				and definition.tags.has(POOL_TAG):
			_eligible_ids.append(definition.item_id)
	_eligible_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return str(a) < str(b)
	)
	_deck = _eligible_ids.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	for index in range(_deck.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := _deck[index]
		_deck[index] = _deck[swap_index]
		_deck[swap_index] = temporary
	return _eligible_ids.size() >= 2


func build_options(
		report: CombatReport,
		character_states: Array,
		inventory: RunInventory,
		final_room: bool
	) -> Array[Dictionary]:
	if final_room or report == null or not report.finalized or not report.victory \
			or _catalog == null or inventory == null:
		return []
	if _options_by_report.has(report.report_id):
		return (_options_by_report[report.report_id] as Array).duplicate(true)
	var owned := _owned_definition_ids(character_states, inventory)
	var selected: Array[StringName] = []
	while not _deck.is_empty() and selected.size() < 2:
		var candidate: StringName = _deck.pop_front()
		if owned.has(candidate) or _offered_ids.has(candidate) \
				or selected.has(candidate):
			continue
		selected.append(candidate)
	# Fallback defensif : il ne produit jamais deux fois le meme ID. En run
	# normale, les quatorze entrees rendent cette branche inaccessible.
	if selected.size() < 2:
		for candidate in _eligible_ids:
			if selected.size() >= 2:
				break
			if selected.has(candidate) or owned.has(candidate):
				continue
			selected.append(candidate)
	var options: Array[Dictionary] = []
	for item_id in selected:
		if not _offered_ids.has(item_id):
			_offered_ids.append(item_id)
		var definition := _catalog.get_definition(item_id)
		options.append({
			"reward_id": item_id,
			"item_id": item_id,
			"definition": definition,
			"compatible_character_ids": _compatible_character_ids(
				definition,
				character_states,
			),
		})
	_options_by_report[report.report_id] = options.duplicate(true)
	return options


func apply(
		report: CombatReport,
		item_id: StringName,
		character_id: StringName,
		character_states: Array,
		inventory: RunInventory,
		equipment_service: EquipmentService
	) -> Dictionary:
	if report == null or not report.finalized or not report.victory:
		return _failure("COMBAT_REPORT_INVALID", "Rapport de victoire indisponible.")
	if _applied_report_ids.has(report.report_id):
		return _failure("REWARD_ALREADY_APPLIED", "Un équipement a déjà été attribué.")
	var options := _options_by_report.get(report.report_id, []) as Array
	if not options.any(func(option):
		return StringName((option as Dictionary).get("item_id", &"")) == item_id
	):
		return _failure("REWARD_OPTION_INVALID", "Cet équipement n'est pas proposé.")
	var definition := _catalog.get_definition(item_id) if _catalog != null else null
	var state := _find_state(character_states, character_id)
	if definition == null or state == null or state.unit == null \
			or not definition.is_compatible_with(character_id):
		return _failure("CHARACTER_INCOMPATIBLE", "Ce héros ne peut pas utiliser cet équipement.")
	if inventory == null or equipment_service == null:
		return _failure("EQUIPMENT_STATE_INVALID", "Inventaire ou équipement indisponible.")
	var added := inventory.try_add(item_id, 1)
	if not added.get("success", false):
		return added
	var instance_ids := added.get("instance_ids", []) as Array
	if instance_ids.size() != 1:
		return _failure("ITEM_INSTANCE_INVALID", "L'instance de récompense est invalide.")
	var instance_id := StringName(instance_ids[0])
	var equipped := equipment_service.equip(
		inventory,
		state,
		instance_id,
		definition.equipment_slot,
	)
	if not equipped.get("success", false):
		inventory.remove_quantity(instance_id, 1)
		return equipped
	_applied_report_ids[report.report_id] = true
	for option_value in options:
		var option := option_value as Dictionary
		var offered_id := StringName(option.get("item_id", &""))
		if offered_id != item_id and not _discarded_ids.has(offered_id):
			_discarded_ids.append(offered_id)
	return {
		"success": true,
		"report_id": report.report_id,
		"reward_id": item_id,
		"item_id": item_id,
		"instance_id": instance_id,
		"target_character_id": character_id,
		"slot": definition.equipment_slot,
		"unequipped_instance_id": equipped.get("unequipped_instance_id", &""),
	}


func has_applied(report_id: StringName) -> bool:
	return _applied_report_ids.has(report_id)


func snapshot() -> Dictionary:
	return {
		"deck": _deck.duplicate(),
		"eligible_ids": _eligible_ids.duplicate(),
		"offered_ids": _offered_ids.duplicate(),
		"discarded_ids": _discarded_ids.duplicate(),
		"applied_report_ids": _applied_report_ids.keys(),
	}


func _owned_definition_ids(
		character_states: Array,
		inventory: RunInventory
	) -> Dictionary:
	var result := {}
	for instance in inventory.get_slots():
		if instance != null:
			result[instance.definition_id] = true
	for value in character_states:
		var state := value as CharacterRunState
		if state == null or state.equipment_loadout == null:
			continue
		for instance in state.equipment_loadout.get_equipped_items():
			if instance != null:
				result[instance.definition_id] = true
	return result


func _compatible_character_ids(
		definition: ItemDefinition,
		character_states: Array
	) -> Array[StringName]:
	var result: Array[StringName] = []
	if definition == null:
		return result
	for value in character_states:
		var state := value as CharacterRunState
		if state != null and definition.is_compatible_with(state.character_id):
			result.append(state.character_id)
	return result


func _find_state(
		character_states: Array,
		character_id: StringName
	) -> CharacterRunState:
	for value in character_states:
		var state := value as CharacterRunState
		if state != null and state.character_id == character_id:
			return state
	return null


func _failure(code: String, message: String) -> Dictionary:
	return {"success": false, "error_code": code, "error": message}
