extends GutTest
const Profile := preload("res://core/expedition/consumable_enemy_profile.gd")
const Native := preload("res://core/expedition/consumable_enemy_checkpoint.gd")
const Cards := preload("res://core/expedition/consumable_cards_state.gd")
const Turns := preload("res://core/expedition/consumable_card_turns.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
var fields: Array = []
var actor_groups: Array = []
var manager: Node
var live_battle: Node
var save_path := ""


class Manager:
	extends "res://core/game_manager.gd"
	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func start_next_battle() -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func after_each() -> void:
	for group in actor_groups:
		for actor: Unit in group:
			actor.clear_combat_effect_history()
			actor.pending_ability.clear()
			actor.active_statuses.clear()
			actor.linked_commander = null
	for field in fields:
		Cleanup.dispose_grid(field.grid)
	fields.clear()
	actor_groups.clear()
	if is_instance_valid(live_battle):
		remove_child(live_battle)
		live_battle.free()
	if is_instance_valid(manager):
		manager.cleanup_run_state()
		manager.free()
	if not save_path.is_empty():
		GameManager.cleanup_run_state()
		GameManager.expedition_save_path = ExpeditionSaveService.SAVE_PATH
		GameManager.selected_run_variant = "classic"
		ExpeditionSaveService.remove_snapshot(save_path)
	await wait_process_frames(2)


func node_at(depth: int, family := "airain", difficulty := "normal") -> Dictionary:
	var route := ExpeditionRouteState.new()
	route.initialize(33, 6, difficulty)
	for node in route.nodes:
		if (
			int(node.depth) == depth
			and (
				str(node.get("route_family", "shared")) == family
				or str(node.get("route_family", "shared")) == "shared"
			)
		):
			var result: Dictionary = node.duplicate(true)
			result["consumable_bestiary_revision"] = 1
			result["consumable_difficulty"] = difficulty
			result["knowledge"] = "revealed"
			return result
	return { }


func make_field(depth := 6) -> Dictionary:
	var node := node_at(depth)
	var room := ExpeditionRunFactory.make_room(node, 33)
	var field = Factory.make_battlefield(14, 9)
	fields.append(field)
	var runtime := EncounterRuntimeState.new()
	assert_true(runtime.initialize(room.encounter_definition))
	field.caster.set_encounter_runtime_state(runtime)
	var cards := Cards.new()
	cards.initialize_deck(Profile.Catalog.preset("gardien"))
	cards.level = int(Profile.definition(node).level)
	var hero := Factory.make_unit("Héros", 0)
	hero.unit_id = &"hero"
	Turns.bind_hero(hero, cards)
	Turns.rebuild(hero, cards)
	field.grid.place_unit(hero, Vector2i(7, 4))
	var units: Array = [hero]
	actor_groups.append(units)
	var by_id := { }
	for index in room.enemies.size():
		var unit := Unit.from_data(room.enemies[index])
		by_id[str(unit.content_unit_id)] = unit
		unit.unit_id = StringName("cc2_enemy_%02d" % index)
		field.grid.place_unit(unit, Vector2i(1 + index, 2))
		unit.start_turn()
		units.append(unit)
	return {
		"field": field,
		"node": node,
		"room": room,
		"runtime": runtime,
		"hero": hero,
		"cards": cards,
		"units": units,
		"actors": by_id,
	}


func cast(f: Dictionary, actor: Unit, id: String, cell: Vector2i) -> void:
	var spell := Native.find_spell(actor.spells, id)
	assert_not_null(spell)
	assert_true(f.field.caster.can_cast(actor, spell, cell), id)
	var result: Dictionary = f.field.caster.cast(actor, spell, cell)
	assert_false(result.get("failed", false), id)


func test_all_route_profiles_keep_counts_budgets_and_exact_preview() -> void:
	for difficulty in ["normal", "easy"]:
		for depth in Profile.DEPTHS:
			for family in ["airain", "styx", "lethe"]:
				var node := node_at(depth, family, difficulty)
				if node.is_empty():
					continue
				var legacy := node.duplicate(true)
				legacy.erase("consumable_bestiary_revision")
				var room := ExpeditionRunFactory.make_room(node, 33)
				assert_true(room.encounter_definition.is_valid())
				assert_eq(
					room.enemies.size(),
					ExpeditionRunFactory.make_room(legacy, 33).enemies.size(),
				)
				var preview := ExpeditionEncounterPreview.describe(node, 33)
				assert_eq(int(preview.count), room.enemies.size())
				var total := 0
				for data in room.enemies:
					total += data.max_hp
					assert_true(
						str(preview.details).contains(
							"%d PV · %d PA · %d PM · initiative %d"
							% [data.max_hp, data.max_ap, data.max_mp, data.initiative]
						)
					)
					for spell in data.spells:
						assert_true(str(preview.details).contains(spell.spell_name))
				if depth == 6:
					for id in ["skeleton_melee", "skeleton_chief"]:
						total += Profile.summon_data(id, node).max_hp
				var row := Profile.definition(node)
				var target := float(Profile.Catalog.data().rules.prowess[int(row.level) - 1]) * float(
					row.hpBudget
				) * (.9 if difficulty == "easy" else 1.0)
				assert_almost_eq(float(total), target, 4.0, "Bounded HP budget at depth %d" % depth)
	assert_eq((load(Profile.NATIVE.skeleton_melee[0]) as UnitData).max_hp, 72)
	assert_eq((load(Profile.NATIVE.skeleton_melee[0]) as UnitData).spells[0].damage, 18)
	assert_eq((load(Profile.NATIVE.philosopher_mage[0]) as UnitData).spells[2].heal, 22)


func test_old_snapshots_keep_revision_zero_and_unknown_revision_is_rejected() -> void:
	var cards := Cards.new()
	cards.initialize_deck(Profile.Catalog.preset("gardien"))
	var saved := cards.snapshot()
	saved.erase("bestiary_revision")
	assert_true(cards.restore(saved))
	assert_eq(cards.bestiary_revision, 0)
	saved["bestiary_revision"] = 1
	assert_true(cards.restore(saved))
	saved.bestiary_revision = 2
	assert_false(cards.restore(saved))
	assert_eq(cards.bestiary_revision, 1)


func test_philosopher_ai_controls_attacks_and_native_damage_obeys_cards_defense() -> void:
	var f := make_field(8)
	var mage: Unit = f.actors.philosopher_mage
	f.field.grid.relocate_unit(mage, Vector2i(3, 4))
	f.hero.resist_magique.base_value = 20
	Effects.apply_state(mage, "weak", .25, 1, f.hero)
	var ai := EnemyAI.new(f.field.grid, f.field.pathfinder, f.field.caster)
	var plan := ai.decide(mage, f.units)
	var ids := []
	for action in plan:
		if action.type == "cast":
			ids.append(str(action.spell.spell_id))
	assert_eq(ids, ["philosopher_aporia", "philosopher_axiom"])
	var before: int = f.hero.current_hp
	for action in plan:
		if action.type == "cast":
			cast(f, mage, str(action.spell.spell_id), action.cell)
	assert_eq(mage.current_ap, 0)
	assert_eq(before - f.hero.current_hp, roundi(mage.attack_power.get_value() * .75 * .8))
	assert_false(Effects.states(mage).has("weak"))
	f.hero.start_turn()
	assert_false(f.hero.process_statuses())
	assert_eq(f.hero.current_mp, 1)
	assert_eq(f.hero.current_ap, 4)
	# A support activation still spends real PA and respects cooldowns.
	mage.start_turn()
	mage.current_hp -= 30
	var hp := mage.current_hp
	cast(f, mage, "philosopher_mending", mage.grid_pos)
	assert_eq(mage.current_hp - hp, Native.find_spell(mage.spells, "philosopher_mending").heal)
	cast(f, mage, "philosopher_aegis", mage.grid_pos)
	assert_eq(mage.current_shield, Native.find_spell(mage.spells, "philosopher_aegis").shield_grant)
	assert_false(mage.can_use_spell(Native.find_spell(mage.spells, "philosopher_mending")))


func test_linked_mark_formation_and_source_death_survive_actor_ids() -> void:
	var f := make_field()
	var centurion: Unit = f.actors.skeleton_snow_centurion
	var melee: Unit = f.actors.skeleton_melee
	var chief: Unit = f.actors.skeleton_chief
	var aegis := Native.find_spell(centurion.spells, "frost_aegis")
	assert_eq(aegis.applied_status.stat_modifiers["resist_magique"], 20.0)
	assert_true(aegis.applied_status.description.contains("+20"))
	f.field.grid.relocate_unit(melee, Vector2i(6, 4))
	f.field.grid.relocate_unit(chief, Vector2i(6, 3))
	assert_eq(
		melee.armure.get_int(),
		16,
		"The native formation counts hero and chief as living neighbours",
	)
	assert_eq(melee.linked_commander, centurion)
	cast(f, centurion, "centurion_mark", f.hero.grid_pos)
	f.hero.armure.base_value = 0
	var hp: int = f.hero.current_hp
	cast(f, melee, "skeleton_bone_blade", f.hero.grid_pos)
	var blade := Native.find_spell(melee.spells, "skeleton_bone_blade")
	assert_eq(hp - f.hero.current_hp, blade.damage + blade.bonus_damage_if_marked)
	assert_true(f.field.grid.has_living_unit_id(1, &"skeleton_chief"))
	centurion.take_damage(10000)
	assert_false(f.hero.has_status(&"centurion_mark"))


func test_native_attacks_trigger_guardian_absorption_and_counter_damage() -> void:
	var f := make_field()
	var melee: Unit = f.actors.skeleton_melee
	f.field.grid.relocate_unit(melee, Vector2i(6, 4))
	f.hero.armure.base_value = 0
	Effects.guard(f.hero, 1.0, f.cards)
	var hp := melee.current_hp
	cast(f, melee, "skeleton_bone_blade", f.hero.grid_pos)
	assert_eq(f.cards.absorbed_since_turn, melee.attack_power.get_int())
	assert_lt(
		melee.current_hp,
		hp,
		"The class reacts to a native spell exactly as to a generic attack",
	)
	assert_eq(f.hero.current_hp, f.hero.max_hp.get_int())


func test_sentence_has_escape_counterplay_and_uses_the_same_linear_defense() -> void:
	var f := make_field()
	var chief: Unit = f.actors.skeleton_chief
	f.field.grid.relocate_unit(chief, Vector2i(6, 4))
	cast(f, chief, "scarlet_sentence", f.hero.grid_pos)
	var hp: int = f.hero.current_hp
	f.field.grid.relocate_unit(f.hero, Vector2i(8, 4))
	chief.start_turn()
	var escaped: Dictionary = f.field.caster.resolve_pending_activation(chief, f.units)
	assert_true(escaped.blocked)
	assert_true(escaped.consume_activation)
	assert_eq(f.hero.current_hp, hp)
	for _turn in 3:
		chief.start_turn()
	f.field.grid.relocate_unit(f.hero, Vector2i(7, 4))
	cast(f, chief, "scarlet_sentence", f.hero.grid_pos)
	f.hero.armure.base_value = 20
	chief.start_turn()
	var hit: Dictionary = f.field.caster.resolve_pending_activation(chief, f.units)
	assert_true(hit.resolved)
	assert_eq(
		hp - f.hero.current_hp,
		roundi(Native.find_spell(chief.spells, "scarlet_sentence").damage * .8),
	)
	assert_eq(f.hero.grid_pos, Vector2i(8, 4))


func test_summoning_is_finite_blockable_and_cannot_duplicate_a_living_chief() -> void:
	var f := make_field()
	var centurion: Unit = f.actors.skeleton_snow_centurion
	centurion.current_hp = 1
	assert_false(f.field.caster.can_cast(
			centurion,
			Native.find_spell(centurion.spells, "raise_chief"),
			Vector2i(1, 4),
		))
	cast(f, centurion, "call_bones", Vector2i(1, 4))
	assert_eq(f.runtime.normal_summons_committed, 1)
	f.field.grid.relocate_unit(f.hero, Vector2i(1, 4))
	centurion.start_turn()
	var blocked: Dictionary = f.field.caster.resolve_pending_activation(centurion, f.units)
	assert_true(blocked.blocked)
	assert_eq(blocked.reason, &"cell_blocked")
	assert_eq(f.runtime.get_remaining_budget(&"normal"), 0)
	for _turn in 4:
		centurion.start_turn()
	assert_false(centurion.can_use_spell(Native.find_spell(centurion.spells, "call_bones")))
	var chief: Unit = f.actors.skeleton_chief
	chief.take_damage(10000)
	cast(f, centurion, "raise_chief", Vector2i(2, 3))
	centurion.start_turn()
	var raised: Dictionary = f.field.caster.resolve_pending_activation(centurion, f.units)
	assert_true(raised.resolved)
	assert_eq(raised.summoned_unit.max_hp.get_int(), 44)
	assert_eq(f.runtime.get_remaining_budget(&"chief"), 0)


func _mount(snapshot: Dictionary) -> void:
	if is_instance_valid(live_battle):
		remove_child(live_battle)
		live_battle.free()
	assert_true(GameManager.restore_expedition_snapshot(snapshot))
	live_battle = GameManager.get_current_room().battle_scene.instantiate()
	add_child(live_battle)
	await wait_process_frames(3)
	if live_battle._deployment.is_active():
		live_battle._deployment.on_cell_clicked(live_battle._deployment._deploy_zone[0])
	for _tick in 300:
		await wait_seconds(.02)
		if live_battle._can_accept_player_intent():
			break
	assert_true(live_battle._can_accept_player_intent())


func _actor(id: String) -> Unit:
	for actor in live_battle.units:
		if str(actor.content_unit_id) == id and not actor.get_meta("cc2_summoned", false):
			return actor
	return null


func test_real_legion_preserves_pending_spells_summons_budget_and_loot_on_resume() -> void:
	manager = Manager.new()
	add_child(manager)
	save_path = "user://cc2_bestiary_%d.json" % Time.get_ticks_usec()
	manager.expedition_save_path = save_path
	assert_true(manager.start_expedition(33, { }, false, true, "normal", true))
	for _depth in 5:
		var session: ExpeditionSession = manager.expedition
		# Route transition fixture; no claim about winning or difficulty.
		if session.route.phase == "combat":
			assert_true(session.combat_won())
			assert_true(session.acknowledge_combat_receipt().success)
		if session.cards.level >= 4 and session.cards.specialization.is_empty():
			session.cards.specialize("execution")
		while not session.advancement_step.is_empty():
			session.advance_level_step()
		var options: Array = session.reward_options(manager.item_catalog)
		assert_true(session.claim(str(options[0].id), manager.run_inventory, manager.item_catalog).success)
		assert_true(manager.choose_expedition_node(str(session.route.get_available_nodes()[0].id)))
	assert_eq(int(manager.expedition.route.get_current_node().depth), 6)
	GameManager.cleanup_run_state()
	GameManager.expedition_save_path = save_path
	await _mount(manager.get_expedition_snapshot())
	var hero: Unit = GameManager.expedition.character.unit
	var chief := _actor("skeleton_chief")
	var centurion := _actor("skeleton_snow_centurion")
	var placed := false
	for y in live_battle.grid.rows:
		for x in live_battle.grid.cols - 1:
			var cell := Vector2i(x, y)
			if live_battle.grid.is_walkable(cell) and live_battle.grid.is_walkable(
					cell + Vector2i.RIGHT
				):
				live_battle.grid.relocate_unit(hero, cell)
				live_battle.grid.relocate_unit(chief, cell + Vector2i.RIGHT)
				placed = true
				break
		if placed:
			break
	assert_true(placed)
	chief.start_turn()
	centurion.start_turn()
	var sentence := Native.find_spell(chief.spells, "scarlet_sentence")
	var bones := Native.find_spell(centurion.spells, "call_bones")
	assert_false(live_battle.spell_caster.cast(chief, sentence, hero.grid_pos).get("failed", false))
	var cells: Array = live_battle.spell_caster.get_targetable_cells(centurion, bones)
	assert_false(cells.is_empty())
	assert_false(live_battle.spell_caster.cast(centurion, bones, cells[0]).get("failed", false))
	var commitments: Dictionary = JSON.parse_string(
		JSON.stringify(GameManager.expedition.cards.loot_commitments)
	)
	assert_true(live_battle._cards_runtime.checkpoint())
	var saved := ExpeditionSaveService.read_snapshot(save_path)
	assert_eq(int(saved.session.combat_checkpoint.version), 3)
	# Tampered pending spells and excessive summon budgets are rejected atomically.
	var corrupt := saved.duplicate(true)
	corrupt.session.combat_checkpoint.summon_budgets.normal = 2
	assert_false(manager.restore_expedition_snapshot(corrupt))
	await _mount(saved)
	chief = _actor("skeleton_chief")
	centurion = _actor("skeleton_snow_centurion")
	assert_eq(str(chief.pending_ability.spell.spell_id), "scarlet_sentence")
	assert_eq(str(centurion.pending_ability.spell.spell_id), "call_bones")
	assert_eq(live_battle._tactical_telegraphs.get_telegraph_count(), 2)
	centurion.start_turn()
	var resolved: Dictionary = live_battle.spell_caster.resolve_pending_activation(
		centurion,
		live_battle.units,
		live_battle.turn_queue,
		Callable(live_battle, "_on_pending_unit_spawned"),
	)
	assert_true(resolved.resolved)
	var summon: Unit = resolved.summoned_unit
	assert_eq(str(summon.unit_id), "cc2_enemy_04")
	assert_eq(summon.max_hp.get_int(), 28)
	assert_eq(GameManager.expedition.cards.loot_commitments, commitments)
	assert_true(live_battle._cards_runtime.checkpoint())
	saved = ExpeditionSaveService.read_snapshot(save_path)
	await _mount(saved)
	assert_eq(live_battle.units.size(), 6)
	assert_eq(live_battle.turn_queue.get_full_order().size(), 6)
	assert_eq(live_battle.encounter_runtime_state.normal_summons_committed, 1)
	assert_eq(GameManager.expedition.cards.loot_commitments, commitments)
	assert_eq(live_battle._tactical_telegraphs.get_telegraph_count(), 1)
	var before: Dictionary = GameManager.expedition.combat_checkpoint.duplicate(true)
	assert_eq(
		live_battle.turn_queue.get_full_order().map(
			func(actor):
				return str(actor.unit_id),
		),
		before.turn_order,
	)
	assert_true(live_battle._cards_runtime.checkpoint())
	assert_eq(GameManager.expedition.combat_checkpoint, before, "Immediate resume is lossless")
	chief = _actor("skeleton_chief")
	Effects.apply_state(chief, "stasis", 0, 1, GameManager.expedition.character.unit)
	assert_true(live_battle._cards_runtime.begin_activation(chief))
	assert_true(chief.pending_ability.is_empty())
