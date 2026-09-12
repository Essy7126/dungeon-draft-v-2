extends RefCounted
## Destination-owned opening encounters. Uses existing monster roles and visuals;
## all tuning is applied to independent runtime resources, before depth scaling.
const PACKS := {
	"La sente des oliviers": [
		"Les braises du puits",
		["rejeton", "fondeur"],
		"puits",
		1.10,
		0.85,
		"split",
	],
	"Les guetteurs du bosquet": [
		"La cendre et la fournaise",
		["conducteur", "fondeur"],
		"puits",
		1.05,
		0.90,
		"split",
	],
	"La garde des sources": [
		"Les sources incandescentes",
		["rejeton", "fondeur", "conducteur"],
		"puits",
		0.78,
		0.70,
		"double_line",
	],
	"Le portique des oboles": [
		"Le bouclier et le trait",
		["brute", "archer"],
		"porte",
		1.0,
		0.90,
		"double_line",
	],
	"Les percepteurs d'airain": [
		"La garde du péage",
		["brute", "archer", "archer"],
		"porte",
		0.85,
		0.78,
		"double_line",
	],
	"Les traces du Léthé": [
		"Les crocs et le secours",
		["molosse", "officiant"],
		"barque",
		1.15,
		0.90,
		"double_line",
	],
	"Les lances oubliées": [
		"Les deux rives du convoi",
		["molosse", "molosse", "officiant"],
		"barque",
		0.85,
		0.75,
		"split",
	],
	"Le gué des serments": [
		"La garde des braises",
		["brute", "fondeur"],
		"confluence",
		0.95,
		0.90,
		"double_line",
	],
	"Les roseaux du tireur": [
		"Le secours des roseaux",
		["molosse", "officiant", "archer"],
		"barque",
		0.85,
		0.75,
		"split",
	],
	"L'atrium des cendres": [
		"L'enclume et la fournaise",
		["brute", "fondeur", "archer"],
		"confluence",
		0.85,
		0.78,
		"double_line",
	],
	"Les gardiens du foyer": [
		"Les voix de la fournaise",
		["conducteur", "fondeur", "rejeton"],
		"puits",
		0.90,
		0.78,
		"split",
	],
	"Les duellistes du gué": [
		"Le dernier secours du passeur",
		["molosse", "molosse", "officiant"],
		"barque",
		0.95,
		0.80,
		"double_line",
	],
}
const HINTS := {
	"puits": [
		"Des braises à distance et une fournaise annoncée ; la cendre peut réduire les PM.",
		"La fournaise suit sa cible : cassez la ligne de vue ou entrez dans sa zone morte avant la résolution. Aucun retrait de PA.",
	],
	"porte": [
		"Une sentinelle déplaçable couvre des tireurs physiques fragiles.",
		"Séparez les voisins pour limiter ses deux égides, ou contournez la sentinelle et engagez les tireurs à une case.",
	],
	"barque": [
		"Des crocs poursuivent Achille pendant qu'un officiant dépense ses deux secours.",
		"Concentrez vos dégâts ou atteignez le soigneur. Ses deux soins exigent un allié et ne reviennent jamais.",
	],
	"confluence": [
		"Une garde physique accompagne une fournaise annoncée.",
		"Déplacez le garde pour ouvrir un passage ; approchez le lanceur ou rompez sa ligne pendant sa préparation.",
	],
}


static func preview(node: Dictionary) -> Dictionary:
	var title := str(node.get("title", ""))
	if int(node.get("depth", 0)) not in [2, 3, 5, 6] or not PACKS.has(title):
		return { }
	var entry: Array = PACKS[title]
	var roles: Array[StringName] = []
	for role: String in entry[1]:
		roles.append(StringName(role))
	var hint: Array = HINTS[entry[2]]
	return {
		"name": entry[0],
		"count": roles.size(),
		"roles": roles,
		"summary": hint[0],
		"counterplay": hint[1],
		"hp_factor": entry[3],
		"attack_factor": entry[4],
		"formations": [StringName(entry[5])],
		"biome": entry[2],
		"mp_cap": 0,
	}


static func tune(unit: UnitData, role: StringName, node: Dictionary) -> void:
	var pack := preview(node)
	if pack.is_empty():
		return
	# Early fights teach displacement before later ranks gain anchoring.
	unit.first_forced_movement_reduction_per_activation = 0
	if role == &"brute":
		unit.armure = 10.0
		unit.max_mp = 2
		unit.spells.resize(1)
		unit.spells[0].ap_cost = unit.max_ap
		var ward := load("res://data/spells/enemies/catabase_egide.tres").duplicate(true) as Spell
		ward.spell_id = &"catabase_early_egide"
		ward.spell_name = "Égide du portique"
		ward.ap_cost = unit.max_ap
		ward.max_uses_per_combat = 2
		ward.shield_grant = 0
		ward.shield_scaling = SpellScalingData.new()
		ward.shield_scaling.max_hp_coefficient = 0.20
		ward.description = "Protège le lanceur et ses alliés adjacents pour deux activations : 20 % des PV max du lanceur. Deux usages par combat, trois activations entre usages. Remplace sa frappe ce tour."
		unit.spells.append(ward)
		unit.presentation_summary = "Deux PM ; choisit entre frapper et protéger ses voisins. Deux égides par combat. Attirez ou repoussez la sentinelle pour séparer sa formation."
	elif role == &"archer":
		unit.max_mp = 2
		unit.spells.resize(1)
		unit.spells[0].ap_cost = unit.max_ap
		unit.presentation_summary = "Un tir physique par activation, à deux cases minimum. Ses deux PM permettent de le rejoindre ; le contact bloque son tir."
	elif role in [&"rejeton", &"fondeur", &"conducteur"]:
		unit.max_mp = 2
		unit.maximum_range = 5
		unit.spells.resize(1)
		unit.spells[0].ap_cost = unit.max_ap
		unit.spells[0].spell_range = 5
		if role == &"fondeur":
			var prepared := load("res://data/spells/catabase_monsters/braise_fournaise.tres").duplicate(
				true
			) as Spell
			prepared.spell_id = &"catabase_early_fournaise"
			prepared.spell_name = "Fournaise du puits"
			prepared.ap_cost = unit.max_ap
			prepared.spell_range = 5
			prepared.damage_scaling.prowess_coefficient = 1.80
			prepared.applied_status = null
			prepared.description = "Prépare un impact de feu à la prochaine activation, sans brûlure persistante. Suit la cible à 2–5 cases avec ligne de vue ; sortir de portée ou casser la ligne annule le coup. La résolution consomme l'activation."
			unit.spells.append(prepared)
			unit.presentation_summary = "Prépare une fournaise puis consacre sa prochaine activation à sa résolution. Deux PM ; cassez sa ligne ou approchez à une case."
		elif role == &"conducteur":
			var cinder := unit.spells[0].duplicate(true) as Spell
			cinder.spell_id = &"catabase_early_cendre"
			cinder.spell_name = "Cendre entravante"
			cinder.damage_scaling.prowess_coefficient = 0.65
			cinder.cooldown_activations = 3
			cinder.initial_cooldown = 1
			var slow := StatusData.new()
			slow.status_id = &"catabase_early_cendre"
			slow.status_name = "Cendre aux pieds"
			slow.duration = 1
			slow.mp_reduction = 1
			slow.description = "−1 PM à la prochaine activation. Aucun retrait de PA."
			cinder.applied_status = slow
			cinder.description = "Trait de feu affaibli et −1 PM à la prochaine activation. Une activation initiale d'attente, puis trois activations entre usages."
			unit.spells.append(cinder)
			unit.presentation_summary = "Une attaque par activation. La cendre retire un PM et revient toutes les trois activations ; elle prépare les lignes du fondeur."
	elif role == &"molosse":
		unit.max_mp = 3
		unit.spells.resize(1)
		unit.spells[0].ap_cost = unit.max_ap
		unit.presentation_summary = "Trois PM, une morsure physique. Isolez-le du soigneur et utilisez Garde pour absorber ses crocs."
	elif role == &"officiant":
		unit.max_mp = 2
		unit.spells.resize(2)
		for spell: Spell in unit.spells:
			spell.ap_cost = unit.max_ap
			if spell.is_healing():
				spell.max_uses_per_combat = 2
				spell.can_target_self = false
				spell.heal = 10
				spell.description = "Soigne un allié blessé à quatre cases maximum. Deux usages par combat, une activation sur deux ; ne peut pas se soigner."
		unit.presentation_summary = "Deux soins pour ses alliés, jamais pour lui-même. Choisit entre soigner et attaquer ; deux PM."
	unit.active_spell_slots = unit.spells.size()
	unit.description = unit.presentation_summary
	unit.ai_profile.ideal_minimum_range = unit.minimum_range
	unit.ai_profile.ideal_maximum_range = unit.maximum_range
