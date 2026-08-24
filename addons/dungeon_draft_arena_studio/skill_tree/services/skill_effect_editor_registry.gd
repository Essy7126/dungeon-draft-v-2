@tool
class_name SkillEffectEditorRegistry
extends RefCounted

## Source unique de verite sur ce que chaque EffectType consulte reellement au
## runtime (core/spell_mods/spell_mod_skill_tree_effect.gd). L'inspecteur ne
## doit jamais redecider localement quels champs afficher : il lit
## descriptor.fields produit ici. Toute nouvelle valeur d'EffectType doit
## etre ajoutee ici avant d'etre exposee dans l'editeur.

const EffectType := SpellModSkillTreeEffect.EffectType

## Types pour lesquels _units_for_scope(ctx) est reellement appelee : le champ
## "Cible de l'effet" (target_scope) y change le resultat. Verifie ligne a
## ligne dans on_targets_resolved/on_damage_resolved (spell_mod_skill_tree_effect.gd).
const SCOPE_AWARE_EFFECTS := [
	EffectType.DAMAGE_ALL, EffectType.HEAL, EffectType.SHIELD_TARGET,
	EffectType.STATUS_DOT, EffectType.STATUS_SLOW, EffectType.STATUS_REGEN,
	EffectType.STATUS_VULNERABILITY, EffectType.STATUS_OUTGOING_DAMAGE,
	EffectType.PUSH_BONUS, EffectType.PUSH_EXACT, EffectType.CLEANSE,
]

## Cible reelle et fixe des types qui n'utilisent pas target_scope. Affichee
## en lecture seule a la place du champ "Cible de l'effet", qui serait ignore.
const FIXED_TARGETS := {
	EffectType.DAMAGE_CENTER: "la cellule centrale de la zone",
	EffectType.DAMAGE_LOW_HP: "la cible ennemie principale",
	EffectType.DAMAGE_BACKSTAB: "la cible ennemie principale",
	EffectType.DAMAGE_BACKSTAB_OR_LOW_HP: "la cible ennemie principale",
	EffectType.HEAL_LOW_HP: "la cible alliée principale",
	EffectType.SHIELD_CASTER_IF_ALLY: "le lanceur, seulement si la cible principale est un allié",
	EffectType.NEXT_TURN_MP_TARGET: "la cible principale",
	EffectType.NEXT_TURN_MP_CASTER: "le lanceur",
	EffectType.COLLISION_BONUS: "la victime de la collision",
	EffectType.COLLISION_EXACT: "la victime de la collision",
	EffectType.TERRAIN_DURATION: "le terrain déjà créé par ce sort",
	EffectType.TERRAIN_DAMAGE: "le terrain déjà créé par ce sort",
	EffectType.ADJACENT_HEAL_RATIO: "les alliés adjacents à la cible principale",
	EffectType.SHIELD_ALLIES_ON_AREA: "les alliés dans la zone touchée",
	EffectType.MP_ALLIES_ON_AREA: "les alliés dans la zone touchée",
	EffectType.ATTACK_BUFF: "la cible alliée principale",
	EffectType.MOVE_CASTER_TO_TARGET: "le lanceur, vers la cible",
	EffectType.ALLOW_FREE_CELL_TARGET: "une cellule libre",
	EffectType.ADJACENT_SHIELD: "les alliés autour de la cible, ou du lanceur si le sort n'a pas de cible",
	EffectType.SHIELD_CASTER: "le lanceur",
}

## effect_group n'est lu que par _add_grouped_damage_to_cell(), appelee
## uniquement pour DAMAGE_LOW_HP. Les 32 autres types l'ignorent totalement.
const EFFECT_GROUP_AWARE_EFFECTS := [
	EffectType.DAMAGE_LOW_HP,
]

## require_backstab/require_ally_target ne sont lus que par _condition_passes(),
## appelee uniquement par NEXT_TURN_MP_TARGET et NEXT_TURN_MP_CASTER.
const CONDITION_FLAG_AWARE_EFFECTS := [
	EffectType.NEXT_TURN_MP_TARGET, EffectType.NEXT_TURN_MP_CASTER,
]

const MODIFIER_CLASSES := {
	"SpellModTerrainOnAffectedCells": ["Terrain sur zone", "cases", "les cases affectées", "selon le terrain", "durée du terrain", "à la résolution du terrain", "remplacement par cellule"],
	"SpellModRangeBonus": ["Portée supplémentaire", "cases", "le lanceur", "toujours", "permanent pour le lancement", "au calcul de portée", "cumul additif"],
	"SpellModNextTurnMovement": ["PM au prochain tour", "PM", "la cible", "si la cible est valide", "prochain tour", "fin du lancement", "cumul additif"],
	"SpellModHealBonus": ["Soin supplémentaire", "PV", "les alliés affectés", "toujours", "instantané", "résolution des cibles", "cumul additif"],
	"SpellModExactPushDistance": ["Distance de poussée exacte", "cases", "les ennemis affectés", "si poussable", "instantané", "résolution du mouvement", "remplacement"],
	"SpellModDamageBonusAtMinRange": ["Dégâts à portée minimale", "dégâts", "l'ennemi principal", "portée minimale", "instantané", "résolution des cibles", "cumul additif"],
	"SpellModCollisionDamage": ["Dégâts de collision (historique)", "dégâts", "la victime de la collision", "collision réelle", "instantané", "résolution du mouvement", "maximum exact ou cumul"],
	"SpellModCentralCellDamageBonus": ["Dégâts sur cellule centrale", "dégâts", "la cible centrale", "cellule centrale touchée", "instantané", "résolution des cibles", "cumul additif"],
	"SpellModBackstabDamageBonus": ["Dégâts de dos", "dégâts", "l'ennemi principal", "attaque dans le dos", "instantané", "résolution des cibles", "cumul additif"],
	"SpellModApplyStatus": ["Application de statut", "valeur de statut", "les cibles affectées", "cible valide", "tours", "finalisation des cibles", "politique du statut"],
	"SpellModAlignedSecondaryTarget": ["Cible secondaire alignée", "cases", "l'ennemi secondaire", "alignement valide", "instantané", "résolution des cibles", "une cible unique"],
	"SpellModAdditionalShield": ["Bouclier supplémentaire", "bouclier", "les alliés affectés", "toujours", "instantané", "résolution des dégâts", "cumul additif"],
	"SpellModAdditionalPush": ["Poussée supplémentaire", "cases", "les ennemis affectés", "si poussable", "instantané", "résolution du mouvement", "cumul additif"],
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
			"property": &"amount", "label": "Quantité", "required_positive": false, "guided": true,
		})
	# Cible : le champ "Cible de l'effet" n'a un effet reel que pour les types
	# listes dans SCOPE_AWARE_EFFECTS (verifie contre _units_for_scope dans le
	# runtime). Les autres types ont une cible fixe, affichee en lecture seule.
	if effect_type in SCOPE_AWARE_EFFECTS:
		descriptor.fields.append({"property": &"target_scope", "label": "Cible", "guided": true})
		descriptor.target = "défini par le réglage « Cible de l'effet » ci-dessus"
	elif FIXED_TARGETS.has(effect_type):
		descriptor.target = str(FIXED_TARGETS[effect_type])
	var damage_effects := [0, 1, 2, 3, 4, 20, 21, 23]
	var heal_effects := [6, 7]
	var shield_effects := [8, 9, 26, 31, 32]
	# PUSH_EXACT (19) deplace des unites en cases, ce n'est pas un effet de
	# degats : corrige d'une classification erronee qui affichait "degats"
	# comme unite pour un effet de poussee.
	var mp_effects := [
		EffectType.NEXT_TURN_MP_TARGET,
		EffectType.NEXT_TURN_MP_CASTER,
		EffectType.MP_ALLIES_ON_AREA,
	]
	var push_effects := [EffectType.PUSH_BONUS, EffectType.PUSH_EXACT]
	if effect_type in damage_effects:
		descriptor.unit = "dégâts"
	elif effect_type in heal_effects:
		descriptor.unit = "PV"
	elif effect_type in shield_effects:
		descriptor.unit = "bouclier"
	elif effect_type in mp_effects:
		descriptor.unit = "PM"
	elif effect_type in push_effects:
		descriptor.unit = "cases"
	elif effect_type == EffectType.RANGE:
		descriptor.unit = "cases de portée"
	elif effect_type == EffectType.AREA_CARDINAL:
		descriptor.unit = "couches cardinales"
	elif effect_type == EffectType.CLEANSE:
		descriptor.unit = "statuts retirés"
	elif effect_type == EffectType.ADJACENT_HEAL_RATIO:
		descriptor.unit = "ratio du soin principal"
	# Statuts et bonus a charges : chaque branche ci-dessous ne liste que les
	# proprietes reellement lues par _build_status()/_apply_attack_buff() dans
	# le runtime, verifiees une a une plutot que groupees par ressemblance.
	match effect_type:
		EffectType.STATUS_DOT:
			descriptor.unit = "valeur de statut"
			descriptor.duration = "durée en tours, lue par le runtime"
			descriptor.frequency = "au début ou à la fin du tour, selon le réglage Moment d'application"
			descriptor.stacking = "empilement selon Empilement : BASE crée, DELTA ajoute, OVERRIDE remplace"
			descriptor.fields.append_array([
				{"property": &"duration", "label": "Durée", "guided": true},
				{"property": &"status_name", "label": "Nom du statut", "guided": true},
				{"property": &"status_group", "label": "Groupe stable"},
				{"property": &"status_mode", "label": "Empilement"},
				{"property": &"status_damage_type", "label": "Type de dégâts"},
				{"property": &"status_element", "label": "Élément"},
				{"property": &"status_timing", "label": "Moment d'application"},
			])
		EffectType.STATUS_SLOW, EffectType.STATUS_REGEN, EffectType.STATUS_OUTGOING_DAMAGE:
			descriptor.unit = "valeur de statut"
			descriptor.duration = "durée en tours, lue par le runtime"
			descriptor.frequency = "une fois par tour pendant la durée"
			descriptor.stacking = "empilement selon Empilement : BASE crée, DELTA ajoute, OVERRIDE remplace"
			descriptor.fields.append_array([
				{"property": &"duration", "label": "Durée", "guided": true},
				{"property": &"status_name", "label": "Nom du statut", "guided": true},
				{"property": &"status_group", "label": "Groupe stable"},
				{"property": &"status_mode", "label": "Empilement"},
			])
		EffectType.STATUS_VULNERABILITY:
			# Le runtime fixe une duree de 99 quel que soit le reglage : le
			# statut dure jusqu'a epuisement des charges, pas un nombre de
			# tours. Le champ Duree serait donc accepte mais ignore ; masque.
			descriptor.unit = "valeur de statut"
			descriptor.duration = "ignorée par le runtime : le statut dure jusqu'à épuisement des charges, pas un nombre de tours"
			descriptor.frequency = "se déclenche sur les prochaines attaques reçues, jusqu'à épuisement des charges"
			descriptor.stacking = "Empilement ne modifie que la quantité ; la durée réglée ici n'a aucun effet"
			descriptor.fields.append_array([
				{"property": &"status_name", "label": "Nom du statut", "guided": true},
				{"property": &"status_group", "label": "Groupe stable"},
				{"property": &"status_mode", "label": "Empilement"},
				{"property": &"status_damage_type", "label": "Type de dégâts déclencheur"},
				{"property": &"charges", "label": "Charges", "guided": true},
				{"property": &"secondary_amount", "label": "Dégâts aux alliés adjacents", "guided": true},
			])
		EffectType.ATTACK_BUFF:
			# Meme mecanique a charges que Vulnerabilite : duree fixee en dur
			# a 99 par _apply_attack_buff(), Empilement/statuts periodiques
			# non utilises.
			descriptor.unit = "sans unité"
			descriptor.duration = "ignorée par le runtime : le bonus dure jusqu'à épuisement des charges, pas un nombre de tours"
			descriptor.frequency = "se déclenche sur les prochaines attaques du porteur, jusqu'à épuisement des charges"
			descriptor.stacking = "remplace le bonus précédent portant le même groupe stable"
			descriptor.fields.append_array([
				{"property": &"status_name", "label": "Nom du bonus", "guided": true},
				{"property": &"status_group", "label": "Groupe stable"},
				{"property": &"charges", "label": "Charges", "guided": true},
			])
	if effect_type in [2, 4, 7]:
		descriptor.condition = "cible sous threshold_ratio PV"
		descriptor.fields.append({"property": &"threshold_ratio", "label": "Seuil de PV", "guided": true})
	elif effect_type in [3, 4]:
		descriptor.condition = "attaque dans le dos"
	if effect_type in EFFECT_GROUP_AWARE_EFFECTS:
		# Le groupe stable evite qu'un empilement cumule deux fois le meme
		# bonus conditionnel sur une meme cellule ; seul DAMAGE_LOW_HP le lit.
		descriptor.fields.append({"property": &"effect_group", "label": "Groupe d'effet"})
	if effect_type in CONDITION_FLAG_AWARE_EFFECTS:
		descriptor.fields.append_array([
			{"property": &"require_backstab", "label": "Exiger une attaque dans le dos"},
			{"property": &"require_ally_target", "label": "Exiger une cible alliée"},
		])
	if effect_type == EffectType.ADJACENT_HEAL_RATIO:
		descriptor.fields.append({"property": &"ratio", "label": "Ratio partagé", "guided": true})
	if effect_type == EffectType.PUSH_EXACT or effect_type == EffectType.COLLISION_EXACT:
		# Les variantes "exactes" remplacent, elles n'additionnent jamais :
		# spell_mod_skill_tree_effect.gd fait un maxi()/override, pas un +=.
		descriptor.stacking = "remplacement — la valeur la plus haute l'emporte, jamais de cumul"
	if effect_type == EffectType.MOVE_CASTER_TO_TARGET:
		descriptor.condition = (
			"destination libre et alignement valide ; le chemin peut aussi être exigé libre"
		)
		descriptor.fields.append({
			"property": &"movement_requires_clear_path",
			"label": "Exiger un chemin dégagé",
		})
	if effect_type == EffectType.ALLOW_FREE_CELL_TARGET:
		descriptor.stacking = "booléen, sans cumul"


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
