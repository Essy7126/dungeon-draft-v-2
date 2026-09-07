extends GutTest

const Factory = preload("res://test/support/factory.gd")
var _adapter: MasteryCombatAdapter
var _grid: GridData
var _caster: SpellCaster
var _hero: Unit
var _enemy: Unit
var _relic_services: Array[RelicRuntimeService] = []

func before_each() -> void:
	_grid = GridData.new(8, 8)
	var pathfinder := Pathfinder.new(_grid)
	var terrain := TerrainEffects.new(_grid)
	_caster = SpellCaster.new(_grid, pathfinder, terrain)
	_hero = Factory.make_unit("Achille", 0)
	_enemy = Factory.make_unit("Enemy", 1)
	_hero.unit_id = &"achilles"
	_enemy.unit_id = &"target"
	_hero.current_ap = 20
	_hero.crit_chance.base_value = 0.0
	_enemy.crit_chance.base_value = 0.0
	_hero.esquive.base_value = 0.0
	_enemy.esquive.base_value = 0.0
	_grid.place_unit(_hero, Vector2i(2, 2))
	_grid.place_unit(_enemy, Vector2i(3, 2))
	_hero.facing_dir = Vector2i.RIGHT
	_hero.mastery_runtime = MasteryReactiveRuntimeService.new()
	for id in ["peleid_strike", "fulminant_dash", "pelion_shot", "bronze_guard"]:
		_hero.spells.append(load("res://data/spells/achilles/%s.tres" % id))
	_adapter = MasteryCombatAdapter.new()
	_adapter.configure(_grid, _caster, terrain, pathfinder, [_hero, _enemy])

func after_each() -> void:
	_adapter.dispose()
	for service in _relic_services:
		service.dispose()
	_relic_services.clear()

func _configure(effects: Array[MasteryReactiveEffectData]) -> void:
	assert_true(_hero.mastery_runtime.configure(effects).is_empty())

func _effect(source: StringName, effect_id: StringName, event: StringName) -> MasteryReactiveEffectData:
	var result := MasteryReactiveEffectData.new()
	result.source_id = source
	result.effect_id = effect_id
	result.event_id = event
	return result

func _strike() -> Spell:
	return _hero.spells[0] as Spell

func test_conditional_damage_runs_before_the_real_hit() -> void:
	var execution := _effect(&"execution", &"damage_multiplier", &"spell_cast")
	execution.valid_spell_ids = [&"achilles_peleid_strike"]
	execution.target_hp_ratio_at_most = 0.35
	execution.multiplier = 1.35
	_configure([execution])
	_enemy.current_hp = 30
	var base := _strike().get_scaled_damage(_hero)
	_caster.cast(_hero, _strike(), _enemy.grid_pos)
	assert_eq(_enemy.current_hp, 30 - int(round(base * 1.35)))

func test_directional_guard_changes_only_guard_points_and_keeps_other_sources() -> void:
	var direction := _effect(&"direction", &"modify_shield_damage", &"damage_received")
	direction.requires_guard = true
	direction.directional_guard = DirectionalGuardData.new()
	_configure([direction])
	_hero.add_sourced_shield(&"guard", 20, _hero, {"tags": [&"guard"], "priority": 10})
	_hero.add_sourced_shield(&"other", 9)
	_hero.take_damage(20, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "ignore_defense": true, "attack_classification": &"MELEE", "action_id": &"incoming"})
	assert_eq(_hero.get_shield_value(&"guard"), 7)
	assert_eq(_hero.get_shield_value(&"other"), 9)
	assert_eq(_hero.current_hp, 100)

func test_counter_uses_real_spell_pipeline_without_ap_manual_use_or_spell_xp_event() -> void:
	var counter := _effect(&"counter", &"automatic_attack", &"damage_received")
	counter.requires_guard = true
	counter.required_attack_classification = MasteryReactiveEffectData.AttackClassification.MELEE
	counter.target_spell_id = &"achilles_peleid_strike"
	counter.multiplier = 0.7
	counter.automatic_action = true
	counter.frequency = MasteryReactiveEffectData.Frequency.ONCE_UNTIL_NEXT_ACTIVATION
	_configure([counter])
	_hero.add_sourced_shield(&"guard", 20, _hero, {"tags": [&"guard"]})
	var ap := _hero.current_ap
	var uses := _hero.get_spell_uses(_strike())
	var xp_events := [0]
	var on_cast := func(_actor, _spell, _report): xp_events[0] += 1
	EventBus.spell_cast.connect(on_cast)
	_hero.take_damage(5, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "attack_classification": &"MELEE", "action_id": &"enemy_attack"})
	_adapter.flush_automatic()
	EventBus.spell_cast.disconnect(on_cast)
	assert_eq(_enemy.current_hp, 100 - int(round(_strike().get_scaled_damage(_hero) * 0.7)))
	assert_eq(_hero.current_ap, ap)
	assert_eq(_hero.get_spell_uses(_strike()), uses)
	assert_eq(xp_events[0], 0)

func test_followup_revalidates_occupancy_without_spending_its_request() -> void:
	var step := _effect(&"step", &"queue_followup", &"movement_resolved")
	step.followup_request_type = &"orthogonal_step"
	step.maximum_cells = 1
	step.optional = true
	_configure([step])
	_adapter.dispatch(_hero, &"movement_resolved")
	var request := _adapter.pending_choice(_hero)
	assert_not_null(request)
	var selected := Vector2i(2, 3)
	assert_true(request.valid_cells.has(selected))
	_grid.relocate_unit(_enemy, selected)
	var result := _adapter.resolve_choice(_hero, request, selected)
	assert_false(result.get("resolved", true))
	assert_eq(_adapter.pending_choice(_hero), request)

func test_expiring_guard_conversion_uses_the_actual_remaining_source() -> void:
	var conversion := _effect(&"conversion", &"choose_shield_conversion", &"activation_started")
	conversion.requires_guard = true
	conversion.followup_request_type = &"shield_conversion"
	conversion.valid_option_ids = [&"retain_half_as_new_shield", &"convert_remaining_to_next_strike"]
	_configure([conversion])
	_hero.add_sourced_shield(&"guard", 30, _hero, {"tags": [&"guard"], "expires_after_activations": 1})
	_hero.add_sourced_shield(&"other", 7)
	_hero.start_turn()
	assert_eq(_hero.get_shield_value(&"guard"), 0)
	var request := _adapter.pending_choice(_hero)
	assert_not_null(request)
	assert_true(_adapter.resolve_choice(_hero, request, null, &"retain_half_as_new_shield").get("resolved", false))
	assert_eq(_hero.get_shield_value(&"conversion"), 15)
	assert_eq(_hero.get_shield_value(&"other"), 7)

func test_bastion_and_anchor_require_one_choice_before_consuming_guard() -> void:
	var bastion := _effect(&"achilles_aeacus_mobile_bastion.impact", &"bastion_impact", &"movement_resolved")
	bastion.requires_guard = true
	bastion.ratio_value = 0.2
	bastion.cap_max_hp_ratio = 0.08
	bastion.flat_value = 1
	_configure([bastion])
	_hero.add_sourced_shield(&"guard", 50, _hero, {"tags": [&"guard"]})
	_adapter.dispatch(_hero, &"movement_resolved", {"action_id": &"dash"})
	_adapter.handle_relic_intent({"actor_id": _hero.get_runtime_stable_id(), "intent_id": &"guard_dash_conversion",
		"item_id": &"anchor_thetis", "action_id": &"dash", "parameters": {"shield_consumption_ratio": 0.3}})
	_adapter.flush_automatic()
	assert_eq(_hero.get_shield_value(&"guard"), 50)
	var request := _adapter.pending_choice(_hero)
	assert_not_null(request)
	assert_false(request.optional)
	assert_true(_adapter.resolve_choice(_hero, request, null, bastion.source_id).get("resolved", false))
	assert_eq(_hero.get_shield_value(&"guard"), 40)
	assert_null(_adapter.pending_choice(_hero))


func test_absorption_threshold_excludes_collateral_shield_points() -> void:
	var track := _effect(&"guard_track", &"track_absorption", &"damage_absorbed")
	track.requires_guard = true
	track.minimum_absorbed_max_hp_ratio = 0.1
	track.flag_id = &"ready"
	_configure([track])
	_hero.add_sourced_shield(&"guard", 5, _hero, {"tags": [&"guard"], "priority": 10})
	_hero.add_sourced_shield(&"other", 20)
	_hero.take_damage(10, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "ignore_defense": true, "attack_classification": &"MELEE"})
	assert_false(_hero.mastery_runtime.has_runtime_flag(&"ready", track.scope, _adapter.context_for(_hero)))

func test_collateral_source_break_does_not_trigger_guard_destroyed() -> void:
	var broken := _effect(&"guard_break", &"set_flag", &"shield_destroyed")
	broken.flag_id = &"broken"
	_configure([broken])
	_hero.add_sourced_shield(&"guard", 20, _hero, {"tags": [&"guard"]})
	_hero.add_sourced_shield(&"other", 3, _hero, {"priority": 10})
	_hero.take_damage(8, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "ignore_defense": true, "attack_classification": &"MELEE"})
	assert_eq(_hero.get_shield_value(&"guard"), 15)
	assert_false(_hero.mastery_runtime.has_runtime_flag(&"broken", broken.scope, _adapter.context_for(_hero)))

func test_unchosen_sentinel_keeps_its_combat_charge_for_a_later_projectile() -> void:
	var sentinel := _effect(&"achilles_junction_pelion_sentinel.response_shot", &"automatic_attack", &"projectile_received")
	sentinel.requires_guard = true
	sentinel.target_spell_id = &"achilles_pelion_shot"
	sentinel.multiplier = 0.6
	sentinel.automatic_action = true
	sentinel.frequency = MasteryReactiveEffectData.Frequency.ONCE_PER_COMBAT
	_configure([sentinel])
	_grid.relocate_unit(_enemy, Vector2i(5, 2))
	_hero.add_sourced_shield(&"guard", 100, _hero, {"tags": [&"guard"]})
	_hero.take_damage(10, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "attack_classification": &"PROJECTILE", "action_id": &"first_projectile"})
	_adapter.handle_relic_intent({"actor_id": _hero.get_runtime_stable_id(), "intent_id": &"projectile_counter",
		"item_id": &"mirror_athena", "damage_source_id": _enemy.get_runtime_stable_id(),
		"action_id": &"first_projectile", "amount_absorbed": 10, "parameters": {"reflect_ratio": 0.5}})
	_adapter.flush_automatic()
	var request := _adapter.pending_choice(_hero)
	assert_not_null(request)
	assert_true(_adapter.resolve_choice(_hero, request, null, &"relic:mirror_athena").get("resolved", false))
	assert_eq(_enemy.current_hp, 95, "Only the selected mirror reflects")
	_hero.take_damage(10, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "attack_classification": &"PROJECTILE", "action_id": &"second_projectile"})
	_adapter.flush_automatic()
	assert_eq(_enemy.current_hp, 89, "Sentinel's refused charge was restored")

func test_distinct_offenses_count_real_dash_impact_on_the_same_target() -> void:
	var fury := _effect(&"fury", &"track_distinct_offenses", &"spell_cast")
	fury.multiplier = 1.15
	fury.secondary_multiplier = 1.25
	fury.valid_spell_ids = [&"achilles_peleid_strike", &"achilles_pelion_shot", &"achilles_fulminant_dash"]
	var bastion := _effect(&"bastion", &"bastion_impact", &"movement_resolved")
	bastion.requires_guard = true
	bastion.ratio_value = 0.2
	bastion.cap_max_hp_ratio = 0.08
	_configure([fury, bastion])
	_caster.cast(_hero, _strike(), _enemy.grid_pos)
	assert_eq(_enemy.current_hp, 89)
	_grid.relocate_unit(_enemy, Vector2i(4, 2))
	_caster.cast(_hero, _hero.spells[2] as Spell, _enemy.grid_pos)
	assert_eq(_enemy.current_hp, 77, "Second distinct offensive spell gets 15 percent")
	_hero.add_sourced_shield(&"guard", 100, _hero, {"tags": [&"guard"]})
	_caster.cast(_hero, _hero.spells[1] as Spell, Vector2i(3, 2))
	assert_eq(_enemy.current_hp, 67, "Third actual technique impact gets 25 percent")


func _install_relic(item_id: StringName) -> RelicRuntimeService:
	var catalog := load("res://data/items/catalogs/odyssey_item_catalog.tres") as ItemCatalog
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog))
	assert_true(inventory.try_add(item_id).get("success", false))
	var service := RelicRuntimeService.new()
	_relic_services.append(service)
	assert_true(service.initialize(inventory, catalog, [_hero]))
	service.begin_combat([_hero, _enemy])
	var terrain := _adapter.terrain
	var pathfinder := _adapter.pathfinder
	_adapter.dispose()
	_adapter.configure(_grid, _caster, terrain, pathfinder, [_hero, _enemy], service)
	return service


func test_unchosen_real_mirror_keeps_its_charge_until_the_next_projectile() -> void:
	var sentinel := _effect(&"sentinel", &"automatic_attack", &"projectile_received")
	sentinel.requires_guard = true
	sentinel.target_spell_id = &"achilles_pelion_shot"
	sentinel.multiplier = 0.6
	sentinel.automatic_action = true
	sentinel.frequency = MasteryReactiveEffectData.Frequency.ONCE_PER_COMBAT
	_configure([sentinel])
	_install_relic(&"odyssey_athena_mirror")
	_grid.relocate_unit(_enemy, Vector2i(5, 2))
	_hero.add_sourced_shield(&"guard", 100, _hero, {"tags": [&"guard"]})
	_hero.take_damage(10, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "attack_classification": &"PROJECTILE", "action_id": &"mirror_first"})
	_adapter.flush_automatic()
	var request := _adapter.pending_choice(_hero)
	assert_not_null(request)
	assert_true(_adapter.resolve_choice(_hero, request, null, sentinel.source_id).get("resolved", false))
	_adapter.flush_automatic()
	assert_eq(_enemy.current_hp, 94, "Only Sentinel fired; Mirror retains its charge")
	_hero.take_damage(10, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "attack_classification": &"PROJECTILE", "action_id": &"mirror_second"})
	_adapter.flush_automatic()
	assert_eq(_enemy.current_hp, 89, "The previously refused Mirror now reflects 5")
	_hero.take_damage(10, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "attack_classification": &"PROJECTILE", "action_id": &"mirror_third"})
	_adapter.flush_automatic()
	assert_eq(_enemy.current_hp, 89, "Both combat charges are spent exactly once")


func test_mirror_ignores_full_absorption_split_between_guard_and_another_shield() -> void:
	_install_relic(&"odyssey_athena_mirror")
	_hero.add_sourced_shield(&"guard", 5, _hero, {"tags": [&"guard"], "priority": 10})
	_hero.add_sourced_shield(&"other", 5)
	_hero.take_damage(10, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "attack_classification": &"PROJECTILE", "action_id": &"split_absorption"})
	_adapter.flush_automatic()
	assert_eq(_hero.current_hp, 100)
	assert_eq(_enemy.current_hp, 100, "A collateral shield cannot satisfy full Guard absorption")
	_hero.add_sourced_shield(&"guard", 20, _hero, {"tags": [&"guard"]})
	_hero.take_damage(10, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "attack_classification": &"PROJECTILE", "action_id": &"full_guard_absorption"})
	_adapter.flush_automatic()
	assert_eq(_enemy.current_hp, 95, "The failed condition did not consume Mirror")


func test_zero_damage_collision_arms_real_nail_once() -> void:
	_install_relic(&"odyssey_hephaestus_nail")
	_enemy.armure.base_value = 80
	_grid.set_type(Vector2i(4, 2), GridData.CellType.WALL)
	var events: Array[int] = []
	var on_collision := func(_actor, _target, amount: int): events.append(amount)
	EventBus.collision_impact.connect(on_collision)
	var journal: Array = []
	var result := _caster._push_unit(_hero, _enemy, 1, 0, journal)
	EventBus.collision_impact.disconnect(on_collision)
	assert_true(result.collision)
	assert_eq(_enemy.current_hp, 100)
	assert_eq(_enemy.grid_pos, Vector2i(3, 2))
	assert_eq(events, [0])
	assert_eq(journal.size(), 1)
	assert_eq(_enemy.armure.get_int(), 40, "Actual collision fact arms Nail without collision damage")


func test_anchor_push_marks_each_victim_for_break_formation() -> void:
	var catalog := load("res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres") as MasteryCatalogData
	var node := catalog.node_catalog()[&"achilles_wrath_break_formation"] as SkillTreeNodeData
	assert_true(_hero.mastery_runtime.configure_from_nodes([node]).is_empty())
	_hero.mastery_nodes = [node]
	var second := Factory.make_unit("Second", 1)
	second.unit_id = &"second"
	_enemy.armure.base_value = 50
	second.armure.base_value = 50
	_grid.place_unit(second, Vector2i(2, 3))
	_adapter.attach_unit(second)
	_hero.add_sourced_shield(&"guard", 100, _hero, {"tags": [&"guard"]})
	var item := load("res://data/items/definitions/odyssey/thetis_anchor.tres") as ItemDefinition
	var intent := RelicEffectRegistry.new().build_tactical_intent(item.reactive_effects[0], {
		"actor_id": _hero.get_runtime_stable_id(), "item_id": item.item_id,
		"instance_id": &"anchor", "action_id": &"anchor_dash", "spell_id": &"achilles_fulminant_dash"})
	_adapter.handle_relic_intent(intent)
	_adapter.flush_automatic()
	assert_eq(_enemy.grid_pos, Vector2i(4, 2))
	assert_eq(second.grid_pos, Vector2i(2, 4))
	for target in [_enemy, second]:
		assert_eq(target.armure.get_int(), 25)
		assert_true(_hero.mastery_runtime.has_runtime_flag(&"wrath_break_formation_ready",
			MasteryReactiveEffectData.Scope.UNTIL_NEXT_ACTIVATION, _adapter.context_for(_hero, {"target": target})))


func test_target_bound_damage_bonus_does_not_spread_to_an_unmarked_area_victim() -> void:
	var catalog := load("res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres") as MasteryCatalogData
	var node := catalog.node_catalog()[&"achilles_wrath_break_formation"] as SkillTreeNodeData
	var scourge := catalog.node_catalog()[&"achilles_wrath_scourge_of_troy"] as SkillTreeNodeData
	assert_true(_hero.mastery_runtime.configure_from_nodes([node, scourge]).is_empty())
	_hero.mastery_nodes = [node, scourge]
	_hero.attack_power.base_value = 200
	_enemy.max_hp.base_value = 1000
	_enemy.current_hp = 1000
	var second := Factory.make_unit("Unmarked", 1)
	second.unit_id = &"unmarked"
	second.max_hp.base_value = 1000
	second.current_hp = 1000
	_grid.place_unit(second, Vector2i(4, 2))
	_adapter.attach_unit(second)
	_adapter.dispatch(_hero, &"unit_moved", {"target": _enemy, "forced_move": true})
	_caster.cast(_hero, _strike(), _enemy.grid_pos)
	assert_eq(_enemy.current_hp, 835, "132 damage receives the 25 percent marked-target bonus")
	assert_eq(second.current_hp, 923, "The second cell keeps its normal 77 damage")
	assert_false(_hero.mastery_runtime.has_runtime_flag(&"wrath_break_formation_ready",
		MasteryReactiveEffectData.Scope.UNTIL_NEXT_ACTIVATION, _adapter.context_for(_hero, {"target": _enemy})))


func test_counter_losing_its_target_in_the_queue_keeps_its_charge() -> void:
	var counter := _effect(&"queued_counter", &"automatic_attack", &"damage_received")
	counter.requires_guard = true
	counter.target_spell_id = &"achilles_peleid_strike"
	counter.multiplier = 0.7
	counter.automatic_action = true
	counter.frequency = MasteryReactiveEffectData.Frequency.ONCE_PER_COMBAT
	_configure([counter])
	_hero.add_sourced_shield(&"guard", 20, _hero, {"tags": [&"guard"]})
	_enemy.current_hp = 5
	_adapter.queue_automatic(_hero, _strike().spell_id, _enemy, 1.0, &"prior_automatic")
	_hero.take_damage(1, _enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "attack_classification": &"MELEE", "action_id": &"queued_first"})
	_adapter.flush_automatic()
	assert_eq(_enemy.current_hp, 0)
	var next := Factory.make_unit("Next", 1)
	next.unit_id = &"next"
	_grid.place_unit(next, Vector2i(2, 3))
	_adapter.attach_unit(next)
	_hero.take_damage(1, next, Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "attack_classification": &"MELEE", "action_id": &"queued_second"})
	_adapter.flush_automatic()
	assert_eq(next.current_hp, 92, "The counter cancelled after a queued kill did not spend its charge")


func test_mastery_created_shield_applies_resolution_once_after_a_real_elimination() -> void:
	var catalog := load("res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres") as MasteryCatalogData
	var node := catalog.node_catalog()[&"achilles_wrath_irrepressible_wrath"] as SkillTreeNodeData
	assert_true(_hero.mastery_runtime.configure_from_nodes([node]).is_empty())
	_hero.mastery_nodes = [node]
	_hero.shield_creation_multiplier = 1.5
	_hero.current_hp = 30
	_hero.start_turn()
	_hero.add_sourced_shield(&"existing", 7, _hero)
	_enemy.current_hp = 1
	_caster.cast(_hero, _strike(), _enemy.grid_pos)
	assert_eq(_enemy.current_hp, 0)
	assert_eq(_hero.get_shield_value(&"achilles_wrath_irrepressible_wrath.kill_shield"), 12,
		"8 percent of 100 HP creates 8 raw shield, then Resolution grants 12 exactly once")
	assert_eq(_hero.get_shield_value(&"existing"), 7, "Existing shield values are unchanged")
	_hero.start_turn()
	assert_eq(_hero.get_shield_value(&"achilles_wrath_irrepressible_wrath.kill_shield"), 0)


func test_bastion_spending_the_last_guard_point_removes_only_the_guard_aura() -> void:
	var catalog := load("res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres") as MasteryCatalogData
	var anchor := catalog.node_catalog()[&"achilles_aeacus_bronze_anchor"] as SkillTreeNodeData
	var bastion := _effect(&"last_guard_bastion", &"bastion_impact", &"movement_resolved")
	bastion.requires_guard = true
	bastion.ratio_value = 0.5
	bastion.cap_max_hp_ratio = 0.08
	bastion.flat_value = 1
	var effects: Array[MasteryReactiveEffectData] = []
	effects.assign(anchor.reactive_effects)
	effects.append(bastion)
	_configure(effects)
	_hero.armure.add_modifier(7.0, Stat.ModType.FLAT, "other_armor_source")
	var guard := _hero.spells[3] as Spell
	_caster.cast(_hero, guard, _hero.grid_pos)
	_hero.consume_shield_source(guard.spell_id, _hero.get_shield_value(guard.spell_id) - 1)
	_hero.add_sourced_shield(&"other", 4)
	assert_eq(_hero.get_shield_value(guard.spell_id), 1)
	assert_eq(_hero.armure.get_int(), 37)
	assert_true(_adapter.blocks_control(_hero, &"push"))
	assert_true(_adapter.blocks_control(_hero, &"pull"))
	_adapter.dispatch(_hero, &"movement_resolved", {"action_id": &"consume_last_guard"})
	_adapter.flush_automatic()
	assert_eq(_hero.get_shield_value(guard.spell_id), 0)
	assert_eq(_hero.get_shield_value(&"other"), 4)
	assert_eq(_hero.armure.get_int(), 7, "Only the armor tied to the expired Guard is removed")
	assert_false(_adapter.blocks_control(_hero, &"push"))
	assert_false(_adapter.blocks_control(_hero, &"pull"))
