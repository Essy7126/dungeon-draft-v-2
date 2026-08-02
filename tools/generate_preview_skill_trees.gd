extends Node

const EffectModifier = preload(
	"res://core/spell_mods/spell_mod_skill_tree_effect.gd"
)

const PREVIEW_PATH := "res://asset/ui/dungeon_draft/arbre_compétences/preview.html"
const THRESHOLDS := {1: 0, 2: 3, 3: 7, 4: 12, 5: 18}

# Doit rester synchronisé avec SpellModSkillTreeEffect.EffectType.
const FX := {
	"damage_all": 0, "damage_center": 1, "damage_low": 2,
	"damage_backstab": 3, "damage_backstab_or_low": 4, "range": 5,
	"heal": 6, "heal_low": 7, "shield_target": 8,
	"shield_caster_if_ally": 9, "mp_target": 10, "mp_caster": 11,
	"dot": 12, "slow": 13, "regen": 14, "vulnerability": 15,
	"outgoing": 16, "area": 17, "push_bonus": 18, "push_exact": 19,
	"collision_bonus": 20, "collision_exact": 21,
	"terrain_duration": 22, "terrain_damage": 23, "cleanse": 24,
	"adjacent_heal": 25, "shield_area": 26, "mp_area": 27,
	"attack_buff": 28, "move_caster": 29, "allow_free": 30,
	"adjacent_shield": 31, "shield_caster": 32,
}

const SCOPE := {
	"primary_enemy": 0, "primary_ally": 1, "enemies": 2,
	"allies": 3, "caster": 4,
}
const STATUS_MODE := {"base": 0, "delta": 1, "override": 2}

const TREES := [
	{
		"source": "elfe.assassin", "prefix": "elf_assassin",
		"discipline_id": &"assassin", "display": "Assassin",
		"description": "Maîtrise des frappes rapprochées et opportunistes.",
		"spell_id": &"elf_sneak_strike", "base_range": 1,
		"color": Color(0.48, 0.30, 0.64),
		"path": "res://data/characters/elf/disciplines/assassin.tres",
	},
	{
		"source": "elfe.mage", "prefix": "elf_mage",
		"discipline_id": &"mage", "display": "Mage",
		"description": "Maîtrise des explosions, du feu persistant et du contrôle de zone.",
		"spell_id": &"elf_fireball", "base_range": 14,
		"color": Color(0.90, 0.30, 0.18),
		"path": "res://data/characters/elf/disciplines/mage.tres",
	},
	{
		"source": "elfe.soigneur", "prefix": "elf_healer",
		"discipline_id": &"healer", "display": "Soigneur",
		"description": "Maîtrise des soins, de la régénération et de la protection.",
		"spell_id": &"elf_sylvan_heal", "base_range": 5,
		"color": Color(0.30, 0.72, 0.58),
		"path": "res://data/characters/elf/disciplines/healer.tres",
	},
	{
		"source": "mage.pyromancie", "prefix": "mage_pyromancy",
		"discipline_id": &"mage_pyromancy", "display": "Pyromancie",
		"description": "Maîtrise des dégâts directs, des explosions et du feu persistant.",
		"spell_id": &"mage_fireball", "base_range": 14,
		"color": Color(0.94, 0.30, 0.12),
		"path": "res://data/characters/mage/disciplines/fire.tres",
	},
	{
		"source": "mage.cryomancie", "prefix": "mage_cryomancy",
		"discipline_id": &"mage_cryomancy", "display": "Cryomancie",
		"description": "Maîtrise des obstacles, du ralentissement et du verrouillage spatial.",
		"spell_id": &"mage_ice_wall", "base_range": 6,
		"color": Color(0.35, 0.78, 1.0),
		"path": "res://data/characters/mage/disciplines/ice.tres",
	},
	{
		"source": "mage.foudromancie", "prefix": "mage_fulguromancy",
		"discipline_id": &"mage_fulguromancy", "display": "Foudromancie",
		"description": "Maîtrise des zones électriques, de l'entrave et de la conductivité.",
		"spell_id": &"mage_thunderstorm", "base_range": 5,
		"color": Color(0.63, 0.48, 1.0),
		"path": "res://data/characters/mage/disciplines/lightning.tres",
	},
	{
		"source": "mage.geomancie", "prefix": "mage_geomancy",
		"discipline_id": &"mage_geomancy", "display": "Géomancie",
		"description": "Maîtrise des impacts telluriques, de la poussée et des fractures.",
		"spell_id": &"mage_seismic_wave", "base_range": 3,
		"color": Color(0.58, 0.40, 0.20),
		"path": "res://data/characters/mage/disciplines/earth.tres",
	},
	{
		"source": "guerrier.brutalite", "prefix": "warrior_breaker",
		"discipline_id": &"warrior_breaker", "display": "Brutalité",
		"description": "Maîtrise de la frappe lourde, de l'exécution et des blessures.",
		"spell_id": &"warrior_heavy_strike", "base_range": 1,
		"color": Color(0.90, 0.28, 0.18),
		"path": "res://data/characters/warrior/disciplines/breaker.tres",
	},
	{
		"source": "guerrier.assaut", "prefix": "warrior_assault",
		"discipline_id": &"warrior_assault", "display": "Assaut",
		"description": "Maîtrise de la charge, de la mobilité et de l'impact.",
		"spell_id": &"warrior_charge", "base_range": 3,
		"color": Color(0.98, 0.48, 0.24),
		"path": "res://data/characters/warrior/disciplines/assault.tres",
	},
	{
		"source": "guerrier.furie", "prefix": "warrior_fury",
		"discipline_id": &"warrior_fury", "display": "Furie",
		"description": "Maîtrise du tourbillon, du saignement et de la projection circulaire.",
		"spell_id": &"warrior_whirlwind", "base_range": 0,
		"color": Color(0.92, 0.20, 0.18),
		"path": "res://data/characters/warrior/disciplines/fury.tres",
	},
	{
		"source": "guerrier.rempart", "prefix": "warrior_bulwark",
		"discipline_id": &"warrior_bulwark", "display": "Rempart",
		"description": "Maîtrise de la garde, du commandement et de la purification.",
		"spell_id": &"warrior_guard", "base_range": 1,
		"color": Color(0.32, 0.58, 0.82),
		"path": "res://data/characters/warrior/disciplines/bulwark.tres",
	},
]


func _ready() -> void:
	var html := FileAccess.get_file_as_string(PREVIEW_PATH)
	if html.is_empty():
		push_error("Preview illisible: %s" % PREVIEW_PATH)
		get_tree().quit(1)
		return
	var all_ok := true
	for tree in TREES:
		if not _generate_tree(html, tree):
			all_ok = false
	get_tree().quit(0 if all_ok else 1)


func _generate_tree(html: String, tree: Dictionary) -> bool:
	var nodes := _extract_nodes(html, str(tree["source"]))
	if nodes.size() != 19:
		push_error("%s: %d nodes preview, 19 attendus" % [tree["source"], nodes.size()])
		return false
	var by_rank := {1: [], 2: [], 3: [], 4: [], 5: []}
	for node in nodes:
		by_rank[int(node["rank"])].append(node)
	if [by_rank[1].size(), by_rank[2].size(), by_rank[3].size(), by_rank[4].size(), by_rank[5].size()] != [1, 2, 4, 8, 4]:
		push_error("%s: topologie preview invalide" % tree["source"])
		return false

	var discipline := DisciplineData.new()
	discipline.discipline_id = tree["discipline_id"]
	discipline.display_name = tree["display"]
	discipline.description = tree["description"]
	discipline.presentation_color = tree["color"]
	var ranks: Array[DisciplineRankData] = []
	var canonical_by_rank := {}
	var missing_effects: Array[String] = []
	for rank_number in range(1, 6):
		var rank_data := DisciplineRankData.new()
		rank_data.rank = rank_number
		rank_data.required_total_xp = THRESHOLDS[rank_number]
		var choices: Array[SkillUpgradeData] = []
		canonical_by_rank[rank_number] = []
		if rank_number > 1:
			for preview_node in by_rank[rank_number]:
				var node := _make_node(tree, preview_node, rank_number)
				choices.append(node)
				canonical_by_rank[rank_number].append(node)
				if node.spell_modifiers.is_empty():
					missing_effects.append(str(node.upgrade_id))
		rank_data.choices = choices
		ranks.append(rank_data)
	discipline.ranks = ranks
	_wire_topology(canonical_by_rank)
	if not missing_effects.is_empty():
		push_error("%s: nodes sans effet: %s" % [tree["source"], missing_effects])
		return false
	var error := ResourceSaver.save(discipline, tree["path"])
	if error != OK:
		push_error("Échec sauvegarde %s: %s" % [tree["path"], error_string(error)])
		return false
	print("GENERATED %s -> %s (19 nodes)" % [tree["source"], tree["path"]])
	return true


func _extract_nodes(html: String, source_prefix: String) -> Array[Dictionary]:
	var regex := RegEx.new()
	regex.compile("(?s)<article class=\"node[^\"]*\">.*?<span class=\"rank-label\">R([1-5])[^<]*</span><code>([^<]+)</code>.*?<h4>([^<]+)</h4>\\s*<p>([^<]+)</p>\\s*</article>")
	var result: Array[Dictionary] = []
	for match_value in regex.search_all(html):
		var preview_id := _decode_html(match_value.get_string(2))
		if not preview_id.begins_with(source_prefix + "."):
			continue
		result.append({
			"rank": int(match_value.get_string(1)),
			"preview_id": preview_id,
			"name": _decode_html(match_value.get_string(3)).strip_edges(),
			"description": _decode_html(match_value.get_string(4)).strip_edges(),
		})
	return result


func _make_node(
		tree: Dictionary,
		preview_node: Dictionary,
		rank_number: int
	) -> SkillTreeNodeData:
	var node := SkillTreeNodeData.new()
	var preview_parts := str(preview_node["preview_id"]).split(".")
	var slug := str(preview_parts[preview_parts.size() - 1])
	node.upgrade_id = StringName("%s_%s" % [tree["prefix"], slug])
	node.display_name = preview_node["name"]
	node.description = preview_node["description"]
	node.discipline_id = tree["discipline_id"]
	node.rank = rank_number
	node.target_spell_id = tree["spell_id"]
	var modifiers: Array[SpellModifier] = []
	for effect_spec in _infer_effects(tree, preview_node):
		var modifier = EffectModifier.new()
		modifier.modifier_name = node.display_name
		modifier.target_spell_id = tree["spell_id"]
		for property_name in effect_spec:
			modifier.set(property_name, effect_spec[property_name])
		modifiers.append(modifier)
	node.spell_modifiers = modifiers
	return node


func _wire_topology(by_rank: Dictionary) -> void:
	var r2: Array = by_rank[2]
	var r3: Array = by_rank[3]
	var r4: Array = by_rank[4]
	var r5: Array = by_rank[5]
	(r2[0] as SkillTreeNodeData).excluded_node_ids = [r2[1].upgrade_id]
	(r2[1] as SkillTreeNodeData).excluded_node_ids = [r2[0].upgrade_id]
	for index in range(4):
		(r3[index] as SkillTreeNodeData).prerequisite_node_ids = [
			r2[0 if index < 2 else 1].upgrade_id
		]
	for index in range(8):
		(r4[index] as SkillTreeNodeData).prerequisite_node_ids = [
			r3[index / 2].upgrade_id
		]
	for index in range(4):
		(r5[index] as SkillTreeNodeData).prerequisite_node_ids = [
			r2[0 if index < 2 else 1].upgrade_id
		]


func _infer_effects(tree: Dictionary, preview_node: Dictionary) -> Array[Dictionary]:
	var name := str(preview_node["name"])
	var description := str(preview_node["description"])
	var text := _normalize(description)
	var special := _special_effects(tree, name, text)
	if not special.is_empty():
		return special
	var effects: Array[Dictionary] = []
	var prefix := str(tree["prefix"])

	# Statuts de dégâts exacts ou de base.
	var status_kind := _status_kind(text)
	var status_values := _match_two(text, "(?:poison|saignement|brulure)\\s*:?\\s*(\\d+) degats? pendant (\\d+) tours?")
	if not status_values.is_empty():
		var mode := "base" if text.begins_with("applique") else "override"
		effects.append(_status_fx(
			FX.dot, status_values[0], status_values[1],
			prefix + "_" + status_kind, status_kind.capitalize(), mode,
			SCOPE.enemies, status_kind
		))
	var status_delta := _match_one(text, "(?:poison|saignement|brulure) inflige (?:encore )?\\+(\\d+) degats? par tour")
	if status_delta >= 0:
		effects.append(_status_fx(
			FX.dot, status_delta, 0, prefix + "_" + status_kind,
			status_kind.capitalize(), "delta", SCOPE.enemies, status_kind
		))
	var status_duration := _match_one(text, "(?:poison|saignement|brulure) dure (?:encore )?(\\d+) tour supplementaire")
	if status_duration >= 0:
		effects.append(_status_fx(
			FX.dot, 0, status_duration, prefix + "_" + status_kind,
			status_kind.capitalize(), "delta", SCOPE.enemies, status_kind
		))

	# Régénération.
	var regen_values := _match_two(text, "rend (\\d+) pv .* (\\d+) prochains tours")
	if not regen_values.is_empty():
		effects.append(_status_fx(
			FX.regen, regen_values[0], regen_values[1], prefix + "_regeneration",
			"Régénération", "base", SCOPE.primary_ally, "regen"
		))
	if text.contains("regeneration dure"):
		var regen_duration := _match_one(text, "dure (\\d+) tour supplementaire")
		effects.append(_status_fx(
			FX.regen, 0, maxi(1, regen_duration), prefix + "_regeneration",
			"Régénération", "delta", SCOPE.primary_ally, "regen"
		))
	if text.contains("regeneration rend +"):
		var regen_bonus := _match_one(text, "rend \\+(\\d+) pv")
		effects.append(_status_fx(
			FX.regen, maxi(1, regen_bonus), 0, prefix + "_regeneration",
			"Régénération", "delta", SCOPE.primary_ally, "regen"
		))

	# Vulnérabilité chargée.
	if text.contains("degats recus") or text.contains("attaque physique recue") \
			or text.contains("attaques physiques") or text.contains("brise-armure"):
		var vulnerability_amount := _first_positive_damage(text)
		var vulnerability_charges := _attack_charge_count(text)
		if vulnerability_amount > 0:
			effects.append(_vulnerability_fx(
				vulnerability_amount, vulnerability_charges,
				prefix + "_vulnerability", SCOPE.enemies
			))

	# Entrave de mouvement.
	if text.contains("pm") and (text.contains("perd") or text.contains("-")):
		var slow_amount := _negative_pm(text)
		if slow_amount > 0:
			var slow_duration := 2 if text.contains("pendant 2 tours") else 1
			effects.append(_status_fx(
				FX.slow, slow_amount, slow_duration, prefix + "_slow",
				"Entrave", "base", SCOPE.enemies, "slow"
			))

	# Portée.
	var range_bonus := _match_one(text, "\\+(\\d+) portee")
	if range_bonus >= 0:
		effects.append(_fx(FX.range, range_bonus))
	var total_range := _match_one(text, "portee totale de (\\d+) cases")
	if total_range >= 0:
		effects.append(_fx(FX.range, maxi(0, total_range - int(tree["base_range"]))))

	# Zone cardinale.
	if text.contains("zone gagne") or text.contains("zone agrandie") \
			or text.contains("cercle elargi"):
		var area_amount := _match_one(text, "zone gagne (?:encore )?(\\d+) cellule")
		effects.append(_fx(FX.area, maxi(1, area_amount)))

	# Terrain.
	if text.contains("terrain") and text.contains("dure"):
		var terrain_duration := _match_one(text, "(\\d+) tour")
		effects.append(_fx(FX.terrain_duration, maxi(1, terrain_duration)))
	if text.contains("terrain") and text.contains("degats"):
		var terrain_damage := _first_positive_damage(text)
		if terrain_damage > 0:
			effects.append(_fx(FX.terrain_damage, terrain_damage))

	# Poussée et collision.
	var push_total := _match_one(text, "poussee totale de (\\d+) cases")
	if push_total < 0:
		push_total = _match_one(text, "poussee de (\\d+) cases")
	if push_total >= 0:
		effects.append(_fx(FX.push_exact, push_total))
	elif text.contains("repousse") or text.contains("case de poussee"):
		var push_bonus := _match_one(text, "(\\d+) case")
		effects.append(_fx(FX.push_bonus, maxi(1, push_bonus)))
	if text.contains("collision"):
		var collision := _match_one(text, "(\\d+) degats(?: de collision)?")
		if collision >= 0:
			effects.append(_fx(
				FX.collision_exact if text.contains("poussee totale") else FX.collision_bonus,
				collision
			))

	# Boucliers.
	if text.contains("bouclier"):
		var shield := _match_one(text, "(\\d+) (?:points? de )?boucliers?")
		if shield >= 0:
			var shield_effect := FX.shield_target
			var scope := SCOPE.primary_ally
			if text.contains("allies presents sur la glace"):
				shield_effect = FX.shield_area
				scope = SCOPE.allies
			elif text.contains("allie adjacent"):
				shield_effect = FX.adjacent_shield
			elif text.contains("l'elfe recoit") or text.contains("le guerrier recoit"):
				shield_effect = FX.shield_caster_if_ally
			effects.append(_fx(shield_effect, shield, {"target_scope": scope}))

	# Soins immédiats.
	var heal_amount := _match_one(text, "\\+(\\d+) soins")
	if heal_amount >= 0:
		effects.append(_fx(FX.heal, heal_amount, {"target_scope": SCOPE.primary_ally}))

	# Mobilité positive.
	if text.contains("pm") and (text.contains("gagne") or text.contains("bonus de mobilite")):
		var mp_bonus := _positive_pm(text)
		if mp_bonus > 0:
			var effect := FX.mp_caster if text.contains("l'elfe") or text.contains("le guerrier") else FX.mp_target
			effects.append(_fx(effect, mp_bonus, {"target_scope": SCOPE.primary_ally}))

	# Dégâts directs : on exclut les clauses déjà traduites ci-dessus.
	_append_direct_damage_effects(effects, text)
	return _deduplicate_effects(effects)


func _special_effects(tree: Dictionary, name: String, text: String) -> Array[Dictionary]:
	var prefix := str(tree["prefix"])
	match name:
		"Dans le dos":
			return [_fx(FX.damage_backstab, 4)]
		"Exécutrice", "Exécuteur":
			return [_fx(FX.damage_low, 4, {
				"threshold_ratio": 0.40,
				"effect_group": StringName(prefix + "_execution"),
			})]
		"Coup fatal":
			return [_fx(FX.damage_low, 4, {
				"threshold_ratio": 0.50,
				"effect_group": StringName(prefix + "_execution"),
			})]
		"Repli":
			return [_fx(FX.mp_caster, 1, {"require_backstab": true})]
		"Assassinat":
			return [_fx(FX.damage_backstab_or_low, 8, {"threshold_ratio": 0.35})]
		"Décapitation":
			return [_fx(FX.damage_low, 8, {"threshold_ratio": 0.35})]
		"Lame fantôme":
			return [_fx(FX.range, 2), _fx(FX.damage_all, 3)]
		"Ouverture":
			return [_vulnerability_fx(3, 1, prefix + "_vulnerability", SCOPE.enemies)]
		"Brèche ouverte":
			return [_vulnerability_fx(2, 2, prefix + "_vulnerability", SCOPE.enemies)]
		"Fragilité glacée":
			return [_vulnerability_fx(2, 2, prefix + "_vulnerability", SCOPE.enemies)]
		"Charge persistante":
			return [_vulnerability_fx(3, 2, prefix + "_vulnerability", SCOPE.enemies)]
		"Cristallisation":
			return [_vulnerability_fx(2, 1, prefix + "_vulnerability", SCOPE.enemies)]
		"Conductivité":
			return [_vulnerability_fx(3, 1, prefix + "_vulnerability", SCOPE.enemies)]
		"Fracture":
			return [_vulnerability_fx(2, 2, prefix + "_vulnerability", SCOPE.enemies)]
		"Armure pulvérisée":
			return [_vulnerability_fx(4, 3, prefix + "_vulnerability", SCOPE.enemies)]
		"Fracture durable":
			return [_vulnerability_fx(2, 3, prefix + "_vulnerability", SCOPE.enemies)]
		"Arc secondaire":
			return [_vulnerability_fx(0, 1, prefix + "_vulnerability", SCOPE.enemies, 3)]
		"Affaiblissement":
			return [_status_fx(FX.outgoing, -2, 1, prefix + "_weakened", "Affaiblissement", "base", SCOPE.enemies, "outgoing")]
		"Double dose":
			return [_status_fx(FX.dot, 3, 2, prefix + "_poison", "Poison", "override", SCOPE.enemies, "poison")]
		"Sauveteuse":
			return [_fx(FX.heal_low, 5, {"threshold_ratio": 0.50, "target_scope": SCOPE.primary_ally})]
		"Miracle mineur":
			return [_fx(FX.heal_low, 5, {"threshold_ratio": 0.35, "target_scope": SCOPE.primary_ally})]
		"Miracle sylvestre":
			return [
				_fx(FX.heal_low, 10, {"threshold_ratio": 0.35, "target_scope": SCOPE.primary_ally}),
				_fx(FX.cleanse, 1, {"target_scope": SCOPE.primary_ally}),
			]
		"Floraison":
			return [_fx(FX.adjacent_heal, 0, {"ratio": 0.50, "target_scope": SCOPE.primary_ally})]
		"Protection partagée":
			return [_fx(FX.shield_caster_if_ally, 3, {"target_scope": SCOPE.primary_ally})]
		"Écorce vivante":
			return [
				_fx(FX.shield_target, 8, {"target_scope": SCOPE.primary_ally}),
				_fx(FX.shield_caster_if_ally, 4, {"target_scope": SCOPE.primary_ally}),
			]
		"Élan protecteur":
			return [
				_fx(FX.mp_target, 2, {"target_scope": SCOPE.primary_ally}),
				_fx(FX.shield_target, 6, {"target_scope": SCOPE.primary_ally}),
			]
		"Élan sylvestre":
			return [_fx(FX.mp_target, 2, {"target_scope": SCOPE.primary_ally})]
		"Purification", "Purification martiale":
			return [_fx(FX.cleanse, 1, {"target_scope": SCOPE.primary_ally})]
		"Supernova":
			return [_fx(FX.damage_center, 6), _fx(FX.damage_all, 3), _fx(FX.area, 1)]
		"Nova elfique":
			return [_fx(FX.damage_all, 3), _fx(FX.area, 1)]
		"Mer de flammes":
			return [_fx(FX.area, 1), _fx(FX.terrain_duration, 2), _fx(FX.terrain_damage, 3)]
		"Enfer", "Incendie sauvage":
			return [
				_status_fx(FX.dot, 3, 3, prefix + "_burn", "Brûlure", "override", SCOPE.enemies, "burn"),
				_fx(FX.terrain_duration, 2 if name == "Enfer" else 1),
			]
		"Onde explosive":
			return [_fx(FX.push_exact, 2), _fx(FX.collision_exact, 6), _fx(FX.terrain_duration, 1)]
		"Fournaise":
			return [_fx(FX.terrain_damage, 2)]
		"Mur étendu":
			return [_fx(FX.area, 1)]
		"Glace tenace", "Mur durable":
			return [_fx(FX.terrain_duration, 1)]
		"Geôlier du froid":
			return [_status_fx(FX.slow, 1, 1, prefix + "_slow", "Gel", "base", SCOPE.enemies, "slow")]
		"Glace miroir":
			return [_fx(FX.shield_area, 3, {"target_scope": SCOPE.allies})]
		"Passage sûr":
			return [_fx(FX.mp_area, 1, {"target_scope": SCOPE.allies})]
		"Point de rupture":
			return [_vulnerability_fx(4, 1, prefix + "_vulnerability", SCOPE.enemies)]
		"Forteresse gelée":
			return [_fx(FX.area, 2), _fx(FX.terrain_duration, 2)]
		"Sanctuaire de glace":
			return [
				_fx(FX.shield_area, 8, {"target_scope": SCOPE.allies}),
				_fx(FX.mp_area, 1, {"target_scope": SCOPE.allies}),
			]
		"Hiver brutal":
			return [
				_fx(FX.damage_all, 7),
				_status_fx(FX.slow, 2, 1, prefix + "_slow", "Gel profond", "base", SCOPE.enemies, "slow"),
			]
		"Prison cristalline":
			return [_fx(FX.damage_all, 5), _vulnerability_fx(4, 2, prefix + "_vulnerability", SCOPE.enemies)]
		"Paralysie complète":
			return [
				_status_fx(FX.slow, 2, 1, prefix + "_slow", "Paralysie", "base", SCOPE.enemies, "slow"),
				_status_fx(FX.dot, 3, 1, prefix + "_residual_lightning", "Électricité résiduelle", "base", SCOPE.enemies, "lightning", StatusData.PeriodicTiming.TURN_END),
			]
		"Champ statique", "Contrôleur", "Éboulement":
			return [_status_fx(FX.slow, 1, 1, prefix + "_slow", "Entrave", "base", SCOPE.enemies, "slow")]
		"Paralysie":
			return [_status_fx(FX.slow, 1, 2, prefix + "_slow", "Paralysie", "base", SCOPE.enemies, "slow")]
		"Électricité résiduelle":
			return [_status_fx(FX.dot, 2, 1, prefix + "_residual_lightning", "Électricité résiduelle", "base", SCOPE.enemies, "lightning", StatusData.PeriodicTiming.TURN_END)]
		"Orage conducteur":
			return [_vulnerability_fx(4, 2, prefix + "_vulnerability", SCOPE.enemies, 3)]
		"Cataclysme":
			return [_fx(FX.damage_all, 5), _vulnerability_fx(4, 2, prefix + "_vulnerability", SCOPE.enemies)]
		"Faille majeure":
			return [_fx(FX.range, 4), _fx(FX.damage_all, 3)]
		"Brèche profonde", "Armure fendue":
			return [_vulnerability_fx(4, 2, prefix + "_vulnerability", SCOPE.enemies)]
		"Glissement de terrain":
			return [
				_fx(FX.push_exact, 2),
				_status_fx(FX.slow, 2, 1, prefix + "_slow", "Terrain instable", "base", SCOPE.enemies, "slow"),
				_fx(FX.damage_all, 3),
			]
		"Plaie incapacitante":
			return [
				_status_fx(FX.dot, 2, 4, prefix + "_bleeding", "Saignement", "override", SCOPE.enemies, "bleeding"),
				_status_fx(FX.slow, 1, 1, prefix + "_slow", "Tendon sectionné", "base", SCOPE.enemies, "slow"),
			]
		"Intercepteur":
			return [_fx(FX.allow_free, 0)]
		"Armure d’élan":
			return [_fx(FX.shield_caster, 3)]
		"Avant-garde":
			return [_fx(FX.shield_caster, 3)]
		"Protection mobile":
			return [_fx(FX.adjacent_shield, 3)]
		"Charge tactique":
			return [_fx(FX.allow_free, 0), _fx(FX.range, 2), _fx(FX.mp_caster, 1)]
		"Avant-garde suprême":
			return [_fx(FX.range, 2), _fx(FX.shield_caster, 7)]
		"Bélier de guerre":
			return [_fx(FX.push_exact, 3), _fx(FX.damage_all, 3)]
		"Impact dévastateur":
			return [_fx(FX.damage_all, 6), _fx(FX.collision_exact, 8)]
		"Tempête d’acier":
			return [_fx(FX.damage_all, 5), _fx(FX.area, 1)]
		"Cercle élargi":
			return [_fx(FX.area, 1)]
		"Moissonneur":
			return [_status_fx(FX.dot, 3, 3, prefix + "_bleeding", "Saignement", "override", SCOPE.enemies, "bleeding")]
		"Balayage total":
			return [
				_status_fx(FX.slow, 2, 1, prefix + "_slow", "Fauchage", "base", SCOPE.enemies, "slow"),
				_fx(FX.damage_all, 3),
			]
		"Onde de choc":
			return [_fx(FX.push_exact, 3), _fx(FX.collision_exact, 6)]
		"Serment":
			return [_fx(FX.shield_caster_if_ally, 3, {"target_scope": SCOPE.primary_ally})]
		"Soutien durable":
			return [_status_fx(FX.regen, 2, 2, prefix + "_regeneration", "Régénération", "base", SCOPE.primary_ally, "regen")]
		"Serment du protecteur":
			return [
				_fx(FX.shield_target, 7, {"target_scope": SCOPE.primary_ally}),
				_fx(FX.shield_caster_if_ally, 7, {"target_scope": SCOPE.primary_ally}),
			]
		"Ordre d’assaut":
			return [_attack_buff_fx(prefix, 2)]
		"Commandement":
			return [_attack_buff_fx(prefix, 4)]
		"Ordre de guerre":
			return [_fx(FX.mp_target, 2, {"target_scope": SCOPE.primary_ally}), _attack_buff_fx(prefix, 4)]
		"Nettoyage complet":
			return [_fx(FX.cleanse, 2, {"target_scope": SCOPE.primary_ally})]
		"Protection absolue":
			return [_fx(FX.shield_target, 6, {"target_scope": SCOPE.primary_ally}), _fx(FX.cleanse, 99, {"target_scope": SCOPE.primary_ally})]
		_:
			return []


func _append_direct_damage_effects(effects: Array[Dictionary], text: String) -> void:
	if text.contains("collision") or text.contains("degats recus") \
			or text.contains("attaque physique recue") \
			or text.contains("poison") or text.contains("saignement") \
			or text.contains("brulure") or text.contains("terrain"):
		return
	var center := _match_one(text, "\\+(\\d+) degats[^.]*?(?:centre|cellule centrale)")
	if center >= 0:
		effects.append(_fx(FX.damage_center, center))
	var all_damage := _match_one(text, "\\+(\\d+) degats[^.]*?(?:toutes les cibles|degats de zone|cibles de la ligne)")
	if all_damage >= 0:
		effects.append(_fx(FX.damage_all, all_damage))
	if center >= 0 or all_damage >= 0:
		return
	var creation_damage := _match_one(text, "(?:inflige )?(\\d+) degats[^.]*?(?:lors de la creation|aux ennemis presents)")
	if creation_damage >= 0:
		effects.append(_fx(FX.damage_all, creation_damage))
		return
	var direct := _match_one(text, "\\+(\\d+) degats")
	if direct >= 0:
		effects.append(_fx(FX.damage_all, direct))


func _fx(effect_type: int, value: int = 0, extra: Dictionary = {}) -> Dictionary:
	var result := {"effect_type": effect_type, "amount": value}
	for key in extra:
		result[key] = extra[key]
	return result


func _status_fx(
		effect_type: int,
		value: int,
		status_duration: int,
		group: String,
		display_name: String,
		mode: String,
		scope: int,
		kind: String,
		timing: int = StatusData.PeriodicTiming.TURN_START
	) -> Dictionary:
	var damage_type := Spell.DamageType.MAGICAL
	var element := Spell.Element.NONE
	if kind == "bleeding":
		damage_type = Spell.DamageType.PHYSICAL
	elif kind == "burn":
		element = Spell.Element.FIRE
	elif kind == "lightning":
		element = Spell.Element.LIGHTNING
	return _fx(effect_type, value, {
		"duration": status_duration,
		"status_group": StringName(group),
		"status_name": display_name,
		"status_mode": STATUS_MODE[mode],
		"target_scope": scope,
		"status_damage_type": damage_type,
		"status_element": element,
		"status_timing": timing,
	})


func _vulnerability_fx(
		value: int,
		uses: int,
		group: String,
		scope: int,
		splash_damage: int = 0
	) -> Dictionary:
	return _fx(FX.vulnerability, value, {
		"secondary_amount": splash_damage,
		"charges": maxi(1, uses),
		"duration": 99,
		"status_group": StringName(group),
		"status_name": "Vulnérabilité physique",
		"status_mode": STATUS_MODE.base,
		"target_scope": scope,
		"status_damage_type": Spell.DamageType.PHYSICAL,
	})


func _attack_buff_fx(prefix: String, value: int) -> Dictionary:
	return _fx(FX.attack_buff, value, {
		"charges": 1,
		"status_group": StringName(prefix + "_attack_order"),
		"status_name": "Ordre d'assaut",
		"target_scope": SCOPE.primary_ally,
	})


func _deduplicate_effects(effects: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for effect in effects:
		var key := JSON.stringify(effect)
		if not seen.has(key):
			seen[key] = true
			result.append(effect)
	return result


func _status_kind(text: String) -> String:
	if text.contains("poison"):
		return "poison"
	if text.contains("saignement"):
		return "bleeding"
	return "burn"


func _attack_charge_count(text: String) -> int:
	var count := _match_one(text, "(?:les |aux )?(\\d+) prochaines attaques")
	return count if count > 0 else 1


func _negative_pm(text: String) -> int:
	var value := _match_one(text, "-(\\d+) pm")
	if value < 0:
		value = _match_one(text, "perd (\\d+) pm")
	return value


func _positive_pm(text: String) -> int:
	var value := _match_one(text, "\\+(\\d+) pm")
	if value < 0:
		value = _match_one(text, "gagne (\\d+) pm")
	return value


func _first_positive_damage(text: String) -> int:
	var value := _match_one(text, "\\+(\\d+) degats")
	if value < 0:
		value = _match_one(text, "(?:inflige |subissent )(\\d+) degats")
	return value


func _match_one(text: String, pattern: String) -> int:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return -1
	var found := regex.search(text)
	return int(found.get_string(1)) if found != null else -1


func _match_two(text: String, pattern: String) -> Array:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return []
	var found := regex.search(text)
	return [int(found.get_string(1)), int(found.get_string(2))] if found != null else []


func _normalize(value: String) -> String:
	var text := value.to_lower()
	for pair in [
		["à", "a"], ["â", "a"], ["ä", "a"], ["é", "e"], ["è", "e"],
		["ê", "e"], ["ë", "e"], ["î", "i"], ["ï", "i"], ["ô", "o"],
		["ö", "o"], ["ù", "u"], ["û", "u"], ["ü", "u"], ["ç", "c"],
		["œ", "oe"], ["’", "'"], ["−", "-"],
	]:
		text = text.replace(pair[0], pair[1])
	return text


func _decode_html(value: String) -> String:
	return value.replace("&amp;", "&").replace("&lt;", "<").replace(
		"&gt;", ">"
	).replace("&quot;", "\"").replace("&#39;", "'").replace("&nbsp;", " ")
