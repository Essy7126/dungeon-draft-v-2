@tool
class_name ItemStudioDocument
extends RefCounted

signal changed
signal refresh_requested(kind: StringName, path: String)
signal dirty_changed(is_dirty: bool)

const CHANGE_VALUE := &"VALUE"
const CHANGE_STRUCTURE := &"STRUCTURE"
const CHANGE_PREVIEW := &"PREVIEW"
const CHANGE_DOCUMENT := &"DOCUMENT"

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
var original_file_sha256 := ""
var preview_disabled_effects := {}
var history := StudioHistoryController.new()
var copy_service := ItemDeepCopyService.new()
var _pending_change_kind: StringName = CHANGE_DOCUMENT
var _pending_change_path := ""


func _init() -> void:
	history.configure(_apply_history_snapshot, current_fingerprint)
	history.history_changed.connect(_on_history_changed)
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
	original_file_sha256 = _file_sha256(source_path)
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
	original_file_sha256 = ""
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
	original_file_sha256 = ""
	working_copy.item_id = new_item_id
	working_copy.display_name = "%s — copie" % definition.display_name
	if not copy_acquisition_tags:
		working_copy.tags.erase(FirstRunEquipmentRewardService.POOL_TAG)
	status = STATUS_NEW
	history.clear()
	history.set_saved_fingerprint("__unsaved__")
	changed.emit()
	return true


func record_edit(
		action_name: String,
		mutator: Callable,
		change_kind: StringName = CHANGE_VALUE,
		change_path := "",
		merge_key := ""
	) -> bool:
	if working_copy == null or not mutator.is_valid():
		return false
	var before := ItemFingerprintService.semantic_snapshot(working_copy)
	mutator.call()
	var after := ItemFingerprintService.semantic_snapshot(working_copy)
	_pending_change_kind = change_kind
	_pending_change_path = change_path
	var recorded := history.record(action_name, before, after, true, merge_key)
	_pending_change_kind = CHANGE_DOCUMENT
	_pending_change_path = ""
	return recorded


func record_snapshot(
		action_name: String,
		before: Dictionary,
		change_kind: StringName = CHANGE_VALUE,
		change_path := ""
	) -> bool:
	if working_copy == null:
		return false
	_pending_change_kind = change_kind
	_pending_change_path = change_path
	var recorded := history.record(
		action_name,
		before,
		ItemFingerprintService.semantic_snapshot(working_copy),
		true,
	)
	_pending_change_kind = CHANGE_DOCUMENT
	_pending_change_path = ""
	return recorded


func discard_changes() -> Dictionary:
	if source == null:
		return {"ok": false, "error": "Le nouvel objet n’a aucune source à recharger."}
	var reload_source := source
	if not source_path.is_empty() and FileAccess.file_exists(source_path):
		var disk_source := ResourceLoader.load(
			source_path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as ItemDefinition
		if disk_source != null:
			reload_source = disk_source
	return {
		"ok": open_definition(reload_source, status),
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
	original_file_sha256 = _file_sha256(saved_path)
	history.clear()
	history.set_saved_fingerprint(current_fingerprint())
	changed.emit()


func is_dirty() -> bool:
	return working_copy != null and not history.is_at_saved_state()


func current_fingerprint() -> String:
	return ItemFingerprintService.semantic_fingerprint(working_copy)


func snapshot_state() -> Dictionary:
	return {
		"source": copy_service.duplicate_definition(source),
		"working_copy": copy_service.duplicate_definition(working_copy),
		"source_path": source_path,
		"destination_path": destination_path,
		"status": status,
		"original_item_id": original_item_id,
		"original_fingerprint": original_fingerprint,
		"original_file_sha256": original_file_sha256,
		"preview_disabled_effects": preview_disabled_effects.duplicate(true),
		"history": history.snapshot_state(),
		"pending_change_kind": _pending_change_kind,
		"pending_change_path": _pending_change_path,
	}


func restore_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false
	var snapshot_source := state.get("source") as ItemDefinition
	var snapshot_working := state.get("working_copy") as ItemDefinition
	if snapshot_working == null:
		return false
	source = copy_service.duplicate_definition(snapshot_source)
	working_copy = copy_service.duplicate_definition(snapshot_working)
	if working_copy == null:
		return false
	source_path = str(state.get("source_path", ""))
	destination_path = str(state.get("destination_path", ""))
	status = StringName(state.get("status", STATUS_NEW))
	original_item_id = StringName(state.get("original_item_id", &""))
	original_fingerprint = str(state.get("original_fingerprint", ""))
	original_file_sha256 = str(state.get("original_file_sha256", ""))
	preview_disabled_effects = (
		state.get("preview_disabled_effects", {}) as Dictionary
	).duplicate(true)
	_pending_change_kind = StringName(state.get("pending_change_kind", CHANGE_DOCUMENT))
	_pending_change_path = str(state.get("pending_change_path", ""))
	if not history.restore_state(state.get("history", {}) as Dictionary):
		return false
	changed.emit()
	refresh_requested.emit(CHANGE_DOCUMENT, "")
	return true


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
	_emit_refresh(CHANGE_PREVIEW, "%s:%d" % [kind, index])


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
	var preview_reactive: Array[ItemReactiveEffectData] = []
	for index in range(result.reactive_effects.size()):
		if is_preview_effect_enabled(&"reactive", index):
			preview_reactive.append(result.reactive_effects[index])
	result.reactive_effects = preview_reactive
	return result


func _apply_history_snapshot(snapshot: Dictionary) -> void:
	if working_copy == null:
		return
	_restore_definition(working_copy, snapshot)
	_pending_change_kind = CHANGE_DOCUMENT
	_pending_change_path = ""


func _on_history_changed() -> void:
	_emit_refresh(_pending_change_kind, _pending_change_path)


func _emit_refresh(kind: StringName, path: String) -> void:
	changed.emit()
	refresh_requested.emit(kind, path)


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
	var reactive: Array[ItemReactiveEffectData] = []
	for value in snapshot.get("reactive_effects", []) as Array:
		var restored_effect := _restore_reactive_effect(value as Dictionary)
		if restored_effect != null:
			reactive.append(restored_effect)
	definition.reactive_effects = reactive
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


func _restore_reactive_effect(snapshot: Dictionary) -> ItemReactiveEffectData:
	var properties := snapshot.get("properties", {}) as Dictionary
	var effect := ItemReactiveEffectData.new()
	effect.enabled = bool(properties.get("enabled", true))
	effect.trigger_id = StringName(properties.get("trigger_id", ItemReactiveEffectData.TRIGGER_COMBAT_START))
	effect.target_id = StringName(properties.get("target_id", ItemReactiveEffectData.TARGET_TRIGGER_HERO))
	effect.result_id = StringName(properties.get("result_id", ItemReactiveEffectData.RESULT_HEAL_FLAT))
	effect.value = float(properties.get("value", 1.0))
	effect.threshold = float(properties.get("threshold", 0.5))
	effect.frequency_id = StringName(properties.get("frequency_id", ItemReactiveEffectData.FREQUENCY_UNLIMITED))
	effect.max_activations = int(properties.get("max_activations", 1))
	effect.recharge_turns = int(properties.get("recharge_turns", 1))
	var conditions: Array[ItemReactiveConditionData] = []
	for condition_value in properties.get("conditions", []) as Array:
		var condition_snapshot := condition_value as Dictionary
		var condition_properties := condition_snapshot.get("properties", {}) as Dictionary
		var condition := ItemReactiveConditionData.new()
		condition.condition_id = StringName(condition_properties.get("condition_id", &"trigger_team"))
		condition.comparison = StringName(condition_properties.get("comparison", &"equal"))
		condition.value = float(condition_properties.get("value", 0.0))
		condition.team = int(condition_properties.get("team", 0))
		conditions.append(condition)
	effect.conditions = conditions
	return effect


func _load_texture(path: String) -> Texture2D:
	return load(path) as Texture2D if not path.is_empty() else null


func _string_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result


static func _file_sha256(path: String) -> String:
	return FileAccess.get_sha256(path) if not path.is_empty() \
		and FileAccess.file_exists(path) else ""
