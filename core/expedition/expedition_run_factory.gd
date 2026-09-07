class_name ExpeditionRunFactory
extends RefCounted
## Runtime authority for canonical Catabase; authored assets remain immutable.
const PROFILE_ID: StringName = &"catabase"
const BASE_RUN := "res://data/runs/odyssey.tres"
# Hubs do not manufacture character XP. Rank follows victories.
const XP_BY_DEPTH := [100, 110, 120, 0, 130, 140, 160, 0, 180, 200, 210, 0, 230, 250, 270, 0, 280, 300, 0, 340]


static func create(seed_value: int, hero_visual_variants: Dictionary = {}) -> RunData:
	var source := load(BASE_RUN) as RunData
	var result := source.duplicate(false) as RunData
	result.hero_visual_variants = hero_visual_variants.duplicate()
	result.run_name = "Catabase"
	result.catabase_route_enabled = true
	result.default_seed = seed_value
	result.randomize_seed_each_run = false
	var classifications := CombatActionClassificationCatalogData.new()
	classifications.catalog_id = &"catabase_build_actions"
	classifications.entries.assign(source.action_classification_catalog.entries)
	classifications.entries.append_array(ExpeditionBuildCatalog.new().get_action_classifications())
	result.action_classification_catalog = classifications
	result.content_profile = source.content_profile.duplicate(false)
	result.content_profile.profile_id = PROFILE_ID
	result.content_profile.display_name = result.run_name
	result.content_profile.description = "Construisez votre voie dans les Enfers."
	result.content_profile.hero_profiles = []
	for source_hero in source.content_profile.hero_profiles:
		var hero := source_hero.duplicate(false) as RunHeroProfile
		hero.progression_profile = source_hero.progression_profile.duplicate(false)
		hero.progression_profile.combat_action_classification_catalog = classifications
		var progression := source_hero.progression_profile.champion_progression_profile.duplicate(false) as ChampionProgressionProfile
		# Only the new tree owns mastery currency. Starting stats and attributes stay canonical.
		progression.mastery_point_levels = PackedInt32Array()
		progression.purchased_mastery_cap = 0
		hero.progression_profile.champion_progression_profile = progression
		result.content_profile.hero_profiles.append(hero)
	result.economy_profile = source.economy_profile.duplicate(false)
	result.economy_profile.item_catalog = ExpeditionEquipmentCatalog.merge_into(source.economy_profile.item_catalog)
	result.economy_profile.equipment_rewards_enabled = false
	result.economy_profile.starting_currency = 0
	result.economy_profile.victory_currency_reward = 0
	result.rooms = []
	for depth in range(1, ExpeditionRouteCatalog.DEPTH_COUNT + 1):
		var room_index := int(ExpeditionRouteCatalog.MAP_BY_DEPTH.get(depth, 0))
		result.rooms.append(make_room({"depth": depth, "room_index": room_index, "title": "Étape %d" % depth, "id": "pending_%d" % depth, "kind": "normal"}, seed_value))
	return result


static func make_room(node: Dictionary, seed_value: int) -> RoomData:
	var template := ExpeditionMapCatalog.get_room(maxi(0, int(node.get("room_index", 0))))
	var room := template.duplicate(false) as RoomData
	room.room_name = str(node.get("title", template.room_name))
	room.waves = []
	var encounter := template.get_encounter_for_wave(0).duplicate(false) as EncounterDefinition
	encounter.encounter_id = StringName("catabase:%d:%s" % [seed_value, node.id])
	encounter.room_index = int(node.depth)
	encounter.base_xp = 0
	encounter.optional_xp_budget = 0
	encounter.glory_challenge = null
	encounter.roster_units = []
	var multiplier := enemy_multiplier(node)
	for data in template.get_encounter_for_wave(0).roster_units:
		var enemy := data.duplicate(false) as UnitData
		enemy.max_hp = roundi(float(data.max_hp) * multiplier)
		enemy.attack_power = roundi(float(data.attack_power) * multiplier)
		encounter.roster_units.append(enemy)
	room.encounter_definition = encounter
	room.enemies = encounter.expanded_roster()
	return room


static func enemy_multiplier(node: Dictionary) -> float:
	return (1.20 if str(node.get("kind", "")) == "elite" else 1.0) * (1.0 + float(maxi(0, int(node.depth) - 5)) * 0.07)


static func xp_for(node: Dictionary) -> int:
	if not ExpeditionRouteCatalog.is_combat(str(node.kind)):
		return 0
	return 240 if int(node.depth) == 16 else XP_BY_DEPTH[int(node.depth) - 1]


static func is_expedition(run_data: RunData) -> bool:
	return run_data != null and run_data.content_profile != null \
		and run_data.content_profile.profile_id == PROFILE_ID
