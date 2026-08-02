extends GutTest

const Factory = preload("res://test/support/factory.gd")

func test_reset_combat_resources_restores_ap_and_mp() -> void:
	var unit := Factory.make_unit()
	unit.current_ap = 0
	unit.current_mp = 0
	unit.next_turn_ap_modifier = -2
	unit.next_turn_mp_bonus = 4
	unit.next_turn_mp_penalty = 1
	unit.reset_combat_resources()
	assert_eq(unit.current_ap, unit.max_ap.get_int())
	assert_eq(unit.current_mp, unit.max_mp.get_int())
	assert_eq(unit.next_turn_ap_modifier, 0)
	assert_eq(unit.next_turn_mp_bonus, 0)
	assert_eq(unit.next_turn_mp_penalty, 0)

func test_max_hp_reduction_clamps_current_hp_without_healing_on_increase() -> void:
	var unit := Factory.make_unit()
	unit.current_hp = 90
	unit.max_hp.add_modifier(-40.0, Stat.ModType.FLAT, "test_reduction")
	assert_eq(unit.max_hp.get_int(), 60)
	assert_eq(unit.current_hp, 60)
	unit.max_hp.remove_modifiers_from("test_reduction")
	assert_eq(unit.max_hp.get_int(), 100)
	assert_eq(unit.current_hp, 60)

func test_final_critical_chance_is_clamped_to_probability_bounds() -> void:
	var attacker := Factory.make_unit("Attaquant", 0)
	var target := Factory.make_unit("Cible", 1)
	var guaranteed := DamageResolver.HitContext.new()
	guaranteed.attacker = attacker
	guaranteed.raw_damage = 10
	guaranteed.bonus_crit_chance = 10.0
	guaranteed.cannot_be_dodged = true
	assert_true(DamageResolver.compute(target, guaranteed).is_crit)
	var impossible := DamageResolver.HitContext.new()
	impossible.attacker = attacker
	impossible.raw_damage = 10
	impossible.bonus_crit_chance = -10.0
	impossible.cannot_be_dodged = true
	assert_false(DamageResolver.compute(target, impossible).is_crit)

func test_damage_events_distinguish_resolved_hit_from_health_loss() -> void:
	var target := Factory.make_unit("Cible", 1)
	var attacker := Factory.make_unit("Attaquant", 0)
	var resolved_hits: Array = []
	var health_losses: Array = []
	var on_resolved := func(unit, source, amount, category, element, is_crit):
		resolved_hits.append([unit, source, amount, category, element, is_crit])
	var on_health := func(unit, source, amount, category, element, is_crit):
		health_losses.append([unit, source, amount, category, element, is_crit])
	EventBus.damage_dealt.connect(on_resolved)
	EventBus.health_damage_taken.connect(on_health)
	target.add_shield(10)
	target.take_damage(15, attacker, Spell.DamageType.PHYSICAL, Spell.Element.NONE, {
		"ignore_defense": true,
		"cannot_be_dodged": true,
	})
	EventBus.damage_dealt.disconnect(on_resolved)
	EventBus.health_damage_taken.disconnect(on_health)
	assert_eq(resolved_hits.size(), 1)
	assert_eq(health_losses.size(), 1)
	assert_eq(resolved_hits[0][2], 15)
	assert_eq(health_losses[0][2], 5)
	assert_eq(target.current_hp, 95)

func test_status_id_refreshes_without_second_application_event() -> void:
	var unit := Factory.make_unit()
	var first := StatusData.new()
	first.status_id = &"stable_status"
	first.status_name = "Premier libellé"
	first.duration = 2
	var second := StatusData.new()
	second.status_id = &"stable_status"
	second.status_name = "Nouveau libellé"
	second.duration = 4
	var counts := {"applied": 0, "refreshed": 0}
	var on_applied := func(_unit, _status): counts["applied"] += 1
	var on_refreshed := func(_unit, _status): counts["refreshed"] += 1
	EventBus.status_applied.connect(on_applied)
	EventBus.status_refreshed.connect(on_refreshed)
	unit.apply_status(first)
	unit.apply_status(second)
	EventBus.status_applied.disconnect(on_applied)
	EventBus.status_refreshed.disconnect(on_refreshed)
	assert_eq(unit.get_active_statuses().size(), 1)
	assert_eq(unit.get_active_statuses()[0]["remaining"], 4)
	assert_eq(counts["applied"], 1)
	assert_eq(counts["refreshed"], 1)

func test_periodic_damage_uses_status_metadata() -> void:
	var unit := Factory.make_unit()
	unit.armure.base_value = 100.0
	unit.esquive.base_value = 0.5
	var status := StatusData.new()
	status.status_id = &"metadata_dot"
	status.damage_per_turn = 7
	status.damage_type = Spell.DamageType.PHYSICAL
	status.element = Spell.Element.NONE
	status.ignores_defense = true
	status.can_be_dodged = false
	unit.apply_status(status)
	unit.process_statuses()
	assert_eq(unit.current_hp, 93)
