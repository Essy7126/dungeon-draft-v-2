extends GutTest
const Factory = preload("res://test/support/factory.gd")
const Cleanup = preload("res://test/support/isolated_battlefield_cleanup.gd")
var managers: Array = []
var fields: Array = []


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


func _manager():
	var manager := Manager.new()
	manager.expedition_save_path = "user://ct_first_six_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	managers.append(manager)
	return manager


func _field():
	var field = Factory.make_battlefield(10, 6)
	fields.append(field)
	return field


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


func test_six_departures_persist_reward_mutate_and_resume() -> void:
	for weapon in CatabasePreparationCatalog.WEAPONS:
		var m = _manager()
		assert_true(m.start_expedition(2401, { }, true, true), weapon)
		assert_eq(m.battles, 0, "No fight before preparation")
		assert_true(m.expedition.needs_preparation)
		var pending: Dictionary = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
		assert_true(m.restore_expedition_snapshot(pending), "Pending departure resumes")
		assert_false(m.choose_expedition_node("d01_0"), "Cannot bypass choices")
		var result: Dictionary = m.confirm_catabase_preparation(
			CatabasePreparationCatalog.preset(weapon)
		)
		assert_true(result.get("success", false), weapon + str(result))
		assert_true(result.get("saved", false), weapon)
		assert_eq(m.battles, 1)
		assert_eq(m.expedition.character.loadout.get_spell_slot_ids().size(), 4)
		assert_eq(m.expedition.gold, 60)
		var opening: Dictionary = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
		assert_true(
			m.restore_expedition_snapshot(opening),
			"Opening loadout/gear/relic resume: " + weapon,
		)
		assert_true(m.expedition.combat_won())
		_resolve_level(m)
		assert_true(m.claim_expedition_reward("supplies").get("success", false))
		assert_true(m.expedition.is_editable())
		var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(m.get_expedition_snapshot()))
		assert_true(m.restore_expedition_snapshot(checkpoint), "Reward checkpoint: " + weapon)
		assert_eq(m.expedition.build.starting_selection.weapon, weapon)
		assert_false(
			m.confirm_catabase_preparation(CatabasePreparationCatalog.preset(weapon)).get(
				"success",
				false,
			),
			"No duplicate starting grant",
		)


func test_invalid_departure_is_atomic_and_legacy_opening_still_loads() -> void:
	var m = _manager()
	assert_true(m.start_expedition(2401, { }, false, true))
	var before: Dictionary = m.get_expedition_snapshot()
	var invalid := CatabasePreparationCatalog.preset("marteau")
	invalid.techniques[1] = invalid.techniques[0]
	assert_false(m.confirm_catabase_preparation(invalid).get("success", false))
	assert_eq(m.get_expedition_snapshot(), before)
	var legacy = _manager()
	assert_true(legacy.start_expedition(42))
	var snapshot: Dictionary = legacy.get_expedition_snapshot()
	snapshot.session.erase("needs_preparation")
	snapshot.session.build.erase("starting_selection")
	snapshot.session.build.erase("weapon_unlocks")
	assert_true(legacy.restore_expedition_snapshot(snapshot))
	assert_true(legacy.expedition.build.starting_selection.is_empty())


func test_salve_caps_each_hit_expires_and_roundtrips() -> void:
	var f = _field()
	var hero := Factory.make_unit("Achille", 0)
	var enemy := Factory.make_unit("Ennemi", 1)
	f.grid.place_unit(hero, Vector2i(1, 2))
	f.grid.place_unit(enemy, Vector2i(2, 2))
	hero.current_ap = 6
	var catalog := ExpeditionBuildCatalog.new()
	assert_false(f.caster.cast(hero, catalog.get_spell("exp_ct_salve"), hero.grid_pos).get(
			"failed",
			false,
		))
	var saved := hero.get_shield_instances_snapshot()
	assert_eq(saved[0].remaining_impacts, 3)
	assert_true(hero.restore_shield_instances_snapshot(JSON.parse_string(JSON.stringify(saved))))
	var before := hero.current_hp
	for index in 3:
		hero.take_damage(10, enemy, Spell.DamageType.PHYSICAL)
	assert_eq(before - hero.current_hp, 12, "Three hits absorb six each")
	assert_eq(hero.current_shield, 0)
	hero.current_ap = 6
	hero.start_turn()
	f.caster.cast(hero, catalog.get_spell("exp_ct_salve"), hero.grid_pos)
	hero.start_turn()
	assert_eq(hero.current_shield, 0, "No indefinite storage")


func test_disc_preview_matches_return_and_cannot_duplicate_weapon() -> void:
	var f = _field()
	var hero := Factory.make_unit("Achille", 0)
	var enemy := Factory.make_unit("Ennemi", 1)
	f.grid.place_unit(hero, Vector2i(1, 2))
	f.grid.place_unit(enemy, Vector2i(3, 2))
	hero.current_ap = 6
	var catalog := ExpeditionBuildCatalog.new()
	var throw_spell := catalog.get_spell("exp_ct_lancer")
	var return_spell := catalog.get_spell("exp_ct_retour")
	assert_false(f.caster.cast(hero, throw_spell, Vector2i(5, 2)).get("failed", false))
	assert_ne(f.caster.get_cast_failure_reason(hero, throw_spell, enemy.grid_pos), &"")
	var preview: Array = f.caster.get_aoe_cells(return_spell, hero.grid_pos, hero.grid_pos)
	assert_has(preview, enemy.grid_pos)
	var before := enemy.current_hp
	assert_false(f.caster.cast(hero, return_spell, hero.grid_pos).get("failed", false))
	assert_lt(enemy.current_hp, before)
	assert_false(hero.has_meta("ct_disc"))
	assert_ne(f.caster.get_cast_failure_reason(hero, return_spell, hero.grid_pos), &"")


func test_flux_preserves_duration_and_does_not_duplicate_surface() -> void:
	var f = _field()
	var hero := Factory.make_unit("Achille", 0)
	f.grid.place_unit(hero, Vector2i(1, 2))
	hero.current_ap = 6
	var catalog := ExpeditionBuildCatalog.new()
	assert_false(f.caster.cast(hero, catalog.get_spell("exp_ct_braise"), Vector2i(3, 2)).get(
			"failed",
			false,
		))
	f.terrain.tick_all_effects()
	var duration: int = f.terrain.get_remaining_duration(Vector2i(3, 2))
	assert_false(f.caster.cast(hero, catalog.get_spell("exp_ct_flux"), Vector2i(3, 2)).get(
			"failed",
			false,
		))
	assert_null(f.terrain.get_effect_data(Vector2i(3, 2)))
	assert_eq(f.terrain.get_remaining_duration(Vector2i(4, 2)), duration)
	assert_eq(f.terrain.active_surface_cells().size(), 1)


func test_toll_cannot_spend_twice_or_refund_itself() -> void:
	var m = _manager()
	assert_true(m.start_expedition(2401, { }, false, true))
	assert_true(m.confirm_catabase_preparation(CatabasePreparationCatalog.preset("arc")).get(
			"success",
			false,
		))
	var f = _field()
	var hero: Unit = m.heroes[0]
	var enemy := Factory.make_unit("Ennemi", 1)
	f.grid.place_unit(hero, Vector2i(1, 2))
	f.grid.place_unit(enemy, Vector2i(4, 2))
	hero.start_turn()
	var catalog: ExpeditionBuildCatalog = m.expedition.build.catalog
	var toll := catalog.get_spell("exp_ct_peage")
	var ctx: CastContext = f.caster.begin_cast(hero, toll, hero.grid_pos)
	assert_false(ctx.failed)
	f.caster.resolve_cast(ctx)
	f.caster.resolve_cast(ctx)
	assert_eq(m.expedition.gold, 48)
	assert_ne(f.caster.get_cast_failure_reason(hero, toll, hero.grid_pos), &"")
	var before := enemy.current_hp
	f.caster.cast(hero, catalog.get_spell("exp_ct_trait"), enemy.grid_pos)
	assert_gt(before - enemy.current_hp, 28, "Paid bonus reaches production damage resolver")
	assert_false(hero.has_meta("ct_toll"))


func test_relic_definitions_are_valid_and_manual_supply_consumes_once() -> void:
	var m = _manager()
	assert_true(m.start_expedition(2401, { }, false, true))
	assert_true(m.confirm_catabase_preparation(CatabasePreparationCatalog.preset("marteau")).get(
			"success",
			false,
		))
	for item in CatabasePreparationCatalog.relic_items():
		assert_true(item.is_valid(), item.display_name)
		for effect in item.reactive_effects:
			assert_eq(RelicEffectRegistry.new().validate_effect(effect), [], item.display_name)
	var hero: Unit = m.heroes[0]
	hero.current_hp = 50
	hero.current_ap = 6
	var runtime: RelicRuntimeService = m.get_relic_runtime_service()
	runtime.begin_combat([hero])
	var instance: ItemInstance
	for value in m.run_inventory.get_slots():
		if value != null and value.definition_id == &"ct_supply_onguent":
			instance = value
	assert_not_null(instance)
	assert_true(runtime.manual_activation_state(hero, instance.instance_id).available)
	assert_true(runtime.activate_relic_manually(hero, instance.instance_id).success)
	assert_eq(hero.current_hp, 74)
	assert_eq(hero.current_ap, 5)
	assert_false(runtime.activate_relic_manually(hero, instance.instance_id).success)
	assert_eq(hero.current_hp, 74)


func test_all_six_progress_to_twenty_with_exclusive_mutations_and_weapon_pivot() -> void:
	# Victories are injected here; the separate playtest exercises real enemy AI.
	var roots := {
		"marteau": "ct_masse",
		"xiphos": "ct_salve",
		"disque": "ct_retour",
		"hampe": "ct_braise",
		"lame": "ct_entaille",
		"arc": "ct_peage",
	}
	for weapon in roots:
		var m = _manager()
		assert_true(m.start_expedition(2401, { }, false, true))
		assert_true(m.confirm_catabase_preparation(CatabasePreparationCatalog.preset(weapon)).success)
		var mutation: String = "ct." + roots[weapon] + "_a"
		for depth in range(1, 21):
			if m.expedition.route.phase == "combat":
				assert_true(m.expedition.combat_won())
			assert_eq(m.expedition.build.completed_depth, depth)
			_resolve_level(m)
			if depth == 2:
				assert_true(m.purchase_expedition_technique(mutation).success, weapon)
				assert_false(m.purchase_expedition_technique("ct." + roots[weapon] + "_b").success)
			if depth == 8:
				assert_true(m.purchase_expedition_technique(mutation + ".final").success, weapon)
			if depth == 12:
				assert_true(m.expedition.build.choose_depth_eight("slot").success)
			if depth == 14:
				var grant: Dictionary = m.run_inventory.try_add(&"catabase_ct_disque")
				assert_true(grant.success)
				assert_true(
					m.equip_inventory_item(grant.instance_ids[0], &"achilles", ItemDefinition
					.EquipmentSlot
					.WEAPON).success
				)
				assert_eq(m.expedition.build.catalog.get_spell_family(
						String(m.expedition.character.loadout.get_spell_slot_ids()[0])
					), "exp_ct_lancer")
			var checkpoint: Dictionary = JSON.parse_string(
				JSON.stringify(m.get_expedition_snapshot())
			)
			assert_true(m.restore_expedition_snapshot(checkpoint), "%s depth %d" % [weapon, depth])
			if depth == 20:
				assert_true(m.expedition.claim("finish", m.run_inventory, m.item_catalog).success)
				assert_eq(m.expedition.route.phase, "complete")
				break
			var options: Array = m.expedition.reward_options(m.item_catalog)
			var reward := "leave_hub" if options[0].id == "leave_hub" else "supplies"
			assert_true(m.claim_expedition_reward(reward).success)
			var available: Array = m.expedition.route.get_available_nodes()
			assert_false(available.is_empty())
			assert_true(
				m.choose_expedition_node(available[roots.keys().find(weapon) % available.size()].id)
			)


func test_urne_uses_real_guard_events_and_coupe_cannot_heal_without_limit() -> void:
	var m = _manager()
	assert_true(m.start_expedition(2401, { }, false, true))
	assert_true(m.confirm_catabase_preparation(CatabasePreparationCatalog.preset("xiphos")).success)
	var hero: Unit = m.heroes[0]
	var f = _field()
	var enemy := Factory.make_unit("Cible", 1)
	f.grid.place_unit(hero, Vector2i(1, 2))
	f.grid.place_unit(enemy, Vector2i(2, 2))
	var runtime: RelicRuntimeService = m.get_relic_runtime_service()
	runtime.begin_combat([hero], f.grid)
	hero.start_turn()
	f.caster.cast(hero, m.expedition.build.catalog.get_spell("exp_ct_salve"), hero.grid_pos)
	hero.take_damage(20, enemy, Spell.DamageType.PHYSICAL)
	assert_eq(hero.get_meta("ct_bronze"), 3)
	f.caster.cast(hero, m.expedition.build.catalog.get_spell("exp_ct_repercussion"), enemy.grid_pos)
	assert_eq(hero.get_meta("ct_bronze"), 0)
	assert_lt(enemy.current_hp, 100)
	assert_true(m.run_inventory.try_add(&"ct_relic_coupe").success)
	runtime.begin_combat([hero], f.grid)
	hero.current_hp = 20
	for index in 25:
		hero.start_turn()
		enemy.current_hp = 100
		f.caster.cast(hero, m.expedition.build.catalog.get_spell("exp_ct_taille"), enemy.grid_pos)
	assert_eq(hero.current_hp, 50, "Thirty real PV maximum per encounter")
	assert_eq(hero.get_meta("ct_healing"), 0)


func test_clou_rewards_displacement_before_rupture_and_harvest_rewards_a_wound() -> void:
	var catalog := ExpeditionBuildCatalog.new()
	var f = _field()
	var hero := Factory.make_unit("Achille", 0)
	var enemy := Factory.make_unit("Ossements", 1)
	f.grid.place_unit(hero, Vector2i(1, 2))
	f.grid.place_unit(enemy, Vector2i(2, 2))
	hero.set_meta("ct_relic_1", true)
	hero.start_turn()
	f.caster.cast(hero, catalog.get_spell("exp_ct_pousse"), enemy.grid_pos)
	assert_eq(enemy.grid_pos, Vector2i(3, 2))
	f.grid.relocate_unit(hero, Vector2i(2, 2))
	var before := enemy.current_hp
	f.caster.cast(hero, catalog.get_spell("exp_ct_masse"), enemy.grid_pos)
	assert_eq(before - enemy.current_hp, 38, "32 base plus six from the displacement relic")
	assert_true(enemy.has_status(&"exp_ct_fissure"))
	var blood = _field()
	var blade := Factory.make_unit("Achille", 0)
	var target := Factory.make_unit("Ossements", 1)
	blood.grid.place_unit(blade, Vector2i(1, 2))
	blood.grid.place_unit(target, Vector2i(2, 2))
	blade.start_turn()
	blood.caster.cast(blade, catalog.get_spell("exp_ct_entaille"), target.grid_pos)
	assert_true(target.has_status(&"exp_ct_plaie"))
	before = target.current_hp
	blood.caster.cast(blade, catalog.get_spell("exp_ct_recolte"), target.grid_pos)
	assert_eq(before - target.current_hp, 30, "Twenty base plus ten on the wound")


func test_protection_choice_has_an_opposite_physical_and_magical_cost() -> void:
	var losses := { }
	for armor in ["airain", "sceau"]:
		var m = _manager()
		assert_true(m.start_expedition(2401, { }, false, true))
		var selection := CatabasePreparationCatalog.preset("marteau")
		selection.armor = armor
		assert_true(m.confirm_catabase_preparation(selection).success)
		var hero: Unit = m.heroes[0]
		var before := hero.current_hp
		hero.take_damage(30, null, Spell.DamageType.PHYSICAL)
		var physical := before - hero.current_hp
		before = hero.current_hp
		hero.take_damage(30, null, Spell.DamageType.MAGICAL)
		losses[armor] = [physical, before - hero.current_hp]
	assert_lt(losses.airain[0], losses.sceau[0], "Airain protects against the physical front line")
	assert_gt(losses.airain[1], losses.sceau[1], "The same choice pays more for deep magic")


func test_departure_ui_changes_presets_and_commits_the_visible_selection() -> void:
	var m = _manager()
	assert_true(m.start_expedition(2401, { }, false, true))
	var view := preload("res://ui/expedition/catabase_departure_view.gd").new()
	add_child_autofree(view)
	view.size.x = 1000
	view.configure(m.expedition, m.confirm_catabase_preparation)
	var preset: Button = view.find_child("Preset_hampe", true, false)
	preset.pressed.emit()
	assert_eq(view.selection.weapon, "hampe")
	assert_eq(view.selection.techniques, CatabasePreparationCatalog.preset("hampe").techniques)
	assert_null(view.confirm, "Departure must be reviewed before committing")
	for index in 6:
		view.find_child("DepartureNext", true, false).pressed.emit()
	assert_eq(view.step, 6)
	view.confirm.pressed.emit()
	assert_false(m.expedition.needs_preparation)
	assert_eq(m.expedition.build.starting_selection.weapon, "hampe")


func _resolve_level(manager) -> void:
	if manager.expedition.advancement_step.is_empty(): return
	assert_true(manager.advance_expedition_level_step().success)
	while manager.expedition.character.champion_progression.unspent_attribute_points > 0:
		assert_true(manager.spend_champion_attribute(&"achilles", &"vitality"))
	assert_true(manager.advance_expedition_level_step().success)
	assert_true(manager.advance_expedition_level_step().success)
