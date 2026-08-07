@tool
class_name ItemStudioDocument
extends RefCounted

signal changed
signal dirty_changed(is_dirty: bool)

const STATUS_SHARED := &"SHARED"
const STATUS_DRAFT := &"DRAFT"
const STATUS_NEW := &"NEW"

var source: ItemDefinition = null
var working_copy: ItemDefinition = null
var source_path := ""
var destination_path := ""
var status: StringName = STATUS_NEW
var original_item_id: StringName = &""
var original_fingerprint := ""
var preview_disabled_effects := {}
var history := StudioHistoryController.new()
var copy_service := ItemDeepCopyService.new()


func _init() -> void:
	history.configure(_apply_history_snapshot, current_fingerprint)
	history.history_changed.connect(func(): changed.emit())
	history.dirty_state_changed.connect(func(dirty: bool): dirty_changed.emit(dirty))


func open_definition(definition: ItemDefinition, p_status := STATUS_SHARED) -> bool:
	if definition == null:
		return false
	source = definition
	working_copy = copy_service.duplicate_definition(definition)
	if working_copy == null:
		return false
	source_path = definition.resource_path
	destination_path = source_path
	status = p_status
	original_item_id = definition.item_id
	original_fingerprint = ItemFingerprintService.semantic_fingerprint(definition)
	preview_disabled_effects.clear()
	history.clear()
	history.set_saved_fingerprint(current_fingerprint())
	changed.emit()
	return true


func create_new(template: ItemDefinition) -> bool:
	if template == null:
		return false
	source = null
	working_copy = copy_service.duplicate_definition(template)
	if working_copy == null:
		return false
	source_path = ""
	destination_path = ""
	status = STATUS_NEW
	original_item_id = &""
	original_fingerprint = ""
	preview_disabled_effects.clear()
	history.clear()
	history.set_saved_fingerprint("__unsaved__")
	changed.emit()
	return true


func duplicate_as_new(
		definition: ItemDefinition,
		new_item_id: StringName,
		copy_acquisition_tags := false
	) -> bool:
	if not open_definition(definition, STATUS_NEW):
		return false
	source = null
	source_path = ""
	destination_path = ""
	original_item_id = &""
	original_fingerprint = ""
	working_copy.item_id = new_item_id
	working_copy.display_name = "%s — copie" % definition.display_name
	if not copy_acquisition_tags:
		working_copy.tags.erase(FirstRunEquipmentRewardService.POOL_TAG)
	status = STATUS_NEW
	history.clear()
	history.set_saved_fingerprint("__unsaved__")
	changed.emit()
	return true


func record_edit(action_name: String, mutator: Callable) -> bool:
	if working_copy == null or not mutator.is_valid():
		return false
	var before := ItemFingerprintService.semantic_snapshot(working_copy)
	mutator.call()
	var after := ItemFingerprintService.semantic_snapshot(working_copy)
	var recorded := history.record(action_name, before, after, true)
	if not recorded:
		changed.emit()
	return recorded


func record_snapshot(action_name: String, before: Dictionary) -> bool:
	if working_copy == null:
		return false
	return history.record(
		action_name,
		before,
		ItemFingerprintService.semantic_snapshot(working_copy),
		true,
	)


func discard_changes() -> Dictionary:
	if source == null:
		return {"ok": false, "error": "Le nouvel objet n’a aucune source à recharger."}
	return {
		"ok": open_definition(source, status),
		"fingerprint": original_fingerprint,
	}


func mark_saved(reloaded: ItemDefinition, p_status: StringName, saved_path: String) -> void:
	source = reloaded
	working_copy = copy_service.duplicate_definition(reloaded)
	source_path = saved_path
	destination_path = saved_path
	status = p_status
	original_item_id = reloaded.item_id
	original_fingerprint = ItemFingerprintService.semantic_fingerprint(reloaded)
	history.clear()
	history.set_saved_fingerprint(current_fingerprint())
	changed.emit()


func is_dirty() -> bool:
	return working_copy != null and not history.is_at_saved_state()


func current_fingerprint() -> String:
	return ItemFingerprintService.semantic_fingerprint(working_copy)


func change_set() -> ItemChangeSet:
	return ItemChangeSet.between(
		ItemFingerprintService.semantic_snapshot(source),
		ItemFingerprintService.semantic_snapshot(working_copy),
	)


func set_preview_effect_enabled(kind: StringName, index: int, enabled: bool) -> void:
	var key := "%s:%d" % [kind, index]
	if enabled:
		preview_disabled_effects.erase(key)
	else:
		preview_disabled_effects[key] = true
	changed.emit()


func is_preview_effect_enabled(kind: StringName, index: int) -> bool:
	return not preview_disabled_effects.has("%s:%d" % [kind, index])


func preview_copy() -> ItemDefinition:
	var result := copy_service.duplicate_definition(working_copy)
	if result == null:
		return null
	var preview_stats: Array[ItemStatModifierData] = []
	for index in range(result.stat_modifiers.size()):
		if is_preview_effect_enabled(&"stat", index):
			preview_stats.append(result.stat_modifiers[index])
	result.stat_modifiers = preview_stats
	var preview_spells: Array[SpellModifier] = []
	for index in range(result.spell_modifiers.size()):
		if is_preview_effect_enabled(&"spell", index):
			preview_spells.append(result.spell_modifiers[index])
	result.spell_modifiers = preview_spells
	return result


func _apply_history_snapshot(snapshot: Dictionary) -> void:
	if working_copy == null:
		return
	_restore_definition(working_copy, snapshot)
	changed.emit()


func _restore_definition(definition: ItemDefinition, snapshot: Dictionary) -> void:
	definition.item_id = StringName(snapshot.get("item_id", &""))
	definition.display_name = str(snapshot.get("display_name", ""))
	definition.description = str(snapshot.get("description", ""))
	definition.icon = _load_texture(str(snapshot.get("icon", "")))
	definition.inventory_icon = _load_texture(str(snapshot.get("inventory_icon", "")))
	definition.card_texture = _load_texture(str(snapshot.get("card_texture", "")))
	definition.rarity = StringName(snapshot.get("rarity", &"common"))
	definition.tags = _string_names(snapshot.get("tags", []) as Array)
	definition.reward_fx_profile = StringName(snapshot.get("reward_fx_profile", &"generic"))
	definition.reward_audio_profile = StringName(snapshot.get("reward_audio_profile", &"generic"))
	definition.category = int(snapshot.get("category", ItemDefinition.Category.ACCESSORY))
	definition.stack_limit = int(snapshot.get("stack_limit", 1))
	definition.equipment_slot = int(snapshot.get("equipment_slot", ItemDefinition.EquipmentSlot.NONE))
	definition.compatible_character_ids = _string_names(
		snapshot.get("compatible_character_ids", []) as Array
	)
	var stats: Array[ItemStatModifierData] = []
	for value in snapshot.get("stat_modifiers", []) as Array:
		var properties := (value as Dictionary).get("properties", {}) as Dictionary
		var stat := ItemStatModifierData.new()
		stat.stat_id = StringName(properties.get("stat_id", &""))
		stat.value = float(properties.get("value", 0.0))
		stat.modifier_type = int(properties.get("modifier_type", ItemStatModifierData.ModifierType.FLAT))
		stats.append(stat)
	definition.stat_modifiers = stats
	var spells: Array[SpellModifier] = []
	for value in snapshot.get("spell_modifiers", []) as Array:
		var restored := _restore_spell_modifier(value as Dictionary)
		if restored != null:
			spells.append(restored)
	definition.spell_modifiers = spells
	definition.use_effect = int(snapshot.get("use_effect", ItemDefinition.UseEffect.NONE))
	definition.use_value = float(snapshot.get("use_value", 0.0))


func _restore_spell_modifier(snapshot: Dictionary) -> SpellModifier:
	var script_path := str(snapshot.get("script_path", ""))
	var script := load(script_path) as Script if not script_path.is_empty() else null
	var modifier := script.new() as SpellModifier if script != null else null
	if modifier == null:
		return null
	var properties := snapshot.get("properties", {}) as Dictionary
	for property_name in properties:
		var value = properties[property_name]
		if property_name in ["target_spell_id"]:
			value = StringName(value)
		modifier.set(property_name, value)
	return modifier


func _load_texture(path: String) -> Texture2D:
	return load(path) as Texture2D if not path.is_empty() else null


func _string_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result
