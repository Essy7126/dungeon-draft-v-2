extends GutTest

const Factory = preload("res://test/support/factory.gd")
const Cleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
const RelicResults = preload("res://items/catabase_relic_results.gd")
const ACHILLES: UnitData = preload("res://data/units/allies/achilles.tres")

var fields: Array = []
var managers: Array = []


class Manager:
	extends "res://core/game_manager.gd"
	var battles := 0


	func start_next_battle() -> void:
		battles += 1


	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func _manager() -> Manager:
	var manager := Manager.new()
	manager.expedition_save_path = "user://ct_scaling_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	managers.append(manager)
	return manager


func _field():
	var field = Factory.make_battlefield(10, 6)
	fields.append(field)
	return field


func _scaled_hero(prowess := 100.0, max_hp := 600.0) -> Unit:
	var hero := Factory.make_unit("Achille", 0)
	hero.attack_power.base_value = prowess
	hero.max_hp.base_value = max_hp
	hero.current_hp = roundi(max_hp)
	CatabaseCombatModifier.reset_actor(hero, 1)
	return hero


func after_each() -> void:
	for field in fields:
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
	fields.clear()
	for manager in managers:
		manager.cleanup_run_state()
		ExpeditionSaveService.remove_snapshot(manager.expedition_save_path)
		manager.queue_free()
	managers.clear()
	await get_tree().process_frame


func test_revision_one_freezes_urne_and_coupe_caps_at_combat_entry() -> void:
	var hero := _scaled_hero()
	assert_eq(CatabaseCombatModifier.bronze_cap(hero), 220)
	assert_eq(CatabaseCombatModifier.bronze_spend_cap(hero), 165)
	assert_eq(CatabaseCombatModifier.healing_cap(hero), 60)
	assert_eq(hero.get_meta("ct_healing"), 60)
	assert_eq(RelicResults.plaque_guard_amount(hero), 60)
	hero.attack_power.base_value = 200
	hero.max_hp.base_value = 1000
	assert_eq(CatabaseCombatModifier.bronze_cap(hero), 220, "Cap frozen at entry")
	assert_eq(CatabaseCombatModifier.bronze_spend_cap(hero), 165, "Spend frozen at entry")
	assert_eq(CatabaseCombatModifier.healing_cap(hero), 60, "Healing frozen at entry")

	var legacy := Factory.make_unit("Legacy", 0)
	legacy.attack_power.base_value = 100
	legacy.max_hp.base_value = 600
	CatabaseCombatModifier.reset_actor(legacy)
	assert_eq(CatabaseCombatModifier.bronze_cap(legacy), 40)
	assert_eq(CatabaseCombatModifier.bronze_spend_cap(legacy), 30)
	assert_eq(CatabaseCombatModifier.healing_cap(legacy), 30)
	assert_eq(RelicResults.plaque_guard_amount(legacy), 24)

	var low_level := _scaled_hero(18, 110)
	assert_eq(RelicResults.plaque_guard_amount(low_level), 24)

	var catalog := ExpeditionEquipmentCatalog.merge_into(null)
	CatabasePreparationCatalog.contextualize_item_descriptions(catalog, 0)
	assert_string_contains(
		catalog.get_definition(&"ct_relic_urne").description,
		"maximum 40",
	)
	assert_string_contains(
		catalog.get_definition(&"ct_supply_plaque").description,
		"24 garde",
	)
	CatabasePreparationCatalog.contextualize_item_descriptions(catalog, 1)
	assert_string_contains(
		catalog.get_definition(&"ct_relic_urne").description,
		"220 % Prouesse",
	)
	assert_string_contains(
		catalog.get_definition(&"ct_supply_plaque").description,
		"10 % PV max",
	)


func test_salve_scales_at_cast_and_keeps_each_mutation_ratio() -> void:
	var field = _field()
	var hero := _scaled_hero()
	field.grid.place_unit(hero, Vector2i(1, 2))
	var catalog := ExpeditionBuildCatalog.new()
	var cases := {
		"exp_ct_salve": [33, 3, 99],
		"exp_ct_salve_a": [28, 5, 140],
		"exp_ct_salve_b": [44, 3, 132],
	}
	for spell_id in cases:
		hero.start_turn()
		hero.clear_shield()
		var report: Dictionary = field.caster.cast(
			hero,
			catalog.get_spell(spell_id),
			hero.grid_pos,
		)
		assert_false(report.get("failed", false), spell_id)
		var shields := hero.get_shield_instances_snapshot()
		assert_eq(shields.size(), 1, spell_id)
		assert_eq(shields[0].get("max_absorption_per_hit"), cases[spell_id][0], spell_id)
		assert_eq(shields[0].get("remaining_impacts"), cases[spell_id][1], spell_id)
		assert_eq(hero.current_shield, cases[spell_id][2], spell_id)

	hero.attack_power.base_value = 200
	hero.start_turn()
	hero.clear_shield()
	field.caster.cast(hero, catalog.get_spell("exp_ct_salve"), hero.grid_pos)
	assert_eq(
		hero.get_shield_instances_snapshot()[0].get("max_absorption_per_hit"),
		66,
		"Salve reads Prouesse when cast, unlike entry-frozen reserves",
	)


func test_braise_ticks_scale_per_form_without_rewriting_old_surfaces() -> void:
	var field = _field()
	var hero := _scaled_hero()
	field.grid.place_unit(hero, Vector2i(1, 2))
	var catalog := ExpeditionBuildCatalog.new()
	var cases := {
		"exp_ct_braise": [15, 2],
		"exp_ct_braise_a": [25, 3],
		"exp_ct_braise_b": [15, 1],
	}
	var column := 2
	for spell_id in cases:
		hero.start_turn()
		var cell := Vector2i(column, 2)
		column += 1
		var report: Dictionary = field.caster.cast(hero, catalog.get_spell(spell_id), cell)
		assert_false(report.get("failed", false), spell_id)
		var effect: TerrainEffectData = field.terrain.get_effect_data(cell)
		assert_not_null(effect, spell_id)
		assert_eq(effect.damage, cases[spell_id][0], spell_id)
		assert_eq(field.terrain.get_remaining_duration(cell), cases[spell_id][1], spell_id)

	var first_effect: TerrainEffectData = field.terrain.get_effect_data(Vector2i(2, 2))
	hero.attack_power.base_value = 200
	hero.start_turn()
	field.caster.cast(hero, catalog.get_spell("exp_ct_braise"), Vector2i(5, 2))
	assert_eq(field.terrain.get_effect_data(Vector2i(5, 2)).damage, 30)
	assert_eq(first_effect.damage, 15, "A later buff does not rewrite an active braise")


func test_conduction_is_elemental_only_in_revision_one_and_legacy_stays_global() -> void:
	var modern_unit := Unit.from_data(ACHILLES)
	modern_unit.set_meta("ct_balance_revision", 1)
	var modern_state := CharacterRunState.new()
	assert_true(modern_state.initialize(modern_unit, ACHILLES))
	var modern_build := ExpeditionBuildState.new()
	assert_true(modern_build.initialize(modern_state))
	var modern_base := modern_unit.attack_power.get_value()
	modern_build.unlocked_node_ids.append("elements.liaison_b")
	modern_build._apply_stats()
	assert_almost_eq(modern_unit.attack_power.get_value(), modern_base, 0.001)

	var legacy_unit := Unit.from_data(ACHILLES)
	var legacy_state := CharacterRunState.new()
	assert_true(legacy_state.initialize(legacy_unit, ACHILLES))
	var legacy_build := ExpeditionBuildState.new()
	assert_true(legacy_build.initialize(legacy_state))
	var legacy_base := legacy_unit.attack_power.get_value()
	legacy_build.unlocked_node_ids.append("elements.liaison_b")
	legacy_build._apply_stats()
	assert_almost_eq(legacy_unit.attack_power.get_value(), legacy_base * 1.08, 0.001)

	var field = _field()
	var hero := _scaled_hero()
	hero.set_meta("ct_conduction", true)
	var enemy := Factory.make_unit("Cible", 1)
	enemy.max_hp.base_value = 1000
	enemy.current_hp = 1000
	field.grid.place_unit(hero, Vector2i(1, 2))
	field.grid.place_unit(enemy, Vector2i(2, 2))
	var catalog := ExpeditionBuildCatalog.new()
	hero.start_turn()
	var before := enemy.current_hp
	field.caster.cast(hero, catalog.get_spell("exp_ct_braise"), enemy.grid_pos)
	assert_eq(before - enemy.current_hp, 76, "+8 % applies to the elemental Prouesse term")
	assert_eq(field.terrain.get_effect_data(enemy.grid_pos).damage, 16)
	enemy.current_hp = 1000
	hero.start_turn()
	before = enemy.current_hp
	field.caster.cast(hero, catalog.get_spell("exp_ct_taille"), enemy.grid_pos)
	assert_eq(before - enemy.current_hp, 115, "Physical action receives no Conduction bonus")
	modern_state.dispose()
	legacy_state.dispose()


func test_conduction_roundtrip_preserves_legacy_and_revision_six_contracts() -> void:
	for catalog_revision in [5, 6]:
		var manager := _manager()
		assert_true(manager.start_expedition(6100 + catalog_revision, { }, false, true))
		if catalog_revision == 5:
			manager.expedition = ExpeditionSession.new()
			manager.expedition.initialize(
				manager.get_character_state(&"achilles"),
				manager.run_seed,
				"normal",
				catalog_revision,
			)
			# This branch deliberately replaces the revision-six session created by
			# start_expedition. Production legacy runs reach this state through the
			# restore service, which also contextualizes the generated item catalog.
			CatabasePreparationCatalog.contextualize_item_descriptions(
				manager.item_catalog,
				manager.expedition.route.get_balance_revision(),
			)
			manager.expedition.needs_preparation = true
		assert_true(
			manager.confirm_catabase_preparation(
				CatabasePreparationCatalog.preset("hampe")
			).get("success", false),
			"revision %d preparation" % catalog_revision,
		)
		var salve_description := manager.expedition.build.catalog.get_spell(
			"exp_ct_salve"
		).description
		assert_eq(salve_description.contains("33 %"), catalog_revision == 6)
		assert_true(manager.expedition.combat_won())
		_resolve_level(manager)
		var unit: Unit = manager.expedition.character.unit
		var before_conduction := unit.attack_power.get_value()
		assert_true(manager.purchase_expedition_technique("elements.learn_b").success)
		assert_true(manager.purchase_expedition_technique("elements.liaison_b").success)
		var conduction: Dictionary = manager.expedition.build.get_offers().filter(
			func(offer: Dictionary): return str(offer.id) == "elements.liaison_b"
		)[0]
		assert_eq(str(conduction.description).contains("uniquement"), catalog_revision == 6)
		var expected := (
			before_conduction * 1.08 if catalog_revision == 5 else before_conduction
		)
		assert_almost_eq(unit.attack_power.get_value(), expected, 0.001)
		assert_eq(
			manager.expedition.build.catalog.get_spell("exp_ct_salve").description.contains(
				"33 %"
			),
			catalog_revision == 6,
		)
		var urne := manager.item_catalog.get_definition(&"ct_relic_urne")
		assert_not_null(urne)
		if urne != null:
			assert_eq(urne.description.contains("220 %"), catalog_revision == 6)
		var snapshot: Dictionary = JSON.parse_string(
			JSON.stringify(manager.get_expedition_snapshot())
		)
		assert_true(manager.restore_expedition_snapshot(snapshot))
		unit = manager.expedition.character.unit
		assert_eq(
			int(unit.get_meta("ct_balance_revision", -1)),
			0 if catalog_revision == 5 else 1,
		)
		assert_almost_eq(unit.attack_power.get_value(), expected, 0.001)
		assert_eq(
			manager.expedition.build.catalog.get_spell("exp_ct_salve").description.contains(
				"33 %"
			),
			catalog_revision == 6,
		)
		var restored_urne := manager.item_catalog.get_definition(&"ct_relic_urne")
		assert_not_null(restored_urne)
		if restored_urne != null:
			assert_eq(restored_urne.description.contains("220 %"), catalog_revision == 6)


func test_urne_spends_frozen_bronze_and_repercussion_converts_real_spend() -> void:
	var field = _field()
	var hero := _scaled_hero()
	var enemy := Factory.make_unit("Cible", 1)
	enemy.max_hp.base_value = 1000
	enemy.current_hp = 1000
	field.grid.place_unit(hero, Vector2i(1, 2))
	field.grid.place_unit(enemy, Vector2i(2, 2))
	var effect := ItemReactiveEffectData.new()
	effect.result_id = &"ct_bronze"
	assert_true(RelicResults.apply(effect, hero, {
		"damage_source": enemy,
		"guard_absorbed": true,
		"source_absorption": [{"tags": [&"guard"], "amount_absorbed": 500}],
	}, null, null))
	assert_eq(hero.get_meta("ct_bronze"), 220)

	hero.start_turn()
	var before := enemy.current_hp
	var catalog := ExpeditionBuildCatalog.new()
	field.caster.cast(hero, catalog.get_spell("exp_ct_repercussion"), enemy.grid_pos)
	assert_eq(hero.get_meta("ct_bronze"), 55)
	assert_eq(before - enemy.current_hp, 248, "round(165 × 150 %) real bronze")


func test_coupe_uses_real_physical_hp_damage_and_debits_real_healing() -> void:
	var field = _field()
	var hero := _scaled_hero()
	hero.set_meta("ct_relic_4", true)
	var enemy := Factory.make_unit("Cible", 1)
	enemy.max_hp.base_value = 1000
	enemy.current_hp = 1000
	field.grid.place_unit(hero, Vector2i(1, 2))
	field.grid.place_unit(enemy, Vector2i(2, 2))
	var catalog := ExpeditionBuildCatalog.new()

	hero.current_hp = 599
	hero.start_turn()
	field.caster.cast(hero, catalog.get_spell("exp_ct_taille"), enemy.grid_pos)
	assert_eq(hero.current_hp, 600)
	assert_eq(hero.get_meta("ct_healing"), 59, "Only effective healing is debited")

	hero.current_hp = 100
	enemy.current_hp = 10
	hero.start_turn()
	field.caster.cast(hero, catalog.get_spell("exp_ct_taille"), enemy.grid_pos)
	assert_eq(hero.current_hp, 101, "Overkill does not produce healing")
	assert_eq(hero.get_meta("ct_healing"), 58)

	var magical_target := Factory.make_unit("Cible magique", 1)
	magical_target.max_hp.base_value = 1000
	magical_target.current_hp = 1000
	field.grid.remove_unit(enemy)
	field.grid.place_unit(magical_target, Vector2i(2, 2))
	hero.start_turn()
	field.caster.cast(hero, catalog.get_spell("exp_ct_braise"), magical_target.grid_pos)
	assert_eq(hero.current_hp, 101, "Magical damage does not feed Coupe")
	assert_eq(hero.get_meta("ct_healing"), 58)


func test_all_six_presets_stay_legal_and_inert_links_are_advisory() -> void:
	for weapon in CatabasePreparationCatalog.WEAPONS:
		var selection := CatabasePreparationCatalog.preset(weapon)
		assert_true(CatabasePreparationCatalog.valid(selection), weapon)
		assert_eq(CatabasePreparationCatalog.spell_ids(selection).size(), 4, weapon)
		assert_eq(CatabasePreparationCatalog.compatibility_warnings(selection), [], weapon)

	var repercussion := CatabasePreparationCatalog.preset("marteau")
	repercussion.techniques[0] = "exp_ct_repercussion"
	assert_eq(CatabasePreparationCatalog.compatibility_warnings(repercussion).size(), 1)
	var fil := CatabasePreparationCatalog.preset("marteau")
	fil.relic = "fil"
	assert_eq(CatabasePreparationCatalog.compatibility_warnings(fil).size(), 1)
	var meche := CatabasePreparationCatalog.preset("arc")
	meche.relic = "meche"
	assert_eq(CatabasePreparationCatalog.compatibility_warnings(meche).size(), 1)


func _resolve_level(manager: Manager) -> void:
	if manager.expedition.advancement_step.is_empty():
		return
	assert_true(manager.advance_expedition_level_step().success)
	while manager.expedition.character.champion_progression.unspent_attribute_points > 0:
		assert_true(manager.spend_champion_attribute(&"achilles", &"vitality"))
	while not manager.expedition.advancement_step.is_empty():
		assert_true(manager.advance_expedition_level_step().success)
