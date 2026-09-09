class_name CatabaseMonsterEvolutionCatalog
extends RefCounted
## Authored roles and spell kits. The run factory owns depth/encounter multipliers.
## Every result owns its mutable combat resources; painted assets remain shared.

const FAMILY_PATHS := {
	&"sentinelle": "res://data/units/enemies/catabase_sentinelle_airain.tres",
	&"rejeton": "res://data/units/enemies/catabase_rejeton_braise.tres",
	&"molosse": "res://data/units/enemies/catabase_molosse_styx.tres",
	&"lamie": "res://data/units/enemies/catabase_lamie_lethe.tres",
	&"archer": "res://data/units/enemies/catabase_rejeton_braise.tres",
	&"officiant": "res://data/units/enemies/catabase_lamie_lethe.tres",
}
const ROLE_FAMILIES := {
	&"sentinelle": &"sentinelle", &"brute": &"sentinelle",
	&"rabatteur": &"sentinelle", &"porte_egide": &"sentinelle", &"executeur": &"sentinelle", &"champion": &"sentinelle",
	&"rejeton": &"rejeton", &"fondeur": &"rejeton", &"artilleur": &"rejeton", &"conducteur": &"rejeton",
	&"molosse": &"molosse", &"chasseur": &"molosse", &"deplaceur": &"molosse", &"alpha": &"molosse",
	&"lamie": &"lamie", &"tisseuse": &"lamie", &"oracle": &"lamie",
	&"archer": &"archer", &"traqueur": &"archer", &"guetteur": &"archer",
	&"officiant": &"officiant", &"guerisseur": &"officiant", &"collecteur": &"officiant", &"protecteur": &"officiant",
	&"serviteur": &"molosse", &"porteur": &"rejeton",
}
const ADVANCED_ROLES := {
	&"sentinelle": [&"rabatteur", &"porte_egide"],
	&"rejeton": [&"fondeur", &"conducteur"],
	&"molosse": [&"deplaceur", &"alpha"],
	&"lamie": [&"tisseuse", &"oracle"],
	&"archer": [&"traqueur", &"guetteur"],
	&"officiant": [&"guerisseur", &"protecteur"],
}
const GRADE_NAMES := ["Initié", "Vétéran", "Spécialiste"]


static func roles() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(ROLE_FAMILIES.keys())
	return result


static func family_for(role: StringName) -> StringName:
	return ROLE_FAMILIES.get(role, &"")


static func grade_for(node: Dictionary) -> int:
	var depth := int(node.get("depth", 2))
	return 1 if depth <= 5 else (2 if depth <= 12 else 3)


static func build_unit(role: StringName, node: Dictionary) -> UnitData:
	var family := family_for(role)
	if family == &"":
		return null
	var source := load(str(FAMILY_PATHS[family])) as UnitData
	var unit := source.duplicate(false) as UnitData
	var grade := grade_for(node)
	unit.spells = []
	unit.resistances = source.resistances.duplicate(true)
	unit.ai_profile = source.ai_profile.duplicate(true) as EnemyAIProfile
	unit.unit_id = StringName("catabase_evolution_%s_g%d" % [role, grade])
	unit.tactical_role_id = StringName("catabase_evolution_%s" % role)
	unit.ai_profile.profile_id = unit.tactical_role_id
	unit.ai_profile.normal_role_id = unit.tactical_role_id
	unit.ai_profile.marked_status_id = &"catabase_chasse"
	unit.ai_profile.chief_role_id = &""
	unit.ai_profile.commander_role_id = &""
	unit.max_ap = [4, 5, 6][grade - 1]
	unit.basic_attack_enabled = false
	unit.presentation_badge = GRADE_NAMES[grade - 1].to_upper()
	unit.progression_summary = "%s · %s" % [GRADE_NAMES[grade - 1], _family_name(family)]
	match family:
		&"sentinelle": _build_sentinelle(unit, role, grade)
		&"rejeton": _build_rejeton(unit, role, grade)
		&"molosse": _build_molosse(unit, role, grade)
		&"lamie": _build_lamie(unit, role, grade)
		&"archer": _build_archer(unit, role, grade)
		&"officiant": _build_officiant(unit, role, grade)
	if role in [&"serviteur", &"porteur"]:
		_build_minion(unit, role, grade)
	unit.active_spell_slots = maxi(1, unit.spells.size())
	unit.description = unit.presentation_summary
	unit.ai_profile.ideal_minimum_range = unit.minimum_range
	unit.ai_profile.ideal_maximum_range = unit.maximum_range
	return unit


static func scale_secondary_effects(unit: UnitData, hp_multiplier: float, attack_multiplier: float) -> void:
	# Call once on the independently built unit, with the final factory budgets.
	# Damage/shield scaling already reads the final runtime stats.
	for spell: Spell in unit.spells:
		spell.heal = maxi(0, roundi(spell.heal * hp_multiplier))
		spell.bonus_damage_if_marked = maxi(0, roundi(spell.bonus_damage_if_marked * attack_multiplier))
		if spell.applied_status != null:
			_scale_status(spell.applied_status, attack_multiplier)
		if spell.terrain_effect != null:
			spell.terrain_effect.damage = maxi(0, roundi(spell.terrain_effect.damage * attack_multiplier))
			if spell.terrain_effect.applied_status != null:
				_scale_status(spell.terrain_effect.applied_status, attack_multiplier)


static func _build_sentinelle(unit: UnitData, role: StringName, grade: int) -> void:
	unit.unit_name = ["Brute du portique", "Brute vétérane", "Rabatteur du Tartare"][grade - 1]
	unit.role = "Brute de mêlée"
	unit.max_mp = [2, 3, 4][grade - 1]
	unit.armure = [20.0, 30.0, 30.0][grade - 1]
	unit.presentation_summary = "Lente au début, elle apprend à briser l’armure puis à attirer. Gardez une issue et interrompez sa ligne de chaîne."
	if grade == 1:
		unit.spells.append(_spell("massue"))
		unit.presentation_summary = "Deux PM et une seule massue au contact. Gardez vos distances ou choisissez où recevoir sa frappe."
		return
	unit.spells.assign([_fracture(), _spell("revers")])
	if grade < 3 and role not in [&"rabatteur", &"executeur", &"champion"]:
		unit.unit_name = "Brute aux deux frappes"
		unit.presentation_summary = "Trois PM ; choisit une fracture d’armure ou un revers de zone. Ses cinq PA ne permettent qu’une frappe par activation."
		return
	unit.max_hp = 72
	if role == &"champion":
		unit.unit_name = "Champion de la dernière obole"
		unit.role = "Duel de la chaîne et du bouclier"
		unit.max_hp = 150
		unit.attack_power = 24
		unit.max_ap = 6
		unit.max_mp = 4
		var ward := _ward("egide", 0.12)
		ward.spell_name = "Égide du duelliste"
		ward.description = "Protège uniquement le champion pendant deux activations. Trois utilisations par combat."
		ward.spell_id = &"catabase_evolution_egide_champion"
		ward.aoe_shape = Spell.AoeShape.SINGLE
		ward.can_target_ally = false
		unit.spells.append(_spell("chaine"))
		unit.spells.append(ward)
		unit.presentation_summary = "Attire, brise l’armure, balaie le contact ou se protège. Ses six PA imposent un choix : chaîne et frappe, deux frappes, ou protection et attaque."
	elif role == &"porte_egide":
		unit.unit_name = "Porte-Égide"
		unit.role = "Protection de groupe"
		unit.max_hp = 90
		unit.max_mp = 2
		unit.armure = 45.0
		unit.spells.assign([_melee_push(), _ward("egide", 0.16)])
		unit.presentation_summary = "Protège ses voisins avec trois égides temporaires. Séparez la formation ou forcez-la à changer de position."
	elif role == &"executeur":
		unit.unit_name = "Exécuteur d’airain"
		unit.role = "Frappe préparée"
		unit.max_mp = 2
		unit.max_hp = 84
		unit.spells.assign([_spell("massue"), _spell("execution")])
		unit.spells[0].ap_cost = 3
		unit.presentation_summary = "Prépare une sentence de mêlée. Quittez son contact avant la résolution ; un rabatteur peut vous y ramener."
	else:
		unit.spells.append(_spell("chaine"))


static func _build_rejeton(unit: UnitData, role: StringName, grade: int) -> void:
	unit.unit_name = ["Rejeton de braise", "Rejeton de la fournaise", "Fondeur des Enfers"][grade - 1]
	unit.role = "Feu et zones"
	unit.spells.append(_legacy_spell("braise_trait", grade))
	unit.presentation_summary = "Fragile au contact. Ses feux occupent le terrain ; les molosses peuvent vous y pousser."
	if grade == 1:
		unit.presentation_summary = "Tire une braise à distance. Fragile, il doit garder deux cases entre lui et sa cible."
	elif grade == 2:
		unit.presentation_summary = "Prépare une fournaise pour sa prochaine activation. Brisez sa ligne de vue ou approchez pour l’annuler."
	if grade >= 2:
		unit.spells.append(_legacy_spell("braise_fournaise", grade))
	if grade >= 3 or (grade >= 2 and role == &"conducteur"):
		unit.max_mp = 3
		if role == &"conducteur":
			unit.unit_name = "Conducteur de la chasse"
			unit.role = "Marque pour la meute"
			unit.spells.assign([_legacy_spell("braise_trait", grade), _mark()])
			unit.presentation_summary = "Sa marque renforce les morsures des molosses pendant deux activations. Tuez le conducteur ou empêchez les bêtes d’atteindre leur cible."
		elif role == &"artilleur":
			unit.unit_name = "Artilleur de braise"
			unit.maximum_range = 7
			unit.spells[1].spell_range = 7
			unit.spells[1].damage_scaling.prowess_coefficient = 1.65
			unit.presentation_summary = "Annonce une fournaise à longue portée. Rompre la ligne de vue annule sa prochaine attaque."
		else:
			unit.spells.append(_fire_field())


static func _build_molosse(unit: UnitData, role: StringName, grade: int) -> void:
	unit.unit_name = ["Jeune molosse du Styx", "Molosse dévoreur", "Rabatteur du Styx"][grade - 1]
	unit.role = "Poursuite et déplacement"
	unit.max_mp = [4, 5, 5][grade - 1]
	unit.max_hp = [46, 48, 50][grade - 1]
	unit.spells.append(_legacy_spell("styx_morsure", grade))
	if grade >= 2:
		unit.spells.append(_legacy_spell("styx_dechirure", grade))
	if grade >= 3:
		if role == &"alpha":
			unit.unit_name = "Alpha du Styx"
			unit.max_hp = 60
			unit.spells.append(_ward("hurlement", 0.14))
		elif role == &"chasseur":
			unit.unit_name = "Dévoreur des derniers pas"
			unit.max_mp = 6
		else:
			unit.spells.append(_spell("bousculade"))
	for spell: Spell in unit.spells:
		if spell.deals_damage():
			spell.bonus_damage_status_id = &"catabase_chasse"
			spell.bonus_damage_if_marked = 3
	unit.presentation_summary = "Poursuit les cibles exposées. Ses crocs gagnent des dégâts contre la marque du Conducteur ; le rabatteur peut pousser dans les braises."
	if grade == 1:
		unit.presentation_summary = "Quatre PM et une morsure au contact. Les obstacles et les passages étroits limitent sa poursuite."
	elif grade == 2:
		unit.presentation_summary = "Cinq PM ; choisit morsure ou déchirure avec saignement. Ses crocs gagnent des dégâts contre la marque du Conducteur."
	elif role == &"alpha":
		unit.presentation_summary = "Poursuit et protège sa meute avec deux hurlements par combat. Séparez les chiens pour réduire la portée de son soutien."
	elif role == &"chasseur":
		unit.presentation_summary = "Six PM, morsure et déchirure. Protégez votre retraite et évitez de vous laisser désigner par le Conducteur."


static func _build_lamie(unit: UnitData, role: StringName, grade: int) -> void:
	unit.unit_name = ["Lamie du Léthé", "Gardienne du Léthé", "Tisseuse du Léthé"][grade - 1]
	unit.role = "Contrôle des passages"
	unit.spells.append(_legacy_spell("lethe_trait", grade))
	if grade >= 2:
		unit.spells.append(_legacy_spell("lethe_reflux", grade))
	if grade >= 3:
		if role == &"oracle":
			unit.unit_name = "Oracle des absents"
			unit.role = "Renforcement des alliés"
			unit.spells.append(_presage())
		else:
			unit.spells.append(_ice_field())
	unit.presentation_summary = "Ralentit d’un PM sans voler de tour. Utilisez un autre passage ou approchez à l’abri des lignes de vue."
	if grade == 1:
		unit.presentation_summary = "Tire un trait d’ombre à distance. Elle résiste mieux à la magie qu’aux coups physiques ; approchez derrière un couvert."
	if grade >= 3 and role == &"oracle":
		unit.presentation_summary = "Renforce l’attaque d’un allié proche. Rompre la formation ou éliminer l’oracle dissipe le présage."


static func _build_archer(unit: UnitData, role: StringName, grade: int) -> void:
	unit.unit_name = ["Tireur du passeur", "Éclaireur des roseaux", "Traqueur du passeur"][grade - 1]
	unit.role = "Tireur mobile"
	unit.max_hp = [38, 40, 42][grade - 1]
	unit.attack_power = 10
	unit.max_mp = [3, 4, 5][grade - 1]
	unit.resistances = {}
	unit.armure = 5.0
	unit.minimum_range = 2
	unit.preferred_range = 4
	unit.maximum_range = 5
	unit.spells.assign([_spell("fleche")])
	unit.spells[0].ap_cost = 4 if grade == 1 else 3
	unit.presentation_summary = "Tire puis se replace. Fermez ses sorties et exploitez les couverts pour le rejoindre."
	if grade >= 2:
		unit.spells.append(_spell("tir_proche"))
	if grade >= 3 and role == &"guetteur":
		unit.unit_name = "Guetteur des longues lignes"
		unit.role = "Tir préparé à longue portée"
		unit.max_mp = 2
		unit.minimum_range = 3
		unit.preferred_range = 6
		unit.maximum_range = 8
		unit.spells.assign([_spell("fleche"), _spell("visee")])
		unit.spells[0].minimum_range = 3
		unit.presentation_summary = "Prépare un tir très lointain. Sa faible mobilité et sa zone morte de trois cases permettent de l’approcher."
	elif grade >= 3:
		unit.minimum_range = 1
		unit.preferred_range = 3
		unit.maximum_range = 4
		unit.spells[0].spell_range = 4


static func _build_officiant(unit: UnitData, role: StringName, grade: int) -> void:
	unit.unit_name = ["Officiant des oboles", "Officiant du convoi", "Guérisseur des défunts"][grade - 1]
	unit.role = "Soutien à charges limitées"
	unit.max_hp = [40, 44, 48][grade - 1]
	unit.attack_power = 6
	unit.resist_magique = 10.0
	unit.max_mp = 3
	unit.ai_behavior = 2
	unit.ai_profile.strategy = EnemyAIProfile.Strategy.GENERIC_HEALER
	unit.ai_profile.support_heal_threshold = 0.75
	unit.minimum_range = 2
	unit.maximum_range = 4
	unit.preferred_range = 3
	var heal := _spell("soin")
	heal.max_uses_per_combat = 2 if grade == 1 else 3
	heal.heal = [12, 16, 20][grade - 1]
	heal.description = "Rend %d PV de base, une activation sur deux. %d soins par combat." % [heal.heal, heal.max_uses_per_combat]
	var bolt := _legacy_spell("lethe_trait", grade)
	bolt.spell_name = "Trait de l’officiant"
	bolt.spell_id = &"catabase_evolution_trait_officiant"
	bolt.spell_range = 4
	unit.spells.assign([bolt, heal])
	unit.presentation_summary = "Dispose de deux à trois soins pour tout le combat. Interceptez-le ou concentrez vos dégâts pour dépasser son secours."
	if grade >= 2:
		unit.spells.append(_ward("protection", 0.20))
	if grade >= 3 and role == &"protecteur":
		unit.unit_name = "Gardien des derniers voiles"
		unit.role = "Protection des alliés"
		unit.spells.assign([bolt, _ward("protection", 0.28), _ward("egide", 0.14)])
		unit.presentation_summary = "Protège un allié distant ou sa formation proche. Ses voiles expirent ; séparez les défenseurs pour réduire leur efficacité."
	elif role == &"collecteur" and grade >= 2:
		unit.unit_name = "Collecteur d’oboles"
		heal.set_meta("catabase_requires_role_nearby", &"catabase_evolution_porteur")
		heal.set_meta("catabase_support_radius", 2)
		heal.description = "Trois soins au maximum, une activation sur deux. Nécessite un porteur vivant à deux cases."
		unit.presentation_summary = "Ses trois soins nécessitent un porteur vivant à deux cases. Interceptez le convoi pour couper son soutien."


static func _build_minion(unit: UnitData, role: StringName, grade: int) -> void:
	unit.unit_name = "Porteur d’obole" if role == &"porteur" else "Jeune croc du Styx"
	unit.role = "Porteur fragile" if role == &"porteur" else "Serviteur fragile"
	unit.max_hp = 18
	unit.attack_power = 5
	unit.max_ap = 4
	unit.max_mp = 3 if role == &"porteur" else 4
	unit.armure = 0.0
	unit.resistances = {}
	unit.spells.assign([_legacy_spell("braise_trait" if role == &"porteur" else "styx_morsure", 1)])
	if role == &"serviteur":
		unit.spells[0].bonus_damage_status_id = &"catabase_chasse"
		unit.spells[0].bonus_damage_if_marked = 1
	if role == &"porteur":
		unit.spells.append(_ward("tribut", 0.45))
	unit.presentation_summary = "Peu de PV et une seule attaque par activation. Une zone bien placée peut dégager plusieurs serviteurs."
	if role == &"porteur":
		unit.presentation_summary = "Transporte un unique voile pour un allié adjacent. Interceptez-le avant qu’il atteigne le soutien."
	unit.progression_summary = "%s · Auxiliaire fragile" % GRADE_NAMES[grade - 1]


static func _spell(id: String) -> Spell:
	return _clone_spell(load("res://data/spells/enemies/catabase_%s.tres" % id) as Spell)


static func _legacy_spell(id: String, grade: int) -> Spell:
	var spell := _clone_spell(load("res://data/spells/catabase_monsters/%s.tres" % id) as Spell)
	spell.ap_cost = 4 if grade == 1 else 3
	return spell


static func _clone_spell(source: Spell) -> Spell:
	var spell := source.duplicate(false) as Spell
	spell.damage_scaling = source.damage_scaling.duplicate(true) as SpellScalingData if source.damage_scaling != null else null
	spell.shield_scaling = source.shield_scaling.duplicate(true) as SpellScalingData if source.shield_scaling != null else null
	spell.applied_status = source.applied_status.duplicate(true) as StatusData if source.applied_status != null else null
	spell.terrain_effect = source.terrain_effect.duplicate(true) as TerrainEffectData if source.terrain_effect != null else null
	spell.modifiers = []
	for modifier: SpellModifier in source.modifiers:
		spell.modifiers.append(modifier.duplicate(true) as SpellModifier)
	spell.shield_tags = source.shield_tags.duplicate()
	return spell


static func _fracture() -> Spell:
	var spell := _spell("fracture")
	var status := StatusData.new()
	status.status_id = &"catabase_armure_fendue"
	status.status_name = "Armure fendue"
	status.description = "−15 armure pendant deux activations."
	status.duration = 2
	status.stat_modifiers = {"armure": -15.0}
	status.color = Color(0.85, 0.55, 0.2)
	spell.applied_status = status
	return spell


static func _melee_push() -> Spell:
	var spell := _legacy_spell("airain_rempart", 3)
	spell.cooldown_activations = 2
	spell.initial_cooldown = 0
	return spell


static func _ward(id: String, hp_coefficient: float) -> Spell:
	var spell := _spell(id)
	spell.shield_scaling = SpellScalingData.new()
	spell.shield_scaling.max_hp_coefficient = hp_coefficient
	spell.shield_tags.assign([&"ward", &"catabase_evolution"])
	return spell


static func _mark() -> Spell:
	var spell := _spell("marque")
	var status := StatusData.new()
	status.status_id = &"catabase_chasse"
	status.status_name = "Proie désignée"
	status.description = "Les molosses gagnent des dégâts contre cette cible."
	status.duration = 2
	status.remove_when_source_dies = true
	status.color = Color(1.0, 0.45, 0.1)
	spell.applied_status = status
	spell.status_source_scoped = true
	return spell


static func _presage() -> Spell:
	var spell := _spell("presage")
	var status := StatusData.new()
	status.status_id = &"catabase_presage"
	status.status_name = "Présage meurtrier"
	status.description = "Renforce la prochaine activation offensive. Disparaît avec l’oracle."
	status.duration = 1
	status.outgoing_damage_modifier = 4
	status.remove_when_source_dies = true
	status.color = Color(0.8, 0.6, 1.0)
	spell.applied_status = status
	spell.status_source_scoped = true
	return spell


static func _fire_field() -> Spell:
	var spell := _spell("brasier")
	var effect := TerrainEffectData.new()
	effect.effect_name = "Braises de la fournaise"
	effect.description = "Inflige des dégâts de feu à l’entrée pendant deux tours."
	effect.surface_id = &"fire"
	effect.visual_terrain_id = &"lava"
	effect.color = Color(1.0, 0.35, 0.1)
	effect.trigger = TerrainEffectData.Trigger.ON_ENTER
	effect.damage = 4
	effect.element = Spell.Element.FIRE
	effect.duration = 2
	effect.cell_type = 3
	effect.dangerous_for_ai = true
	effect.ai_danger_weight = 3.0
	effect.same_surface_policy = TerrainEffectData.SameSurfacePolicy.REFRESH_DURATION
	spell.terrain_effect = effect
	return spell


static func _ice_field() -> Spell:
	var spell := _spell("givre")
	var effect := TerrainEffectData.new()
	effect.effect_name = "Givre du Léthé"
	effect.description = "Engourdit à l’entrée : −1 PM à la prochaine activation."
	effect.surface_id = &"ice"
	effect.visual_terrain_id = &"ice"
	effect.color = Color(0.45, 0.85, 0.9)
	effect.trigger = TerrainEffectData.Trigger.ON_ENTER
	effect.duration = 2
	effect.cell_type = 4
	effect.dangerous_for_ai = true
	effect.ai_danger_weight = 2.0
	effect.applied_status = load("res://data/spells/catabase_monsters/status/oubli.tres").duplicate(true) as StatusData
	effect.same_surface_policy = TerrainEffectData.SameSurfacePolicy.REFRESH_DURATION
	spell.terrain_effect = effect
	return spell


static func _scale_status(status: StatusData, multiplier: float) -> void:
	status.damage_per_turn = maxi(0, roundi(status.damage_per_turn * multiplier))
	status.outgoing_damage_modifier = roundi(status.outgoing_damage_modifier * multiplier)


static func _family_name(family: StringName) -> String:
	return str({&"sentinelle": "Airain", &"rejeton": "Braise", &"molosse": "Styx", &"lamie": "Léthé", &"archer": "Tireurs", &"officiant": "Officiants"}.get(family, family))
