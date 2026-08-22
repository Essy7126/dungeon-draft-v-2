@tool
class_name SkillEffectEditorRegistry
extends RefCounted

const MODIFIER_CLASSES := {
	"SpellModTerrainOnAffectedCells": ["Terrain sur zone", "cases", "cases affectees", "selon le terrain", "durée du terrain", "a la résolution du terrain", "remplacement par cellule"],
	"SpellModRangeBonus": ["Portée supplementaire", "cases", "lanceur", "toujours", "permanent pour le cast", "au calcul de portée", "cumul additif"],
	"SpellModNextTurnMovement": ["PM au prochain tour", "PM", "cible", "si la cible est valide", "prochain tour", "fin du cast", "cumul additif"],
	"SpellModHealBonus": ["Soin supplementaire", "PV", "alliés affectes", "toujours", "instantane", "résolution des cibles", "cumul additif"],
	"SpellModExactPushDistance": ["Distance de poussee exacte", "cases", "ennemis affectes", "si poussable", "instantane", "résolution du mouvement", "remplacement"],
	"SpellModDamageBonusAtMinRange": ["Dégâts a portée minimale", "degats", "ennemi principal", "portée minimale", "instantane", "résolution des cibles", "cumul additif"],
	"SpellModCollisionDamage": ["Dégâts de collision", "degats", "victime de collision", "collision réelle", "instantane", "résolution du mouvement", "maximum exact ou cumul"],
	"SpellModCentralCellDamageBonus": ["Dégâts cellule centrale", "degats", "cible centrale", "cellule centrale touchee", "instantane", "résolution des cibles", "cumul additif"],
	"SpellModBackstabDamageBonus": ["Dégâts de dos", "degats", "ennemi principal", "attaque dans le dos", "instantane", "résolution des cibles", "cumul additif"],
	"SpellModApplyStatus": ["Application de statut", "valeur de statut", "cibles affectees", "cible valide", "tours", "finalisation des cibles", "politique du statut"],
	"SpellModAlignedSecondaryTarget": ["Cible secondaire alignee", "cases", "ennemi secondaire", "alignement valide", "instantane", "résolution des cibles", "une cible unique"],
	"SpellModAdditionalShield": ["Bouclier supplementaire", "bouclier", "alliés affectes", "toujours", "instantane", "résolution des dégâts", "cumul additif"],
	"SpellModAdditionalPush": ["Poussee supplementaire", "cases", "ennemis affectes", "si poussable", "instantane", "résolution du mouvement", "cumul additif"],
}

var _effects := {}
var _classes := {}


func _init() -> void:
	_build_effect_descriptors()
	_build_class_descriptors()


func descriptor_for(modifier: SpellModifier) -> SkillEffectEditorDescriptor:
	if modifier is SpellModSkillTreeEffect:
		return _effects.get((modifier as SpellModSkillTreeEffect).effect_type) \
			as SkillEffectEditorDescriptor
	if modifier == null:
		return null
	var script: Script = modifier.get_script() as Script
	var resolved_class_name: String = str(script.get_global_name()) \
		if script != null else modifier.get_class()
	return _classes.get(resolved_class_name) as SkillEffectEditorDescriptor


func effect_descriptor(effect_type: int) -> SkillEffectEditorDescriptor:
	return _effects.get(effect_type) as SkillEffectEditorDescriptor


func class_descriptor(requested_class_name: String) -> SkillEffectEditorDescriptor:
	return _classes.get(requested_class_name) as SkillEffectEditorDescriptor


func coverage_report(modifiers: Array = []) -> Dictionary:
	var missing := PackedStringArray()
	for index in range(SpellModSkillTreeEffect.EffectType.size()):
		if not _effects.has(index):
			missing.append("EffectType:%d" % index)
	for modifier_class_name in MODIFIER_CLASSES:
		if not _classes.has(modifier_class_name):
			missing.append(modifier_class_name)
	for value in modifiers:
		if value is SpellModifier and descriptor_for(value) == null:
			var modifier := value as SpellModifier
			var script: Script = modifier.get_script() as Script
			missing.append(str(script.get_global_name()) if script != null else modifier.get_class())
	return {
		"ok": missing.is_empty(),
		"effect_type_count": _effects.size(),
		"modifier_class_count": _classes.size(),
		"missing": missing,
	}


func all_effect_descriptors() -> Array[SkillEffectEditorDescriptor]:
	var result: Array[SkillEffectEditorDescriptor] = []
	for index in range(SpellModSkillTreeEffect.EffectType.size()):
		result.append(_effects[index])
	return result


func _build_effect_descriptors() -> void:
	for effect_type in range(SpellModSkillTreeEffect.EffectType.size()):
		var descriptor: SkillEffectEditorDescriptor = SkillEffectEditorDescriptor.new()
		descriptor.effect_type = effect_type
		descriptor.descriptor_id = StringName("skill_tree_effect_%d" % effect_type)
		descriptor.modifier_class = "SpellModSkillTreeEffect"
		descriptor.display_name = SkillTreeEffectSummaryService.effect_type_label(effect_type)
		descriptor.fields = [
			{"property": &"effect_type", "label": "Type"},
			{"property": &"target_scope", "label": "Cible"},
		]
		_configure_effect(descriptor, effect_type)
		_effects[effect_type] = descriptor


func _configure_effect(descriptor: SkillEffectEditorDescriptor, effect_type: int) -> void:
	var amount_effects := [
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
		16, 17, 18, 19, 20, 21, 22, 23, 24, 26, 27, 28, 31, 32,
	]
	if effect_type in amount_effects:
		descriptor.fields.append({
			"property": &"amount", "label": "Quantite", "required_positive": false,
		})
	var damage_effects := [0, 1, 2, 3, 4, 19, 20, 21, 23]
	var heal_effects := [6, 7, 25]
	var shield_effects := [8, 9, 26, 31, 32]
	var movement_effects := [10, 11, 18, 27]
	if effect_type in damage_effects:
		descriptor.unit = "degats"
		descriptor.target = "ennemis selon la portée choisie"
	elif effect_type in heal_effects:
		descriptor.unit = "PV"
		descriptor.target = "alliés selon la portée choisie"
	elif effect_type in shield_effects:
		descriptor.unit = "bouclier"
		descriptor.target = "alliés selon la portée choisie"
	elif effect_type in movement_effects:
		descriptor.unit = "PM ou cases"
	elif effect_type == SpellModSkillTreeEffect.EffectType.RANGE:
		descriptor.unit = "cases de portée"
	elif effect_type == SpellModSkillTreeEffect.EffectType.AREA_CARDINAL:
		descriptor.unit = "couches cardinales"
	elif effect_type in [
		SpellModSkillTreeEffect.EffectType.STATUS_DOT,
		SpellModSkillTreeEffect.EffectType.STATUS_SLOW,
		SpellModSkillTreeEffect.EffectType.STATUS_REGEN,
		SpellModSkillTreeEffect.EffectType.STATUS_VULNERABILITY,
		SpellModSkillTreeEffect.EffectType.STATUS_OUTGOING_DAMAGE,
	]:
		descriptor.unit = "valeur de statut"
		descriptor.duration = "duration tours"
		descriptor.frequency = "selon status_timing"
		descriptor.stacking = "status_mode BASE / DELTA / OVERRIDE"
		descriptor.fields.append_array([
			{"property": &"duration", "label": "Durée"},
			{"property": &"status_name", "label": "Nom du statut"},
			{"property": &"status_group", "label": "Groupe stable"},
			{"property": &"status_mode", "label": "Empilement"},
			{"property": &"status_timing", "label": "Frequence"},
		])
	if effect_type in [2, 4, 7]:
		descriptor.condition = "cible sous threshold_ratio PV"
		descriptor.fields.append({"property": &"threshold_ratio", "label": "Seuil de PV"})
	elif effect_type in [3, 4]:
		descriptor.condition = "attaque dans le dos"
	if effect_type == SpellModSkillTreeEffect.EffectType.ADJACENT_HEAL_RATIO:
		descriptor.unit = "ratio du soin principal"
		descriptor.target = "alliés adjacents"
		descriptor.fields.append({"property": &"ratio", "label": "Ratio partage"})
	if effect_type == SpellModSkillTreeEffect.EffectType.CLEANSE:
		descriptor.unit = "statuts retires"
		descriptor.target = "alliés selon la portée choisie"
	if effect_type == SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET:
		descriptor.target = "lanceur vers la cible"
		descriptor.condition = "destination libre et alignement valide"
	if effect_type == SpellModSkillTreeEffect.EffectType.ALLOW_FREE_CELL_TARGET:
		descriptor.target = "cellule libre"
		descriptor.stacking = "booleen, sans cumul"


func _build_class_descriptors() -> void:
	for modifier_class_name in MODIFIER_CLASSES:
		var spec := MODIFIER_CLASSES[modifier_class_name] as Array
		var descriptor: SkillEffectEditorDescriptor = SkillEffectEditorDescriptor.new()
		descriptor.descriptor_id = StringName(str(modifier_class_name).to_snake_case())
		descriptor.modifier_class = str(modifier_class_name)
		descriptor.display_name = str(spec[0])
		descriptor.unit = str(spec[1])
		descriptor.target = str(spec[2])
		descriptor.condition = str(spec[3])
		descriptor.duration = str(spec[4])
		descriptor.frequency = str(spec[5])
		descriptor.stacking = str(spec[6])
		_classes[modifier_class_name] = descriptor
