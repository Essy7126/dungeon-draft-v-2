class_name CatabaseMonsterEncounterCatalog
extends RefCounted
## Catabase route packs; source rooms and other runs retain their authored cast.
## HP/attack growth remains exclusively in ExpeditionRunFactory.

const UNIT_PATHS := {
	&"sentinelle": "res://data/units/enemies/catabase_sentinelle_airain.tres",
	&"rejeton": "res://data/units/enemies/catabase_rejeton_braise.tres",
	&"molosse": "res://data/units/enemies/catabase_molosse_styx.tres",
	&"lamie": "res://data/units/enemies/catabase_lamie_lethe.tres",
}
const RECOVERY_DEPTHS := [5, 9, 13, 17]


static func uses_monsters(node: Dictionary) -> bool:
	var depth := int(node.get("depth", 1))
	return depth > 1 and depth not in [7, 20] \
		and str(node.get("kind", "normal")) in ["normal", "elite"]


static func configure_encounter(encounter: EncounterDefinition, node: Dictionary) -> void:
	# The teaching encounter, bronze champion and final Paris fight keep their
	# established identities, placement and companion rosters, including the
	# factory's pending-room placeholders before a real route node is selected.
	if not uses_monsters(node):
		return
	var roles := composition_for(node)
	encounter.roster_units = []
	encounter.roster_counts = PackedInt32Array()
	encounter.minimum_path_distance_by_role = {}
	encounter.maximum_path_distance_by_role = {}
	encounter.shared_normal_summon_budget = 0
	encounter.shared_chief_summon_budget = 0
	encounter.disabled_ability_ids = []
	encounter.formation_profiles = formations_for(node)
	var counts := {}
	for role in roles:
		counts[role] = int(counts.get(role, 0)) + 1
	for role in counts:
		var unit := load(str(UNIT_PATHS[role])) as UnitData
		encounter.roster_units.append(unit)
		encounter.roster_counts.append(int(counts[role]))
		# Fast predators start farther away; a ranged enemy starts beyond its
		# full reach so every new pack grants an approach/cover decision.
		var minimum_distance := maxi(5, unit.max_mp + 3)
		if unit.combat_style == 1:
			minimum_distance = maxi(minimum_distance, unit.maximum_range + 1)
		encounter.minimum_path_distance_by_role[unit.tactical_role_id] = minimum_distance
		encounter.maximum_path_distance_by_role[unit.tactical_role_id] = minimum_distance + 6
	encounter.living_enemy_cap = roles.size()


static func composition_for(node: Dictionary) -> Array[StringName]:
	var depth := int(node.get("depth", 1))
	var reward := str(node.get("reward", "melee"))
	# Early rooms teach two roles. Each new region opens with a lighter pair;
	# later rooms combine three distinct threats, never stacked controllers.
	var roles: Array[StringName] = []
	match reward:
		"armor", "melee":
			roles.assign([&"sentinelle", &"rejeton"])
		"ranged", "elemental":
			roles.assign([&"rejeton", &"molosse"])
		"mobility":
			roles.assign([&"molosse", &"lamie"] if depth >= 5 else [&"molosse", &"rejeton"])
		"control", "healing", "discovery":
			roles.assign([&"lamie", &"sentinelle"] if depth >= 5 else [&"sentinelle", &"rejeton"])
		"vitality":
			roles.assign([&"sentinelle", &"molosse"])
		"signature":
			roles.assign([&"sentinelle", &"lamie"])
		_:
			roles.assign([&"sentinelle", &"rejeton"])
	if depth >= 10 and depth not in RECOVERY_DEPTHS:
		# A ranged pair receives a slow blocker; a defensive/control pair gets
		# a pursuer. A mobile pair gets a fragile shooter, not a second tank.
		if not roles.has(&"molosse"):
			roles.append(&"molosse")
		elif not roles.has(&"rejeton"):
			roles.append(&"rejeton")
		else:
			roles.append(&"sentinelle")
	return roles


static func formations_for(node: Dictionary) -> Array[StringName]:
	var formations: Array[StringName] = []
	match str(node.get("reward", "melee")):
		"armor", "melee", "vitality", "signature":
			formations.assign([&"double_line", &"line"])
		"mobility":
			formations.assign([&"left_flank", &"right_flank"])
		_:
			formations.assign([&"split", &"double_line"])
	return formations
