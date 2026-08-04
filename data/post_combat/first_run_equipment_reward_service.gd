class_name FirstRunEquipmentRewardService
extends RefCounted

const POOL_TAG: StringName = &"first_run_equipment_reward"
const SNAPSHOT_VERSION := 1

var _catalog: ItemCatalog = null
var _deck: Array[StringName] = []
var _eligible_ids: Array[StringName] = []
var _offered_ids: Array[StringName] = []
var _discarded_ids: Array[StringName] = []
var _options_by_report: Dictionary = {}
var _applied_report_ids: Dictionary = {}
var _selected_by_report: Dictionary = {}


func reset(catalog: ItemCatalog = null, run_seed: int = 0) -> bool:
	_catalog = catalog
	_deck.clear()
	_eligible_ids.clear()
	_offered_ids.clear()
	_discarded_ids.clear()
	_options_by_report.clear()
	_applied_report_ids.clear()
	_selected_by_report.clear()
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
	var available: Array[StringName] = []
	for candidate in _deck:
		var definition := _catalog.get_definition(candidate)
		if owned.has(candidate) or _offered_ids.has(candidate) \
				or definition == null \
				or _compatible_character_ids(definition, character_states).is_empty():
			continue
		available.append(candidate)
	var selected: Array[StringName] = []
	if not available.is_empty():
		selected.append(available[0])
	if available.size() > 1:
		var first_definition := _catalog.get_definition(selected[0])
		var second_id := available[1]
		for candidate in available.slice(1):
			var candidate_definition := _catalog.get_definition(candidate)
			if not _same_audience_and_slot(
					first_definition,
					candidate_definition,
					character_states,
				):
				second_id = candidate
				break
		selected.append(second_id)
	for item_id in selected:
		_deck.erase(item_id)
	# Fallback defensif : il ne produit jamais deux fois le meme ID et filtre
	# tout objet inutilisable par le trio.
	if selected.size() < 2:
		for candidate in _eligible_ids:
			if selected.size() >= 2:
				break
			var definition := _catalog.get_definition(candidate)
			if selected.has(candidate) or owned.has(candidate) \
					or definition == null \
					or _compatible_character_ids(definition, character_states).is_empty():
				continue
			selected.append(candidate)
	if selected.size() != 2:
		return []
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
		_equipment_service: EquipmentService = null
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
	if character_id == &"":
		var selected_option := options.filter(func(option):
			return StringName((option as Dictionary).get("item_id", &"")) == item_id
		)[0] as Dictionary
		var compatible_ids := selected_option.get("compatible_character_ids", []) as Array
		if not compatible_ids.is_empty():
			character_id = StringName(compatible_ids[0])
	var state := _find_state(character_states, character_id)
	if definition == null or state == null or state.unit == null \
			or not definition.is_compatible_with(character_id):
		return _failure("CHARACTER_INCOMPATIBLE", "Ce héros ne peut pas utiliser cet équipement.")
	if inventory == null:
		return _failure("EQUIPMENT_STATE_INVALID", "Inventaire indisponible.")
	var added := inventory.try_add(item_id, 1)
	if not added.get("success", false):
		return added
	var instance_ids := added.get("instance_ids", []) as Array
	if instance_ids.size() != 1:
		for value in instance_ids:
			inventory.remove_quantity(StringName(value), 1)
		return _failure("ITEM_INSTANCE_INVALID", "L'instance de récompense est invalide.")
	var instance_id := StringName(instance_ids[0])
	_applied_report_ids[report.report_id] = true
	_selected_by_report[report.report_id] = item_id
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
		"equipped": false,
	}


func remember_selection(report: CombatReport, item_id: StringName) -> bool:
	if report == null or _applied_report_ids.has(report.report_id):
		return false
	var options := _options_by_report.get(report.report_id, []) as Array
	if not _options_contain_item(options, item_id):
		return false
	_selected_by_report[report.report_id] = item_id
	return true


func get_selected_item_id(report_id: StringName) -> StringName:
	return StringName(_selected_by_report.get(report_id, &""))


func get_reward_state(report_id: StringName) -> StringName:
	if _applied_report_ids.has(report_id):
		return &"confirmed"
	if _selected_by_report.has(report_id):
		return &"selected"
	if _options_by_report.has(report_id):
		return &"offered"
	return &"unavailable"


func has_applied(report_id: StringName) -> bool:
	return _applied_report_ids.has(report_id)


func snapshot() -> Dictionary:
	var options := {}
	for report_id in _options_by_report:
		var item_ids: Array[String] = []
		for option_value in _options_by_report[report_id]:
			item_ids.append(str((option_value as Dictionary).get("item_id", &"")))
		options[str(report_id)] = item_ids
	var selected := {}
	for report_id in _selected_by_report:
		selected[str(report_id)] = str(_selected_by_report[report_id])
	var reward_states := {}
	for report_id in _options_by_report:
		reward_states[str(report_id)] = str(get_reward_state(report_id))
	var applied_ids: Array[String] = []
	for report_id in _applied_report_ids:
		applied_ids.append(str(report_id))
	return {
		"version": SNAPSHOT_VERSION,
		"deck": _string_array(_deck),
		"eligible_ids": _string_array(_eligible_ids),
		"offered_ids": _string_array(_offered_ids),
		"discarded_ids": _string_array(_discarded_ids),
		"options_by_report": options,
		"selected_by_report": selected,
		"reward_states_by_report": reward_states,
		"applied_report_ids": applied_ids,
	}


func restore_snapshot(
		snapshot_data: Dictionary,
		catalog: ItemCatalog,
		character_states: Array
	) -> bool:
	if catalog == null or not catalog.rebuild_index() \
			or int(snapshot_data.get("version", -1)) != SNAPSHOT_VERSION:
		return false
	var eligible := _string_name_array(snapshot_data.get("eligible_ids", []) as Array)
	var deck := _string_name_array(snapshot_data.get("deck", []) as Array)
	var offered := _string_name_array(snapshot_data.get("offered_ids", []) as Array)
	var discarded := _string_name_array(snapshot_data.get("discarded_ids", []) as Array)
	if _has_duplicates(eligible) or _has_duplicates(deck) \
			or _has_duplicates(offered) or _has_duplicates(discarded):
		return false
	for item_id in eligible:
		var definition := catalog.get_definition(item_id)
		if definition == null or not definition.is_equippable() \
				or not definition.tags.has(POOL_TAG):
			return false
	for item_id in deck + offered + discarded:
		if not eligible.has(item_id):
			return false
	var rebuilt_options := {}
	var raw_options := snapshot_data.get("options_by_report", {}) as Dictionary
	for report_key in raw_options:
		var report_id := StringName(report_key)
		var ids := _string_name_array(raw_options[report_key] as Array)
		if ids.size() != 2 or _has_duplicates(ids):
			return false
		var options: Array[Dictionary] = []
		for item_id in ids:
			var definition := catalog.get_definition(item_id)
			var compatible := _compatible_character_ids(definition, character_states)
			if definition == null or compatible.is_empty():
				return false
			options.append({
				"reward_id": item_id,
				"item_id": item_id,
				"definition": definition,
				"compatible_character_ids": compatible,
			})
		rebuilt_options[report_id] = options
	var applied := {}
	for report_value in snapshot_data.get("applied_report_ids", []) as Array:
		applied[StringName(report_value)] = true
	var selected := {}
	var raw_selected := snapshot_data.get("selected_by_report", {}) as Dictionary
	for report_key in raw_selected:
		var report_id := StringName(report_key)
		var item_id := StringName(raw_selected[report_key])
		if not rebuilt_options.has(report_id) or not _options_contain_item(
					rebuilt_options[report_id] as Array,
					item_id,
				):
			return false
		selected[report_id] = item_id
	for report_id in applied:
		if not rebuilt_options.has(report_id) or not selected.has(report_id):
			return false
	var raw_states := snapshot_data.get("reward_states_by_report", {}) as Dictionary
	for report_key in raw_states:
		var report_id := StringName(report_key)
		if not rebuilt_options.has(report_id):
			return false
		var expected_state: StringName = &"offered"
		if applied.has(report_id):
			expected_state = &"confirmed"
		elif selected.has(report_id):
			expected_state = &"selected"
		if StringName(raw_states[report_key]) != expected_state:
			return false
	_catalog = catalog
	_eligible_ids = eligible
	_deck = deck
	_offered_ids = offered
	_discarded_ids = discarded
	_options_by_report = rebuilt_options
	_applied_report_ids = applied
	_selected_by_report = selected
	return true


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


func _same_audience_and_slot(
		first: ItemDefinition,
		second: ItemDefinition,
		character_states: Array
	) -> bool:
	if first == null or second == null or first.equipment_slot != second.equipment_slot:
		return false
	var first_ids := _compatible_character_ids(first, character_states)
	var second_ids := _compatible_character_ids(second, character_states)
	first_ids.sort()
	second_ids.sort()
	return first_ids == second_ids


func _options_contain_item(options: Array, item_id: StringName) -> bool:
	for option_value in options:
		if StringName((option_value as Dictionary).get("item_id", &"")) == item_id:
			return true
	return false


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _string_name_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		var normalized := StringName(value)
		if normalized == &"":
			return []
		result.append(normalized)
	return result


func _has_duplicates(values: Array[StringName]) -> bool:
	var seen := {}
	for value in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false


func _failure(code: String, message: String) -> Dictionary:
	return {"success": false, "error_code": code, "error": message}
