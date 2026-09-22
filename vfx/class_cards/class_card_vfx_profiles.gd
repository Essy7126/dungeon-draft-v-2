extends RefCounted
## Authored contracts. Durations are visual tails, never gameplay delays.
const Concepts := preload("class_card_vfx_concepts.gd")
const Power := preload("class_card_vfx_power.gd")
const SPELLS := {
	"a_dagger": {
		"motif": "dagger",
		"duration": .32,
		"width": 1.18,
		"flight_motif": "dagger",
		"role": "directed_hit",
	},
	"t_burn": {
		"motif": "ember",
		"duration": .68,
		"width": 1.3,
		"ranged": false,
		"role": "ignition",
	},
	"t_flamewall": {
		"motif": "ember",
		"duration": .5,
		"width": 1.15,
		"ground_motif": "pyre",
		"ranged": false,
		"role": "damaging_ground",
	},
	"t_glacier": {
		"motif": "frost",
		"duration": .58,
		"width": 1.2,
		"ground_motif": "frost_garden",
		"ranged": false,
		"role": "slowing_ground",
	},
}
const STATES := {
	"class_burn": { "motif": "ember", "width": 1.65 },
	"ecosystem_ice": { "motif": "frost", "width": 1.65 },
	"class_marked": { "motif": "brand", "variant": 2, "width": 1.65 },
	"class_slow": { "motif": "shackle", "variant": 0, "width": 1.65 },
	"class_root": { "motif": "shackle", "variant": 4, "width": 1.80 },
	"class_bleed": { "motif": "wound", "variant": 0, "width": 1.65 },
	"class_weak": { "motif": "wither", "variant": 0, "width": 1.65 },
	"class_weaken": { "motif": "wither", "variant": 0, "width": 1.65 },
	"class_disrupt": { "motif": "discord", "variant": 2, "width": 1.65 },
	"class_lure": { "motif": "discord", "variant": 0, "width": 1.65 },
	"ecosystem_stasis": { "motif": "dream", "variant": 1, "width": 1.90 },
	"ecosystem_stasis_ward": { "motif": "brand", "variant": 7, "width": 1.60 },
	"shield": { "motif": "aegis", "variant": 1, "width": 1.80 },
}
const GROUNDS := {
	"g_fault": ["fire", "fault"],
	"r_embers": ["fire", "embers"],
	"t_flamewall": ["fire", "pyre"],
	"r_caltrop": ["ice", "caltrop"],
	"t_glacier": ["ice", "frost_garden"],
}


static func apply(entry: Dictionary, id: String) -> Dictionary:
	id = id.trim_prefix("class_")
	entry.merge(SPELLS.get(id, { }), true)
	var concept: Array = Concepts.CARDS.get(id, [])
	if not concept.is_empty():
		entry.merge(
			{
				"motif": concept[0],
				"variant": concept[1],
				"duration": concept[2],
				"width": concept[3],
				"concept": concept[4],
			},
			true,
		)
	if GROUNDS.has(id):
		entry["ground_motif"] = GROUNDS[id][1]
		entry["ranged"] = false
	Power.apply(entry, id)
	return preload("cel/recipes.gd").apply(entry, id)


static func state(entry: Dictionary, id: String, data: StatusData = null) -> Dictionary:
	entry["status_id"] = id
	entry.merge(STATES.get(id, { }), true)
	# Paris receives an AP penalty, never the visual assertion of a skipped turn.
	if id == "ecosystem_stasis" and data != null and not data.skips_turn:
		entry["motif"] = "discord"
		entry["variant"] = 1
	if STATES.has(id):
		entry["duration"] = .48 if entry.get("feedback_phase", "") in ["tick", "expire", "break"] else .78
	return entry


static func ground(spell: Spell, family: String) -> String:
	if spell == null:
		return ""
	var id := str(spell.get_effective_spell_id()).trim_prefix("class_")
	# Reactions can retain the original spell while changing the active element.
	if GROUNDS.has(id) and GROUNDS[id][0] == family:
		return GROUNDS[id][1]
	return ""
