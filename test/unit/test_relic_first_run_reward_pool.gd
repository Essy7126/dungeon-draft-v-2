extends GutTest

# Contrat du pool de récompenses de première run après le passage de l'éditeur
# d'objets du Studio : seules les huit reliques produites par l'assistant y
# figurent, les équipements précédemment taggés en sont sortis, et le pool
# continue de proposer deux options distinctes après une victoire.

const CATALOG_PATH := "res://data/items/catalogs/default_item_catalog.tres"
const HERO_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]

# Triés comme FirstRunEquipmentRewardService.reset() trie _eligible_ids.
const RELIC_IDS: Array[StringName] = [
	&"cendres_du_phenix",
	&"chaines_de_promethee",
	&"croc_de_cerbere",
	&"fureur_d_ares",
	&"lyre_d_orphee",
	&"plume_de_nike",
	&"sablier_de_chronos",
	&"sandales_d_hermes",
]

# Équipements qui portaient le tag avant le passage dans le Studio.
const DESELECTED_IDS: Array[StringName] = [
	&"anneau_faille",
	&"arc_maudit",
	&"broche",
	&"caillou",
	&"cape_brume",
	&"collier_sages",
	&"couronne",
	&"excalibur",
	&"hache_executeur",
	&"harnois",
	&"manteau_givre",
	&"matraque_troll",
	&"sceau",
]

var _states: Array[CharacterRunState] = []


func after_each() -> void:
	for state in _states:
		if state != null:
			state.dispose()
	_states.clear()


func test_eligible_pool_is_exactly_the_eight_studio_relics() -> void:
	var service := FirstRunEquipmentRewardService.new()
	assert_true(service.reset(_catalog(), 2026))
	var eligible: Array[StringName] = []
	for value in service.snapshot().get("eligible_ids", []) as Array:
		eligible.append(StringName(value))
	assert_eq(eligible, RELIC_IDS)


func test_every_eligible_entry_is_a_relic_carrying_the_pool_tag() -> void:
	var catalog := _catalog()
	for item_id in RELIC_IDS:
		var definition := catalog.get_definition(item_id)
		assert_not_null(definition, str(item_id))
		assert_true(definition.is_relic(), str(item_id))
		assert_true(definition.tags.has(FirstRunEquipmentRewardService.POOL_TAG), str(item_id))
		assert_eq(definition.rarity, &"common", str(item_id))
		assert_eq(definition.stack_limit, 1, str(item_id))
		assert_true(definition.compatible_character_ids.is_empty(), str(item_id))
		assert_false(definition.reactive_effects.is_empty(), str(item_id))


func test_previously_tagged_equipment_left_the_pool() -> void:
	var catalog := _catalog()
	var service := FirstRunEquipmentRewardService.new()
	assert_true(service.reset(catalog, 2026))
	var eligible := service.snapshot().get("eligible_ids", []) as Array
	for item_id in DESELECTED_IDS:
		var definition := catalog.get_definition(item_id)
		assert_not_null(definition, str(item_id))
		assert_false(
			definition.tags.has(FirstRunEquipmentRewardService.POOL_TAG),
			"%s porte encore le tag" % item_id,
		)
		assert_false(eligible.has(str(item_id)), "%s est encore éligible" % item_id)


func test_pool_offers_two_distinct_relic_options_after_a_victory() -> void:
	var catalog := _catalog()
	var service := FirstRunEquipmentRewardService.new()
	assert_true(service.reset(catalog, 1337))
	var states := _make_states()
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog, 24))
	var offered := {}
	for room_index in 4:
		var options := service.build_options(_report(room_index), states, inventory)
		assert_eq(options.size(), 2, "salle %d" % (room_index + 1))
		var first_id := StringName(options[0].get("item_id", &""))
		var second_id := StringName(options[1].get("item_id", &""))
		assert_ne(first_id, second_id, "salle %d" % (room_index + 1))
		for option in options:
			var item_id := StringName(option.get("item_id", &""))
			assert_false(offered.has(item_id), "%s proposé deux fois" % item_id)
			offered[item_id] = true
			assert_true(RELIC_IDS.has(item_id), "%s hors du pool attendu" % item_id)
			var definition := option.get("definition") as ItemDefinition
			assert_not_null(definition, str(item_id))
			assert_true(definition.is_relic(), str(item_id))


func test_a_relic_reward_is_acquired_without_targeting_a_hero() -> void:
	var catalog := _catalog()
	var service := FirstRunEquipmentRewardService.new()
	assert_true(service.reset(catalog, 7))
	var states := _make_states()
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog, 24))
	var report := _report(0)
	var options := service.build_options(report, states, inventory)
	assert_eq(options.size(), 2)
	var chosen := StringName(options[0].get("item_id", &""))
	var result := service.apply(report, chosen, &"", states, inventory)
	assert_true(result.get("success", false), str(result))
	assert_eq(result.get("target_character_id"), &"")
	assert_true(inventory.contains_definition(chosen))


func test_each_relic_passes_studio_validation_and_effect_coverage() -> void:
	var studio_catalog := ItemStudioCatalogService.new()
	assert_true(studio_catalog.rebuild().get("ok", false))
	var validation_service := ItemStudioValidationService.new()
	var definitions: Array[ItemDefinition] = []
	for item_id in RELIC_IDS:
		var definition := _catalog().get_definition(item_id)
		assert_not_null(definition, str(item_id))
		definitions.append(definition)
		var report := validation_service.validate(
			definition, studio_catalog, definition.resource_path, definition.resource_path
		)
		assert_true(report.get("valid", false), "%s : %s" % [item_id, str(report.get("messages", []))])
	var coverage := ItemEffectRegistry.new().coverage_report(definitions)
	assert_true(coverage.get("valid", false), str(coverage.get("unsupported", [])))


# ============================================================
# VARIÉTÉ D'UNE PARTIE À L'AUTRE
# ============================================================

func test_two_seeds_offer_different_relics_in_the_first_room() -> void:
	var first_pairs := {}
	for run_seed in [1337, 2026, 7, 424242, 99, 5150]:
		first_pairs[_first_room_pair(run_seed)] = true
	assert_gt(
		first_pairs.size(),
		1,
		"Deux graines différentes doivent proposer des reliques différentes",
	)


func test_the_same_seed_still_replays_the_same_offers() -> void:
	assert_eq(
		_first_room_pair(1337),
		_first_room_pair(1337),
		"Une graine fixée reste rejouable à l’identique, pour reproduire un bug",
	)


func test_a_run_draws_a_new_seed_unless_it_is_pinned() -> void:
	var run := RunData.new()
	assert_true(
		run.randomize_seed_each_run,
		"Par défaut une partie doit varier d’une fois à l’autre",
	)
	run.rooms = [load("res://data/rooms/first_run_room_02.tres") as RoomData]
	var seeds := {}
	for attempt in 6:
		assert_true(GameManager._prepare_preconfigured_run(run, HERO_PATHS))
		seeds[GameManager.get_run_seed()] = true
		GameManager.cleanup_run_state()
	assert_gt(seeds.size(), 1, "Chaque partie doit tirer sa propre graine")

	run.randomize_seed_each_run = false
	run.default_seed = 1337
	var pinned := {}
	for attempt in 3:
		assert_true(GameManager._prepare_preconfigured_run(run, HERO_PATHS))
		pinned[GameManager.get_run_seed()] = true
		GameManager.cleanup_run_state()
	assert_eq(pinned.keys(), [1337], "Un run épinglé garde exactement sa graine")


func _first_room_pair(run_seed: int) -> String:
	var service := FirstRunEquipmentRewardService.new()
	var catalog := _catalog()
	assert_true(service.reset(catalog, run_seed))
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog, 24))
	var options := service.build_options(_report(0), _make_states(), inventory)
	assert_eq(options.size(), 2, "graine %d" % run_seed)
	var ids: Array[String] = []
	for option in options:
		ids.append(str((option as Dictionary).get("item_id", &"")))
	ids.sort()
	return "|".join(ids)


func _catalog() -> ItemCatalog:
	var catalog := ResourceLoader.load(
		CATALOG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemCatalog
	assert_not_null(catalog)
	assert_true(catalog.rebuild_index())
	return catalog


func _make_states() -> Array[CharacterRunState]:
	var result: Array[CharacterRunState] = []
	for path in HERO_PATHS:
		var data := load(path) as UnitData
		var state := CharacterRunState.new()
		assert_true(state.initialize(Unit.from_data(data), data), path)
		_states.append(state)
		result.append(state)
	return result


func _report(report_index: int) -> CombatReport:
	var report := CombatReport.new()
	report.report_id = StringName("relic_pool_report_%d" % report_index)
	report.room_index = report_index
	report.victory = true
	report.finalized = true
	return report
