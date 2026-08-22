@tool
class_name ItemStudioValidationService
extends RefCounted

const VALID_CHARACTER_IDS: Array[StringName] = [&"elf", &"mage", &"warrior"]

var registry := ItemEffectRegistry.new()
var relic_registry := RelicEffectRegistry.new()
var copy_service := ItemDeepCopyService.new()


func validate_interactive(
		definition: ItemDefinition,
		catalog: ItemStudioCatalogService,
		target_path := "",
		source_path := "",
		published_item_id: StringName = &""
	) -> Dictionary:
	return _validate_definition(
		definition, catalog, target_path, source_path, published_item_id, false,
	)


func validate(
		definition: ItemDefinition,
		catalog: ItemStudioCatalogService,
		target_path := "",
		source_path := "",
		published_item_id: StringName = &""
	) -> Dictionary:
	return _validate_definition(
		definition, catalog, target_path, source_path, published_item_id, true,
	)


func _validate_definition(
		definition: ItemDefinition,
		catalog: ItemStudioCatalogService,
		target_path: String,
		source_path: String,
		published_item_id: StringName,
		include_catalog_audit: bool
	) -> Dictionary:
	var messages: Array[ItemStudioValidationMessage] = []
	if definition == null:
		_error(messages, &"ITEM_NULL", "Aucune définition d’objet n’est chargée.")
		return _report(messages)
	if definition.item_id == &"":
		_error(messages, &"ITEM_ID_EMPTY", "L’identifiant de l’objet est obligatoire.", "item_id")
	elif catalog != null and catalog.has_item_id(definition.item_id, source_path):
		_error(messages, &"ITEM_ID_DUPLICATE", "Cet item_id est déjà utilisé.", "item_id")
	if published_item_id != &"" and definition.item_id != published_item_id:
		_error(messages, &"PUBLISHED_ID_IMMUTABLE", "Un objet publié ne peut pas changer d’item_id ; dupliquez-le.", "item_id")
	if definition.display_name.strip_edges().is_empty():
		_error(messages, &"NAME_EMPTY", "Le nom affiché est obligatoire.", "display_name")
	if not target_path.is_empty() and FileAccess.file_exists(target_path) and target_path != source_path:
		_error(messages, &"PATH_COLLISION", "Le chemin de destination existe déjà.", target_path)
	_validate_category_and_slot(definition, messages)
	if definition.is_equippable() and definition.stack_limit != 1:
		_error(messages, &"EQUIPMENT_STACKABLE", "Un équipement ne peut pas être empilable.", "stack_limit")
	if definition.is_consumable() and definition.use_effect == ItemDefinition.UseEffect.NONE:
		_error(messages, &"CONSUMABLE_WITHOUT_EFFECT", "Un consommable doit posséder un effet d’usage.", "use_effect")
	if definition.is_consumable() and definition.is_equippable():
		_error(messages, &"CONSUMABLE_EQUIPPED", "Un consommable ne peut pas être équipé.", "equipment_slot")
	if definition.is_relic():
		if definition.stack_limit != 1:
			_error(messages, &"RELIC_STACKABLE", "Une relique est unique et non empilable.", "stack_limit")
		if definition.equipment_slot != ItemDefinition.EquipmentSlot.NONE:
			_error(messages, &"RELIC_EQUIPPABLE", "Une relique ne possède aucun emplacement d’équipement.", "equipment_slot")
		if definition.use_effect != ItemDefinition.UseEffect.NONE:
			_error(messages, &"RELIC_USABLE", "Une relique n’est jamais utilisée ni consommée.", "use_effect")
		if not definition.stat_modifiers.is_empty() or not definition.spell_modifiers.is_empty():
			_error(messages, &"RELIC_LEGACY_EFFECT", "Une relique doit utiliser uniquement des blocs réactifs.", "reactive_effects")
		if definition.reactive_effects.is_empty():
			_error(messages, &"RELIC_WITHOUT_EFFECT", "Une relique doit posséder au moins un bloc d’effet.", "reactive_effects")
		if not definition.compatible_character_ids.is_empty():
			_error(messages, &"RELIC_HERO_COMPATIBILITY", "Une relique est un bonus partagé de la partie et ne cible aucun héros à l’acquisition.", "compatible_character_ids")
	for index in range(definition.reactive_effects.size()):
		var effect := definition.reactive_effects[index]
		for issue in relic_registry.validate_effect(effect):
			_error(
				messages,
				StringName(issue.get("code", &"REACTIVE_EFFECT_INVALID")),
				"Effet réactif %d : %s" % [index + 1, issue.get("message", "combinaison invalide")],
				"reactive_effects[%d]" % index,
			)
	for character_id in definition.compatible_character_ids:
		if character_id not in VALID_CHARACTER_IDS:
			_error(messages, &"CHARACTER_UNKNOWN", "Héros compatible introuvable : %s." % character_id, "compatible_character_ids")
	for index in range(definition.stat_modifiers.size()):
		var modifier := definition.stat_modifiers[index]
		if modifier == null:
			_error(messages, &"EFFECT_NULL", "Le modificateur de statistique %d est nul." % (index + 1), "stat_modifiers")
			continue
		if not modifier.is_valid():
			_error(messages, &"STAT_MODIFIER_INVALID", "Le modificateur de statistique %d est invalide." % (index + 1), "stat_modifiers")
		if not is_finite(modifier.value):
			_error(messages, &"VALUE_NOT_FINITE", "Une valeur de statistique est NaN ou infinie.", "stat_modifiers")
		if modifier.stat_id in [&"max_ap", &"max_mp"]:
			_warning(messages, &"ACTION_ECONOMY_BREAKPOINT", "Une modification de PA ou PM est un breakpoint fort.", "stat_modifiers")
	for index in range(definition.spell_modifiers.size()):
		var modifier := definition.spell_modifiers[index]
		if modifier == null:
			_error(messages, &"EFFECT_NULL", "Le modificateur de sort %d est nul." % (index + 1), "spell_modifiers")
			continue
		if registry.descriptor_for_resource(modifier) == null:
			_error(messages, &"EFFECT_UNSUPPORTED", "%s — Effet non pris en charge par le Studio." % _runtime_class(modifier), "spell_modifiers")
		if modifier is ItemSpellModifierData:
			var item_modifier := modifier as ItemSpellModifierData
			for value in [item_modifier.damage_percent, item_modifier.target_hp_at_or_below, item_modifier.healing_and_shield_percent]:
				if not is_finite(float(value)):
					_error(messages, &"VALUE_NOT_FINITE", "Une valeur de modificateur de sort est NaN ou infinie.", "spell_modifiers")
			if item_modifier.range_bonus != 0:
				_warning(messages, &"RANGE_BREAKPOINT", "Le bonus de portée doit être vérifié sur les sorts compatibles.", "spell_modifiers")
			if item_modifier.damage_percent > 0.0 and item_modifier.target_spell_id == &"" \
					and item_modifier.target_spell_name.is_empty() and item_modifier.damage_type_filter < 0 \
					and not item_modifier.require_elemental_damage:
				_warning(messages, &"GLOBAL_MULTIPLIER", "Ce multiplicateur peut s’appliquer à tous les sorts offensifs.", "spell_modifiers")
	if definition.icon == null:
		_warning(messages, &"ICON_MISSING", "Aucune icône d’inventaire n’est définie.", "icon")
	if definition.get_reward_card_texture() == null:
		_warning(messages, &"CARD_MISSING", "Aucune carte de récompense n’est définie.", "card_texture")
	if definition.description.strip_edges().is_empty():
		_warning(messages, &"DESCRIPTION_EMPTY", "La description joueur est vide.", "description")
	if definition.compatible_character_ids.is_empty():
		_info(messages, &"ALL_HEROES", "L’objet est compatible avec tous les héros contrôlés.")
	if definition.tags.has(FirstRunEquipmentRewardService.POOL_TAG) \
			and definition.compatible_character_ids.any(func(id): return id not in VALID_CHARACTER_IDS):
		_warning(messages, &"REWARD_WITHOUT_HERO", "L’objet de récompense ne possède aucun héros compatible reconnu.")
	var debug_text := "%s %s %s" % [definition.display_name, definition.description, " ".join(_strings(definition.tags))]
	if ["DEBUG", "CHEAT", "PLACEHOLDER"].any(func(marker): return debug_text.to_upper().contains(marker)):
		_warning(messages, &"DEBUG_VALUE", "Une valeur DEBUG/CHEAT/PLACEHOLDER ne doit pas fonder l’analyse.")
	if include_catalog_audit and catalog != null:
		var audit := copy_service.audit_catalog(catalog.production_definitions())
		if not audit.get("valid", false):
			_warning(messages, &"MUTABLE_RESOURCE_SHARED", "Une sous-ressource mutable est partagée entre objets de production.")
	return _report(messages)


func _validate_category_and_slot(
		definition: ItemDefinition,
		messages: Array[ItemStudioValidationMessage]
	) -> void:
	var expected_slot := ItemDefinition.EquipmentSlot.NONE
	match definition.category:
		ItemDefinition.Category.WEAPON:
			expected_slot = ItemDefinition.EquipmentSlot.WEAPON
		ItemDefinition.Category.ARMOR:
			expected_slot = ItemDefinition.EquipmentSlot.ARMOR
		ItemDefinition.Category.ACCESSORY:
			expected_slot = ItemDefinition.EquipmentSlot.ACCESSORY
	if definition.category in [ItemDefinition.Category.WEAPON, ItemDefinition.Category.ARMOR, ItemDefinition.Category.ACCESSORY] \
			and definition.equipment_slot != expected_slot:
		_error(messages, &"CATEGORY_SLOT_MISMATCH", "La catégorie et l’emplacement d’équipement sont incompatibles.", "equipment_slot")
	if definition.category in [ItemDefinition.Category.CONSUMABLE, ItemDefinition.Category.SCROLL] \
			and definition.equipment_slot != ItemDefinition.EquipmentSlot.NONE:
		_error(messages, &"CATEGORY_SLOT_MISMATCH", "Un consommable ou parchemin ne possède aucun emplacement.", "equipment_slot")
	if definition.category == ItemDefinition.Category.RELIC \
			and definition.equipment_slot != ItemDefinition.EquipmentSlot.NONE:
		_error(messages, &"CATEGORY_SLOT_MISMATCH", "Une relique ne possède aucun emplacement.", "equipment_slot")


func _report(messages: Array[ItemStudioValidationMessage]) -> Dictionary:
	var snapshots: Array[Dictionary] = []
	var error_count := 0
	var warning_count := 0
	for message in messages:
		snapshots.append(message.to_snapshot())
		if message.severity == ItemStudioValidationMessage.Severity.ERROR:
			error_count += 1
		elif message.severity == ItemStudioValidationMessage.Severity.WARNING:
			warning_count += 1
	return {
		"valid": error_count == 0,
		"errors": error_count,
		"warnings": warning_count,
		"messages": snapshots,
	}


func _error(messages: Array[ItemStudioValidationMessage], code: StringName, text: String, path := "") -> void:
	messages.append(ItemStudioValidationMessage.new().configure(ItemStudioValidationMessage.Severity.ERROR, code, text, path))


func _warning(messages: Array[ItemStudioValidationMessage], code: StringName, text: String, path := "") -> void:
	messages.append(ItemStudioValidationMessage.new().configure(ItemStudioValidationMessage.Severity.WARNING, code, text, path))


func _info(messages: Array[ItemStudioValidationMessage], code: StringName, text: String, path := "") -> void:
	messages.append(ItemStudioValidationMessage.new().configure(ItemStudioValidationMessage.Severity.INFO, code, text, path))


func _runtime_class(resource: Resource) -> String:
	var script := resource.get_script() as Script if resource != null else null
	return script.resource_path.get_file().get_basename() if script != null else resource.get_class()


func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
