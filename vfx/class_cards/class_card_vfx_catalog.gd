extends RefCounted
## Presentation recipes only. The gameplay catalogue remains the source of card identity.
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const EFFECTS := {
	"hit": "slash",
	"marked": "pierce",
	"moved": "slash",
	"execute": "cleave",
	"guarded": "pierce",
	"wounded": "slash",
	"displaced": "pierce",
	"cross": "cleave",
	"mark": "mark",
	"bleed": "bleed",
	"guard": "guard",
	"move": "move",
	"blink": "shadow",
	"slow": "root",
	"push": "push",
	"pull": "pull",
	"weaken": "weaken",
	"frost": "ice",
	"ice_area": "ice",
	"fire": "fire",
	"burn": "fire",
	"lightning": "lightning",
	"shadow": "shadow",
	"root": "root",
	"disrupt": "disrupt",
	"lure": "pull",
	"stasis": "stasis",
	"fire_field": "fire",
	"ice_field": "ice",
}
const STATUSES := {
	"class_marked": "mark",
	"class_slow": "root",
	"class_bleed": "bleed",
	"class_burn": "fire",
	"class_weak": "weaken",
	"class_weaken": "weaken",
	"class_root": "root",
	"class_disrupt": "disrupt",
	"class_lure": "shadow",
	"ecosystem_stasis": "stasis",
	"ecosystem_stasis_ward": "guard",
	"ecosystem_ice": "ice",
	"catabase_braise": "fire",
	"catabase_oubli": "weaken",
	"catabase_saignement": "bleed",
	"catabase_chasse": "mark",
	"catabase_armure_fendue": "weaken",
	"catabase_presage": "mark",
	"burn": "fire",
	"frozen": "ice",
	"wet": "water",
	"poison": "poison",
	"shock": "lightning",
}
const FAMILIES := [
	"slash",
	"pierce",
	"cleave",
	"mark",
	"bleed",
	"guard",
	"move",
	"shadow",
	"root",
	"push",
	"pull",
	"weaken",
	"ice",
	"fire",
	"lightning",
	"disrupt",
	"stasis",
	"heal",
	"summon",
	"water",
	"poison",
]
const PALETTES := {
	"slash": ["a8c7ca", "edf3de"],
	"pierce": ["b7ccd0", "f0efdb"],
	"cleave": ["d5ac71", "fff0c3"],
	"mark": ["d39a60", "fae0aa"],
	"bleed": ["b43a53", "e4a0a4"],
	"guard": ["cfa152", "fae8b1"],
	"move": ["82b9b7", "d8ede0"],
	"shadow": ["8461ae", "d8bfea"],
	"root": ["85a477", "d9dab0"],
	"push": ["c0a479", "f1e2be"],
	"pull": ["a998c4", "e5d9f0"],
	"weaken": ["937b9f", "d8c4d7"],
	"ice": ["79bacc", "e2f9f5"],
	"fire": ["ff782c", "ffdfa2"],
	"lightning": ["93bbdd", "f3f0de"],
	"disrupt": ["ac83b5", "f0d3e2"],
	"stasis": ["93a6c6", "e4d9f1"],
	"heal": ["75bf9b", "d5f0c2"],
	"summon": ["78b6b0", "e0e9c6"],
	"water": ["63b8cf", "c5edf2"],
	"poison": ["91b967", "d5df96"],
}
const ENEMIES := {
	"catabase_airain_rempart": "push",
	"catabase_braise_fournaise": "fire",
	"catabase_braise_trait": "fire",
	"catabase_evolution_bousculade": "push",
	"catabase_evolution_brasier": "fire",
	"catabase_evolution_chaine": "pull",
	"catabase_evolution_egide": "guard",
	"catabase_evolution_egide_champion": "guard",
	"catabase_evolution_execution": "cleave",
	"catabase_evolution_fleche": "pierce",
	"catabase_evolution_fracture": "cleave",
	"catabase_evolution_givre": "ice",
	"catabase_evolution_hurlement": "guard",
	"catabase_evolution_marque": "mark",
	"catabase_evolution_massue": "cleave",
	"catabase_evolution_presage": "mark",
	"catabase_evolution_protection": "guard",
	"catabase_evolution_revers": "cleave",
	"catabase_evolution_soin": "heal",
	"catabase_evolution_tir_proche": "pierce",
	"catabase_evolution_trait_officiant": "shadow",
	"catabase_evolution_tribut": "guard",
	"catabase_evolution_visee": "pierce",
	"catabase_hellspawn_shadow_bolt": "shadow",
	"catabase_lethe_reflux": "weaken",
	"catabase_lethe_trait": "shadow",
	"catabase_styx_dechirure": "bleed",
	"catabase_styx_morsure": "slash",
	"ecosystem_call_servant": "summon",
	"paris_fire_arrow": "fire",
	"paris_ice_arrow": "ice",
	"paris_infernal_pull": "pull",
	"paris_infernal_sweep": "fire",
	"paris_infernal_whip": "cleave",
	"paris_spectral_arrow": "shadow",
	"paris_vortex_arrow": "pull",
	"paris_vortex_step": "shadow",
	"spectre_heavy_cleave": "cleave",
}
const COLORS := {
	"assassin": Color("dec1db"),
	"gardien": Color("efdaa5"),
	"arpenteur": Color("c5e1c2"),
	"thaumaturge": Color("bed9ed"),
}
const SIGNATURES := {
	"a_pierce": "pierce",
	"a_dagger": "pierce",
	"a_ambush": "cleave",
	"a_reap": "cleave",
	"g_hit": "cleave",
	"g_crash": "cleave",
	"g_shot": "pierce",
	"g_riposte": "cleave",
	"r_shot": "pierce",
	"r_long": "pierce",
	"r_move": "pierce",
	"r_bounty": "pierce",
	"t_hex": "shadow",
	"t_touch": "shadow",
	"s_t_hit": "shadow",
	"s_r_hit": "pierce",
}


static func recipe(id: String) -> Dictionary:
	id = id.trim_prefix("class_")
	var basic := id in ["basic_strike", "basic_guard"]
	var row := Cards.row("a_pierce" if id == "basic_strike" else "g_guard" if basic else id)
	if row.is_empty() or not EFFECTS.has(row[7]):
		return { }
	var effect: String = row[7]
	var family: String = SIGNATURES.get(id, EFFECTS[effect])
	var seed_value := absi(id.hash())
	var strength := clampf(float(row[6]) + (float(row[8]) if effect == "guard" else 0.0), .3, 1.8)
	var entry := {
		"id": id,
		"name": "Protection" if id == "basic_guard" else "Frappe simple" if basic else str(row[2]),
		"class_id": str(row[1]),
		"effect": effect,
		"family": family,
		"accent": COLORS[row[1]],
		"seed": seed_value,
		"strength": strength,
		"duration": (
			1.45 if family == "fire" else 1.1 if family in ["guard", "stasis", "shadow"] else .75
		)
		+ strength * .12,
		"width": 1.65 + strength * .24,
		"rays": 3 + seed_value % 5,
		"phase": float(seed_value % 360) * PI / 180.0,
		"ranged": int(row[5]) > 1 and float(row[6]) > 0,
		"area": effect in ["cross", "fire", "ice_area", "fire_field", "ice_field"],
		"movement": effect in ["move", "blink"],
		"basic": basic,
	}
	return preload("class_card_vfx_profiles.gd").apply(entry, id)


static func feedback(family: String, phase := "apply") -> Dictionary:
	return {
		"id": family + "_" + phase,
		"family": family,
		"effect": family,
		"accent": Color.WHITE,
		"duration": 1.45 if family in ["heal", "fire", "summon"] else .85,
		"width": 2.0 if family == "heal" else 1.45,
		"rays": 4,
		"seed": 0,
		"phase": 0.0,
		"feedback_phase": phase,
	}


static func for_spell(spell: Spell) -> Dictionary:
	if spell == null:
		return { }
	var id := str(spell.get_effective_spell_id())
	if id.begins_with("class_"):
		return recipe(id)
	var family: String = ENEMIES.get(id, "")
	# Older saved card runs share spells with Classic; the router gates by battle session.
	if family == "" and (id.begins_with("exp_") or id.begins_with("achilles_")):
		family = "slash"
		if spell.is_healing():
			family = "heal"
		elif spell.shield_grant > 0 or spell.shield_scaling != null:
			family = "guard"
		elif spell.caster_movement != Spell.CasterMovement.NONE:
			family = "move"
		elif spell.element != Spell.Element.NONE:
			family = {
				Spell.Element.FIRE: "fire",
				Spell.Element.ICE: "ice",
				Spell.Element.LIGHTNING: "lightning",
				Spell.Element.SHADOW: "shadow",
			}.get(spell.element, "pierce")
		elif spell.pull_distance > 0:
			family = "pull"
		elif spell.push_distance > 0:
			family = "push"
		elif spell.applied_status != null:
			family = "mark"
		elif spell.spell_range > 1:
			family = "pierce"
	if family == "":
		return { }
	var entry := feedback(family)
	entry.merge(
		{
			"id": id,
			"name": spell.spell_name,
			"class_id": "adversaire" if ENEMIES.has(id) else "archives Cartes",
			"seed": absi(id.hash()),
			"ranged": spell.spell_range > 1 and not spell.can_target_self,
			"area": spell.aoe_shape != Spell.AoeShape.SINGLE,
			"movement": spell.caster_movement != Spell.CasterMovement.NONE,
			"phase": float(absi(id.hash()) % 360) * PI / 180.0,
		},
		true,
	)
	return preload("cel/recipes.gd").apply(entry, id)


static func status_family(data: StatusData) -> String:
	var id := str(data.get_effective_status_id())
	if STATUSES.has(id):
		return STATUSES[id]
	# Equipment and terrain can add states beyond the current card catalogue.
	# This fallback is presentation-only and is gated to Cards by the router.
	if data.skips_turn:
		return "stasis"
	if data.heal_per_turn > 0:
		return "heal"
	if data.damage_per_turn > 0:
		if data.element == Spell.Element.FIRE:
			return "fire"
		return "poison" if data.damage_type == Spell.DamageType.MAGICAL else "bleed"
	if data.ap_reduction > 0:
		return "disrupt"
	if data.mp_reduction > 0:
		return "root"
	if not data.stat_modifiers.is_empty():
		for value in data.stat_modifiers.values():
			if float(value) < 0:
				return "weaken"
		return "guard"
	return "mark"


static func coverage() -> Dictionary:
	var missing: Array[String] = []
	var by_effect := { }
	for id in Cards.pool():
		var entry := recipe(id)
		if entry.is_empty():
			missing.append(id)
		else:
			by_effect[entry.effect] = int(by_effect.get(entry.effect, 0)) + 1
	return { "cards": Cards.pool().size(), "effects": by_effect, "missing": missing }
