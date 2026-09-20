extends "res://test/unit/test_catabase_monster_tactics.gd"
## Matched situations: remove one interaction, keep the combat rules unchanged.


func test_removing_hazard_changes_the_preferred_attack() -> void:
	var selected: Array[String] = []
	for with_fire in [false, true]:
		var f := _field()
		var dog := _monster(f, Vector2i(1, 1))
		var hero := _hero(f, Vector2i(2, 1))
		if with_fire:
			var fire := TerrainEffectData.new()
			fire.surface_id = &"synergy_audit_fire"
			fire.trigger = TerrainEffectData.Trigger.ON_ENTER
			fire.damage = 12
			fire.can_be_dodged = false
			f.terrain.place_effect(Vector2i(3, 1), fire)
		var bite := _spell("bite", {"damage": 14, "spell_range": 1, "ap_cost": 3})
		var push := _spell("push", {"damage": 5, "push_distance": 1, "spell_range": 1, "ap_cost": 3})
		dog.spells.assign([bite, push])
		var action := _action(f, dog, [dog, hero])
		selected.append(str(action.spell.spell_id))
		assert_false(f.caster.cast(dog, action.spell, action.cell).get("failed", false))
	assert_eq(selected, ["catabase_test_bite", "catabase_test_push"])
	print("SYNERGY_ABLATION hazard preferred_attacks=", selected)


func test_authored_hunt_mark_disappears_when_conductor_dies() -> void:
	var f := _field()
	var conductor := Unit.from_data(Evolution.build_unit(&"conducteur", {"depth": 10}))
	var hero := _hero(f, Vector2i(4, 1))
	f.grid.place_unit(conductor, Vector2i(1, 1))
	conductor.start_turn()
	# The authored mark has one initial activation of cooldown.
	conductor.start_turn()
	var mark: Spell = conductor.spells[1]
	assert_false(f.caster.cast(conductor, mark, hero.grid_pos).get("failed", false))
	assert_true(hero.has_status(&"catabase_chasse"))
	conductor.take_damage(10000, hero, Spell.DamageType.PHYSICAL, Spell.Element.NONE, {"cannot_be_dodged": true})
	assert_false(conductor.is_alive)
	assert_false(hero.has_status(&"catabase_chasse"), "Removing the support breaks its real group bonus")


func test_authored_full_officiant_kit_exposes_actual_ai_choice() -> void:
	# Unlike the capability test, keep every competing spell in the authored kit.
	var choices: Array[String] = []
	for distance in [2, 4, 6]:
		var f := _field()
		var data := Evolution.build_unit(&"officiant", {"depth": 7})
		preload("res://core/expedition/card_enemy_ecosystem.gd").apply(data, {"depth": 7})
		var enemy := Unit.from_data(data)
		f.grid.place_unit(enemy, Vector2i(1, 1))
		var hero := _hero(f, Vector2i(1 + distance, 1))
		enemy.start_turn()
		enemy.current_mp = 0
		var action := _action(f, enemy, [enemy, hero])
		assert_eq(action.get("type"), "cast")
		assert_true(f.caster.can_cast(enemy, action.spell, action.cell))
		choices.append(str(action.spell.spell_id))
	print("SYNERGY_ABLATION full_officiant distances=[2,4,6] choices=", choices)


func test_audit_records_production_summon_admission() -> void:
	# Diagnostic: a passing setup does not certify summon admission.
	var nodes := ExpeditionRouteCatalog.create_nodes(2401)
	for node in nodes:
		if int(node.depth) != 6:
			continue
		var room := ExpeditionRunFactory.make_room(node, 2401, true)
		assert_not_null(room)
		var runtime := EncounterRuntimeState.new()
		assert_true(runtime.initialize(room.encounter_definition))
		for data: UnitData in room.enemies:
			if data.tactical_role_id != &"catabase_evolution_officiant":
				continue
			var enemy := Unit.from_data(data)
			var summon: Spell = data.spells.back()
			assert_true(summon.is_summon())
			print("SYNERGY_ABLATION production_summon ", JSON.stringify({
				"node": node.id,
				"initial_enemies": room.enemies.size(),
				"encounter_cap": room.encounter_definition.living_enemy_cap,
				"spell_cap": summon.summon_max_living_team,
				"full_roster_rejection": runtime.can_prepare_summon(enemy, summon, room.enemies.size()),
				"one_survivor_rejection": runtime.can_prepare_summon(enemy, summon, 1),
			}))
			return
		fail_test("The depth-six production fixture must include an officiant")
		return
	fail_test("Missing depth-six route fixture")
