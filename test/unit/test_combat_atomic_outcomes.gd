extends GutTest


class HudSpy:
	extends RefCounted

	func update_info(_unit) -> void:
		pass

	func build_actions(_unit) -> void:
		pass

	func set_controls_enabled(_enabled: bool) -> void:
		pass

	func set_active_mode(_mode: String, _spell: Spell = null) -> void:
		pass

	func detach() -> void:
		pass


class OutcomeBattleFixture:
	extends "res://battle/battle.gd"

	func _ready() -> void:
		pass

	func _end_battle(victory: bool) -> void:
		if _battle_over:
			return
		_battle_over = true
		EventBus.combat_ended.emit(victory)


func test_fatal_player_attack_emits_action_contract_before_combat_end() -> void:
	var battle := _battle_fixture()
	var hero := Unit.new("Héros", 0, 100, 20, 6, 3, 20)
	var enemy := Unit.new("Dernier ennemi", 1, 1, 10)
	_prepare_units(battle, hero, enemy)
	var events: Array[StringName] = []
	var callbacks := _capture_action_order(hero, events)

	await battle._on_request_attack(enemy.grid_pos)

	_disconnect_action_order(callbacks)
	assert_eq(events, [
		&"basic_attack_performed",
		&"ap_after_action_changed",
		&"action_resolved",
		&"combat_ended",
	])
	assert_true(battle._battle_over)
	assert_false(battle._battle_outcome_waiting)
	assert_eq(battle._outcome_deferral_depth, 0)


func test_fatal_enemy_attack_emits_action_contract_before_combat_end() -> void:
	var battle := _battle_fixture()
	var hero := Unit.new("Dernier héros", 0, 1, 10)
	var enemy := Unit.new("Ennemi", 1, 100, 20, 6, 3, 20)
	_prepare_units(battle, enemy, hero)
	var runner := EnemyTurnRunner.new()
	battle.add_child(runner)
	runner.setup(battle)
	var events: Array[StringName] = []
	var callbacks := _capture_action_order(enemy, events)

	await runner._execute_attack(enemy, hero)

	_disconnect_action_order(callbacks)
	assert_eq(events, [
		&"basic_attack_performed",
		&"ap_after_action_changed",
		&"action_resolved",
		&"combat_ended",
	])
	assert_true(battle._battle_over)
	assert_false(battle._battle_outcome_waiting)
	assert_eq(battle._outcome_deferral_depth, 0)


func test_fatal_enemy_spell_emits_action_contract_before_combat_end() -> void:
	var battle := _battle_fixture()
	var hero := Unit.new("Dernier héros", 0, 1, 10)
	var enemy := Unit.new("Mage ennemi", 1, 100, 20, 6, 3, 20)
	_prepare_units(battle, enemy, hero)
	battle.pathfinder = Pathfinder.new(battle.grid)
	battle.terrain_effects = TerrainEffects.new(battle.grid)
	battle.spell_caster = SpellCaster.new(
		battle.grid, battle.pathfinder, battle.terrain_effects
	)
	var spell := Spell.new()
	spell.spell_id = &"fatal_enemy_spell"
	spell.spell_name = "Sort fatal"
	spell.ap_cost = 2
	spell.spell_range = 1
	spell.damage = 20
	var runner := EnemyTurnRunner.new()
	battle.add_child(runner)
	runner.setup(battle)
	var events: Array[StringName] = []
	var on_ap := func(source, _before, _after, _action_id):
		if source == enemy:
			events.append(&"ap_after_action_changed")
	var on_action := func(source, _action_id, kind, _report):
		if source == enemy and kind == &"spell":
			events.append(&"action_resolved")
	var on_end := func(_victory): events.append(&"combat_ended")
	EventBus.ap_after_action_changed.connect(on_ap)
	EventBus.action_resolved.connect(on_action)
	EventBus.combat_ended.connect(on_end)

	await runner._execute_cast(enemy, spell, hero.grid_pos)

	for entry in [
		[EventBus.ap_after_action_changed, on_ap],
		[EventBus.action_resolved, on_action],
		[EventBus.combat_ended, on_end],
	]:
		var signal_value: Signal = entry[0]
		var callback: Callable = entry[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)
	assert_eq(events, [
		&"ap_after_action_changed",
		&"action_resolved",
		&"combat_ended",
	])
	assert_true(battle._battle_over)
	assert_eq(battle._outcome_deferral_depth, 0)


func test_fatal_turn_end_status_emits_turn_contract_before_combat_end() -> void:
	var battle := _battle_fixture()
	var hero := Unit.new("Dernier héros", 0, 1, 20)
	var enemy := Unit.new("Ennemi", 1, 100, 10)
	_prepare_units(battle, hero, enemy)
	hero.died.connect(battle._on_unit_died)
	var bleeding := StatusData.new()
	bleeding.status_id = &"fatal_turn_end"
	bleeding.duration = 1
	bleeding.damage_per_turn = 1
	bleeding.damage_timing = StatusData.PeriodicTiming.TURN_END
	bleeding.ignores_defense = true
	bleeding.can_be_dodged = false
	hero.apply_status(bleeding)
	var events: Array[StringName] = []
	var on_turn_end := func(unit, _reason):
		if unit == hero:
			events.append(&"turn_ended")
	var on_combat_end := func(_victory):
		events.append(&"combat_ended")
	EventBus.turn_ended.connect(on_turn_end)
	EventBus.combat_ended.connect(on_combat_end)

	assert_true(battle._finish_active_turn(&"player_requested"))

	EventBus.turn_ended.disconnect(on_turn_end)
	EventBus.combat_ended.disconnect(on_combat_end)
	assert_eq(events, [&"turn_ended", &"combat_ended"])
	assert_true(battle._battle_over)
	assert_false(battle._battle_outcome_waiting)
	assert_eq(battle._outcome_deferral_depth, 0)
	assert_same(battle.turn_queue.get_current_unit(), hero)


func test_fatal_turn_start_status_closes_activation_before_combat_end() -> void:
	var battle := _battle_fixture()
	var hero := Unit.new("Dernier héros", 0, 1, 20)
	var enemy := Unit.new("Ennemi", 1, 100, 10)
	_prepare_units(battle, hero, enemy)
	hero.died.connect(battle._on_unit_died)
	var poison := StatusData.new()
	poison.status_id = &"fatal_turn_start"
	poison.duration = 1
	poison.damage_per_turn = 1
	poison.damage_timing = StatusData.PeriodicTiming.TURN_START
	poison.ignores_defense = true
	poison.can_be_dodged = false
	hero.apply_status(poison)
	var events: Array[StringName] = []
	var on_turn_end := func(unit, reason):
		if unit == hero:
			events.append(StringName("turn_ended:%s" % reason))
	var on_combat_end := func(_victory):
		events.append(&"combat_ended")
	EventBus.turn_ended.connect(on_turn_end)
	EventBus.combat_ended.connect(on_combat_end)

	await battle._on_turn_started(hero)

	EventBus.turn_ended.disconnect(on_turn_end)
	EventBus.combat_ended.disconnect(on_combat_end)
	assert_eq(events, [&"turn_ended:dead", &"combat_ended"])
	assert_true(battle._battle_over)
	assert_false(battle._battle_outcome_waiting)
	assert_eq(battle._outcome_deferral_depth, 0)
	assert_same(battle.turn_queue.get_current_unit(), hero)


func test_fatal_pending_strike_closes_activation_before_combat_end() -> void:
	var battle := _battle_fixture()
	var enemy := Unit.new("Lanceur", 1, 100, 20)
	var hero := Unit.new("Dernier héros", 0, 1, 10)
	_prepare_units(battle, enemy, hero)
	_configure_spell_runtime(battle)
	var spell := _pending_strike(20)
	enemy.pending_ability = {
		"spell": spell,
		"cell": hero.grid_pos,
		"target": hero,
		"prepared_activation": enemy.activation_index,
	}
	var events: Array[StringName] = []
	var on_pending := func(caster, _spell, _payload):
		if caster == enemy:
			events.append(&"pending_ability_resolved")
	var on_turn_end := func(unit, reason):
		if unit == enemy:
			events.append(StringName("turn_ended:%s" % reason))
	var on_combat_end := func(_victory):
		events.append(&"combat_ended")
	EventBus.pending_ability_resolved.connect(on_pending)
	EventBus.turn_ended.connect(on_turn_end)
	EventBus.combat_ended.connect(on_combat_end)

	await battle._on_turn_started(enemy)

	EventBus.pending_ability_resolved.disconnect(on_pending)
	EventBus.turn_ended.disconnect(on_turn_end)
	EventBus.combat_ended.disconnect(on_combat_end)
	assert_eq(events, [
		&"pending_ability_resolved",
		&"turn_ended:pending_ability_resolved",
		&"combat_ended",
	])
	assert_true(battle._battle_over)
	assert_false(battle._battle_outcome_waiting)
	assert_eq(battle._outcome_deferral_depth, 0)
	assert_same(battle.turn_queue.get_current_unit(), enemy)


func test_stun_preserves_pending_strike_until_next_playable_activation() -> void:
	var battle := _battle_fixture()
	var enemy := Unit.new("Lanceur choqué", 1, 100, 20)
	var hero := Unit.new("Héros", 0, 100, 10)
	_prepare_units(battle, enemy, hero)
	_configure_spell_runtime(battle)
	var spell := _pending_strike(20)
	enemy.pending_ability = {
		"spell": spell,
		"cell": hero.grid_pos,
		"target": hero,
		"prepared_activation": enemy.activation_index,
	}
	var shock := load("res://data/status/core/choc.tres") as StatusData
	enemy.apply_status(shock)
	var pending_events: Array[StringName] = []
	var turn_reasons: Array[StringName] = []
	var on_pending := func(caster, _spell, _payload):
		if caster == enemy:
			pending_events.append(&"resolved")
	var on_turn_end := func(unit, reason):
		if unit == enemy:
			turn_reasons.append(reason)
	EventBus.pending_ability_resolved.connect(on_pending)
	EventBus.turn_ended.connect(on_turn_end)

	await battle._on_turn_started(enemy)

	assert_eq(hero.current_hp, 100)
	assert_eq(pending_events, [])
	assert_false(enemy.pending_ability.is_empty())
	assert_eq(turn_reasons, [&"stunned"])
	assert_false(enemy.has_status(&"shock"))
	# Le héros est maintenant courant. Faire avancer la file simule sa fin de
	# tour sans reconnecter le signal de Battle dans cette fixture unitaire.
	assert_true(battle.turn_queue.advance())
	await battle._on_turn_started(enemy)

	EventBus.pending_ability_resolved.disconnect(on_pending)
	EventBus.turn_ended.disconnect(on_turn_end)
	assert_eq(hero.current_hp, 80)
	assert_eq(pending_events, [&"resolved"])
	assert_true(enemy.pending_ability.is_empty())
	assert_eq(turn_reasons, [&"stunned", &"pending_ability_resolved"])
	assert_eq(battle._outcome_deferral_depth, 0)


func _battle_fixture() -> OutcomeBattleFixture:
	var battle := OutcomeBattleFixture.new()
	battle.grid = GridData.new(2, 1)
	battle.turn_state = TurnState.new()
	battle._hud_port = HudSpy.new()
	add_child_autofree(battle)
	return battle


func _prepare_units(
		battle: OutcomeBattleFixture,
		attacker: Unit,
		target: Unit
	) -> void:
	assert_true(battle.grid.place_unit(attacker, Vector2i.ZERO))
	assert_true(battle.grid.place_unit(target, Vector2i.RIGHT))
	target.died.connect(battle._on_unit_died)
	battle.units = [attacker, target]
	battle.turn_queue = TurnQueue.new()
	battle.turn_queue.setup(battle.units)
	battle.turn_queue.start()


func _configure_spell_runtime(battle: OutcomeBattleFixture) -> void:
	battle.pathfinder = Pathfinder.new(battle.grid)
	battle.terrain_effects = TerrainEffects.new(battle.grid)
	battle.spell_caster = SpellCaster.new(
		battle.grid, battle.pathfinder, battle.terrain_effects
	)


func _pending_strike(damage: int) -> Spell:
	var spell := Spell.new()
	spell.spell_id = &"pending_strike_fixture"
	spell.spell_name = "Frappe différée de test"
	spell.spell_range = 2
	spell.damage = damage
	spell.delayed_resolution = Spell.DelayedResolution.RANGED_STRIKE
	spell.consumes_activation_on_resolution = true
	return spell


func _capture_action_order(
		actor: Unit,
		events: Array[StringName]
	) -> Dictionary:
	var on_basic := func(source, _target):
		if source == actor:
			events.append(&"basic_attack_performed")
	var on_ap := func(source, _before, _after, _action_id):
		if source == actor:
			events.append(&"ap_after_action_changed")
	var on_action := func(source, _action_id, kind, _report):
		if source == actor and kind == &"basic_attack":
			events.append(&"action_resolved")
	var on_end := func(_victory): events.append(&"combat_ended")
	EventBus.basic_attack_performed.connect(on_basic)
	EventBus.ap_after_action_changed.connect(on_ap)
	EventBus.action_resolved.connect(on_action)
	EventBus.combat_ended.connect(on_end)
	return {
		"basic": on_basic,
		"ap": on_ap,
		"action": on_action,
		"end": on_end,
	}


func _disconnect_action_order(callbacks: Dictionary) -> void:
	for entry in [
		[EventBus.basic_attack_performed, callbacks["basic"]],
		[EventBus.ap_after_action_changed, callbacks["ap"]],
		[EventBus.action_resolved, callbacks["action"]],
		[EventBus.combat_ended, callbacks["end"]],
	]:
		var signal_value: Signal = entry[0]
		var callback: Callable = entry[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)
