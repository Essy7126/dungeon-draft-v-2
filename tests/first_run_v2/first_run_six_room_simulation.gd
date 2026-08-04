extends Node

const RUN := preload("res://data/runs/first_run.tres")
const ITEM_CATALOG := preload("res://data/items/catalogs/default_item_catalog.tres")
const HERO_DATA := [
	preload("res://data/units/alliés/elfe.tres"),
	preload("res://data/units/alliés/mage.tres"),
	preload("res://data/units/alliés/Guerrier.tres"),
]
const PROFILE_SPECIALIZED: StringName = &"specialized"
const PROFILE_BALANCED: StringName = &"balanced"
const PROFILE_NO_PROGRESSION: StringName = &"no_progression"
const PROFILES := [
	PROFILE_SPECIALIZED,
	PROFILE_BALANCED,
	PROFILE_NO_PROGRESSION,
]
const SEED_COUNT := 20
const BASE_SEED := 24000
const MAX_ROUNDS := 12


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--probe-spawns"):
		_probe_room_spawns()
		get_tree().quit()
		return
	# Le banc conserve les mêmes calculs mais évite plusieurs dizaines de milliers
	# de lignes de journal, qui faussent fortement la mesure de performance.
	if not OS.get_cmdline_user_args().has("--verbose-simulation"):
		for category in DebugLogger.LogCategory.values():
			DebugLogger.enabled_categories[category] = false
	var selected_profiles := _selected_profiles()
	var selected_seed_count := _selected_seed_count()
	# Le moteur de production est le mode de validation par défaut. Le modèle
	# rapide reste disponible explicitement pour du diagnostic via `--model`.
	var use_runtime := not OS.get_cmdline_user_args().has("--model")
	var started := Time.get_ticks_msec()
	var runs: Array[Dictionary] = []
	for profile in selected_profiles:
		for seed_offset in selected_seed_count:
			runs.append(
				_simulate_run(StringName(profile), BASE_SEED + seed_offset)
				if use_runtime
				else _simulate_run_model(StringName(profile), BASE_SEED + seed_offset)
			)
	var payload := {
		"schema": 1,
		"simulation_mode": (
			"production_runtime"
			if use_runtime
			else "campaign_model_using_production_data"
		),
		"seed_count": selected_seed_count,
		"base_seed": BASE_SEED,
		"profiles": selected_profiles,
		"elapsed_ms": Time.get_ticks_msec() - started,
		"runs": runs,
		"summary": _aggregate(runs),
	}
	var mode_label := "runtime" if use_runtime else "model"
	var profile_label := "all" if selected_profiles.size() > 1 else str(selected_profiles[0])
	var relative_path := "artifacts/first_run_v2/simulation_%s.json" % profile_label
	if use_runtime:
		relative_path = "artifacts/first_run_v2/simulation_%s_%s.json" % [
			mode_label,
			profile_label,
		]
	var absolute_dir := ProjectSettings.globalize_path("res://artifacts/first_run_v2")
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var output := FileAccess.open("res://" + relative_path, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(payload, "\t"))
		output.close()
	print("FIRST_RUN_V2_SIMULATION_SUMMARY=" + JSON.stringify(payload.summary))
	print("FIRST_RUN_V2_SIMULATION_ARTIFACT=res://" + relative_path)
	get_tree().quit(0 if output != null and _validate_payload(
		payload,
		selected_profiles,
		selected_seed_count,
	) else 1)


func _probe_room_spawns() -> void:
	for room_index in RUN.rooms.size():
		var room := RUN.rooms[room_index] as RoomData
		var grid := _grid_for_room(room)
		var requested: Array = []
		for cell_value in room.hero_spawn_zone:
			var cell := cell_value as Vector2i
			requested.append({
				"cell": str(cell),
				"walkable": grid.is_walkable(cell),
				"type": grid.get_type(cell),
			})
		var walkable: Array[Vector2i] = []
		for x in grid.cols:
			for y in grid.rows:
				var candidate := Vector2i(x, y)
				if grid.is_walkable(candidate):
					walkable.append(candidate)
		var anchor := room.hero_spawn_zone[0] as Vector2i
		walkable.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var distance_a := grid.manhattan(a, anchor)
			var distance_b := grid.manhattan(b, anchor)
			if distance_a != distance_b:
				return distance_a < distance_b
			return a.y < b.y or (a.y == b.y and a.x < b.x)
		)
		print("ROOM_SPAWN_PROBE=", JSON.stringify({
			"room": room_index + 1,
			"requested": requested,
			"nearest_walkable": walkable.slice(0, mini(12, walkable.size())).map(str),
		}))


func _selected_profiles() -> Array:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--profile="):
			continue
		var requested := StringName(argument.trim_prefix("--profile="))
		if PROFILES.has(requested):
			return [requested]
	return PROFILES.duplicate()


func _selected_seed_count() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="):
			return clampi(int(argument.trim_prefix("--seeds=")), 1, SEED_COUNT)
	return SEED_COUNT


func _simulate_run_model(profile: StringName, run_seed: int) -> Dictionary:
	var states := _make_states()
	var inventory := RunInventory.new()
	var equipment := EquipmentService.new()
	var rewards := FirstRunEquipmentRewardService.new()
	inventory.initialize(ITEM_CATALOG, 24)
	equipment.initialize(ITEM_CATALOG)
	rewards.reset(ITEM_CATALOG, run_seed)
	var metrics := {
		"profile": profile,
		"seed": run_seed,
		"victory": false,
		"rooms_completed": 0,
		"transitions": 0,
		"rounds_by_room": [],
		"damage_received_by_room": [],
		"friendly_fire_damage_by_room": [],
		"hero_deaths_by_room": [],
		"failure_reasons_by_room": [],
		"xp_by_room": [],
		"ranks_by_room": [],
		"equipment_chosen": [],
		"normal_summons_resolved": 0,
		"chief_summons_resolved": 0,
		"peak_enemies": 0,
		"room_six_elapsed_ms": 0.0,
		"room_six_peak_runtime_units": 0,
		"full_rank_five_before_room_six": false,
	}
	for room_index in RUN.rooms.size():
		if _living_states(states) == 0:
			break
		var xp_before := _total_xp(states)
		var room_started := Time.get_ticks_usec()
		var result := _simulate_room_model(
			RUN.rooms[room_index],
			states,
			profile,
			run_seed,
			room_index,
		)
		metrics.rounds_by_room.append(result.rounds)
		metrics.damage_received_by_room.append(result.damage_received)
		metrics.friendly_fire_damage_by_room.append(result.get("friendly_fire_damage", 0))
		metrics.hero_deaths_by_room.append(result.hero_deaths)
		metrics.failure_reasons_by_room.append(result.get("reason", &""))
		metrics.xp_by_room.append(_total_xp(states) - xp_before)
		metrics.ranks_by_room.append(_rank_snapshot(states))
		metrics.normal_summons_resolved += result.normal_summons_resolved
		metrics.chief_summons_resolved += result.chief_summons_resolved
		metrics.peak_enemies = maxi(metrics.peak_enemies, result.peak_enemies)
		if room_index == 5:
			metrics.room_six_elapsed_ms = float(Time.get_ticks_usec() - room_started) / 1000.0
			metrics.room_six_peak_runtime_units = result.peak_runtime_units
		if not result.victory:
			break
		metrics.rooms_completed += 1
		if room_index < 5:
			metrics.transitions += 1
			if profile != PROFILE_NO_PROGRESSION:
				var chosen := _grant_reward(
					rewards,
					equipment,
					inventory,
					states,
					profile,
					run_seed,
					room_index,
				)
				if chosen != &"":
					metrics.equipment_chosen.append(chosen)
		if room_index < 5 and _all_disciplines_rank_five(states):
			metrics.full_rank_five_before_room_six = true
	metrics.victory = metrics.rooms_completed == 6
	metrics.final_hero_hp = states.map(func(state):
		return state.unit.current_hp if state.unit != null else 0
	)
	metrics.total_xp = _total_xp(states)
	metrics.final_ranks = _rank_snapshot(states)
	metrics.inventory_slots_used = inventory.get_slots().filter(
		func(instance): return instance != null
	).size()
	for state in states:
		state.dispose()
	return metrics


func _simulate_room_model(
		room: RoomData,
		states: Array[CharacterRunState],
		profile: StringName,
		run_seed: int,
		room_index: int
	) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 7919 + room_index * 104729 + str(profile).hash()
	seed(rng.seed)
	var enemies: Array[Unit] = []
	for data_value in room.encounter_definition.expanded_roster():
		var enemy := Unit.from_data(data_value as UnitData)
		enemy.reset_combat_resources()
		enemies.append(enemy)
	for state in states:
		if state.unit != null and state.unit.is_alive:
			state.unit.reset_combat_resources()
	var hp_before := _total_living_hp(states)
	var heroes_at_start := _living_states(states)
	var rounds := 0
	var peak_enemies := enemies.size()
	var normal_summons := 0
	var chief_summons := 0
	var xp_this_combat := {}
	while rounds < MAX_ROUNDS and _living_states(states) > 0 \
			and _living_enemies(enemies) > 0:
		rounds += 1
		for hero_index in states.size():
			var state := states[hero_index]
			var hero := state.unit
			if hero == null or not hero.is_alive or _living_enemies(enemies) == 0:
				continue
			hero.start_turn()
			var disciplines_awarded_this_activation := {}
			for action_index in 2:
				if _living_enemies(enemies) == 0:
					break
				var spell := _model_spell(
					hero,
					states,
					profile,
					room_index,
					rounds,
					hero_index,
					action_index,
				)
				if spell == null:
					break
				var ap_cost := maxi(1, hero.get_spell_ap_cost(spell))
				if hero.current_ap < ap_cost or not hero.spend_ap(ap_cost):
					continue
				var effective := _model_hero_action(
					state,
					spell,
					enemies,
					states,
					profile,
					rng,
				)
				if effective and profile != PROFILE_NO_PROGRESSION \
						and spell.discipline_id != &"" \
						and not disciplines_awarded_this_activation.has(spell.discipline_id):
					disciplines_awarded_this_activation[spell.discipline_id] = true
					_model_award_xp(state, spell.discipline_id, xp_this_combat)
					_resolve_pending_choices(states, profile, run_seed)
		_try_model_summons(
			room,
			enemies,
			rng,
			rounds,
			{"normal": normal_summons, "chief": chief_summons},
		)
		# Les compteurs sont recalculés depuis les rôles ajoutés par le modèle.
		normal_summons = maxi(
			normal_summons,
			_count_summoned_role(enemies, &"model_summoned_normal"),
		)
		chief_summons = maxi(
			chief_summons,
			_count_summoned_role(enemies, &"model_summoned_chief"),
		)
		peak_enemies = maxi(peak_enemies, _living_enemies(enemies))
		_model_enemy_actions(enemies, states, room_index, rng)
	var victory := _living_states(states) > 0 and _living_enemies(enemies) == 0
	return {
		"victory": victory,
		"reason": &"" if victory else &"combat_lost_or_round_cap",
		"rounds": rounds,
		"damage_received": maxi(0, hp_before - _total_living_hp(states)),
		"hero_deaths": heroes_at_start - _living_states(states),
		"normal_summons_resolved": normal_summons,
		"chief_summons_resolved": chief_summons,
		"peak_enemies": peak_enemies,
		"peak_runtime_units": enemies.size() + states.size(),
	}


func _model_spell(
		hero: Unit,
		states: Array[CharacterRunState],
		profile: StringName,
		room_index: int,
		round_number: int,
		hero_index: int,
		action_index: int
	) -> Spell:
	if hero.spells.is_empty():
		return null
	if profile == PROFILE_BALANCED:
		var needs_healing := states.any(func(candidate):
			return candidate.unit != null and candidate.unit.is_alive \
				and candidate.unit.get_hp_ratio() <= 0.55
		)
		if needs_healing and action_index == 0:
			for spell_value in hero.spells:
				var support := spell_value as Spell
				if support != null and support.is_healing():
					return support
		# Le profil équilibré conserve une rotation multi-discipline sur sa
		# seconde action, mais ouvre par son sort offensif le plus efficace.
		# Cela modélise un joueur polyvalent raisonnable, sans modifier les
		# ressources de gameplay ni donner un bonus artificiel au profil.
		if action_index == 0:
			var best_offensive: Spell = null
			for spell_value in hero.spells:
				var offensive := spell_value as Spell
				if offensive == null or offensive.damage <= 0:
					continue
				if best_offensive == null \
						or offensive.damage > best_offensive.damage \
						or (offensive.damage == best_offensive.damage \
							and str(offensive.spell_id) < str(best_offensive.spell_id)):
					best_offensive = offensive
			if best_offensive != null:
				return best_offensive
	if profile == PROFILE_SPECIALIZED:
		var preferred := {
			&"elf": &"mage",
			&"mage": &"mage_pyromancy",
			&"warrior": &"warrior_breaker",
		}.get(hero.unit_id, &"") as StringName
		for spell_value in hero.spells:
			var candidate := spell_value as Spell
			if candidate != null and candidate.discipline_id == preferred:
				return candidate
	var index := posmod(
		room_index + round_number + hero_index + action_index,
		hero.spells.size(),
	)
	return hero.spells[index] as Spell


func _model_hero_action(
		state: CharacterRunState,
	spell: Spell,
	enemies: Array[Unit],
	states: Array[CharacterRunState],
	_profile: StringName,
	rng: RandomNumberGenerator
	) -> bool:
	var hero := state.unit
	if spell != null and spell.is_healing():
		var wounded := states.filter(func(candidate):
			return candidate.unit != null and candidate.unit.is_alive \
				and candidate.unit.current_hp < candidate.unit.max_hp.get_int()
		)
		if not wounded.is_empty():
			wounded.sort_custom(func(a: CharacterRunState, b: CharacterRunState) -> bool:
				return a.unit.get_hp_ratio() < b.unit.get_hp_ratio()
			)
			var amount := spell.heal + _model_flat_effect_bonus(
				state,
				spell,
				SpellModSkillTreeEffect.EffectType.HEAL,
			)
			amount = roundi(float(amount) * _model_support_multiplier(hero, spell))
			var healed_unit := wounded[0].unit as Unit
			var hp_before := healed_unit.current_hp
			healed_unit.heal(maxi(1, amount), hero)
			return healed_unit.current_hp > hp_before
	if spell != null and spell.shield_grant > 0:
		var protected := states.filter(func(candidate):
			return candidate.unit != null and candidate.unit.is_alive
		)
		if not protected.is_empty():
			protected.sort_custom(func(a: CharacterRunState, b: CharacterRunState) -> bool:
				if a.unit.current_shield != b.unit.current_shield:
					return a.unit.current_shield < b.unit.current_shield
				return a.unit.get_hp_ratio() < b.unit.get_hp_ratio()
			)
			var shield := spell.shield_grant + _model_flat_effect_bonus(
				state,
				spell,
				SpellModSkillTreeEffect.EffectType.SHIELD_TARGET,
			)
			shield = roundi(float(shield) * _model_support_multiplier(hero, spell))
			var protected_unit := protected[0].unit as Unit
			var shield_before := protected_unit.current_shield
			protected_unit.add_shield(maxi(1, shield), hero)
			return protected_unit.current_shield > shield_before
	var living := enemies.filter(func(enemy): return enemy.is_alive)
	if living.is_empty():
		return false
	living.sort_custom(func(a: Unit, b: Unit) -> bool:
		if a.current_hp != b.current_hp:
			return a.current_hp < b.current_hp
		return a.get_runtime_stable_id() < b.get_runtime_stable_id()
	)
	var target := living[0] as Unit
	var damage := hero.get_attack()
	var category := Spell.DamageType.PHYSICAL
	var element := Spell.Element.NONE
	if spell != null and spell.damage > 0:
		damage = spell.damage
		category = spell.damage_type
		element = spell.element
	damage += _model_damage_bonus(state, spell, target)
	damage = roundi(float(damage) * _model_damage_multiplier(hero, spell, target))
	damage = maxi(1, roundi(float(damage) * rng.randf_range(0.94, 1.06)))
	var hp_before := target.current_hp
	target.take_damage(damage, hero, category, element)
	if spell != null and spell.aoe_size > 0 and living.size() > 1:
		(living[1] as Unit).take_damage(
			maxi(1, roundi(float(damage) * 0.35)),
			hero,
			category,
			element,
		)
	return target.current_hp < hp_before


func _model_damage_bonus(
		state: CharacterRunState,
		spell: Spell,
		target: Unit
	) -> int:
	if spell == null:
		return 0
	var bonus := 0
	for modifier_value in state.get_active_progression_spell_modifiers():
		var modifier := modifier_value as SpellModifier
		if modifier == null or not modifier.applies_to(spell):
			continue
		if modifier is SpellModSkillTreeEffect:
			var tree_effect := modifier as SpellModSkillTreeEffect
			match tree_effect.effect_type:
				SpellModSkillTreeEffect.EffectType.DAMAGE_ALL, \
				SpellModSkillTreeEffect.EffectType.DAMAGE_CENTER:
					bonus += tree_effect.amount
				SpellModSkillTreeEffect.EffectType.DAMAGE_LOW_HP, \
				SpellModSkillTreeEffect.EffectType.DAMAGE_BACKSTAB_OR_LOW_HP:
					if target.get_hp_ratio() < tree_effect.threshold_ratio:
						bonus += tree_effect.amount
		elif modifier is SpellModDamageBonusAtMinRange:
			bonus += (modifier as SpellModDamageBonusAtMinRange).bonus_damage
		elif modifier.get("bonus_damage") != null:
			bonus += int(modifier.get("bonus_damage"))
	return bonus


func _model_damage_multiplier(hero: Unit, spell: Spell, target: Unit) -> float:
	if spell == null:
		return 1.0
	var multiplier := 1.0
	for modifier_value in hero.get_equipment_spell_modifiers():
		var modifier := modifier_value as SpellModifier
		if not modifier is ItemSpellModifierData:
			continue
		var equipment_modifier := modifier as ItemSpellModifierData
		if not equipment_modifier.applies_to(spell):
			continue
		if equipment_modifier.target_hp_at_or_below >= 0.0 \
				and target.get_hp_ratio() > equipment_modifier.target_hp_at_or_below:
			continue
		multiplier += equipment_modifier.damage_percent
	return multiplier


func _model_flat_effect_bonus(
		state: CharacterRunState,
		spell: Spell,
		effect_type: int
	) -> int:
	var bonus := 0
	for modifier_value in state.get_active_progression_spell_modifiers():
		var modifier := modifier_value as SpellModifier
		if modifier == null or not modifier.applies_to(spell):
			continue
		if modifier is SpellModSkillTreeEffect \
				and (modifier as SpellModSkillTreeEffect).effect_type == effect_type:
			bonus += (modifier as SpellModSkillTreeEffect).amount
		elif effect_type == SpellModSkillTreeEffect.EffectType.HEAL \
				and modifier.get("bonus_heal") != null:
			bonus += int(modifier.get("bonus_heal"))
	return bonus


func _model_support_multiplier(hero: Unit, spell: Spell) -> float:
	var multiplier := 1.0
	for modifier_value in hero.get_equipment_spell_modifiers():
		var modifier := modifier_value as SpellModifier
		if modifier is ItemSpellModifierData \
				and (modifier as ItemSpellModifierData).applies_to(spell):
			multiplier += (modifier as ItemSpellModifierData).healing_and_shield_percent
	return multiplier


func _model_award_xp(
		state: CharacterRunState,
		discipline_id: StringName,
		xp_this_combat: Dictionary
	) -> void:
	if discipline_id == &"":
		return
	var key := "%s|%s" % [state.character_id, discipline_id]
	var awarded := int(xp_this_combat.get(key, 0))
	if awarded >= CharacterProgressionService.MAX_DISCIPLINE_XP_PER_COMBAT:
		return
	state.add_discipline_xp(discipline_id, 1)
	xp_this_combat[key] = awarded + 1


func _try_model_summons(
		room: RoomData,
		enemies: Array[Unit],
		rng: RandomNumberGenerator,
		round_number: int,
		_committed: Dictionary
	) -> void:
	var definition := room.encounter_definition
	if definition == null or _living_enemies(enemies) >= definition.living_enemy_cap:
		return
	var living_centurions := enemies.filter(func(enemy):
		return enemy.is_alive and enemy.tactical_role_id == &"skeleton_centurion"
	)
	if living_centurions.is_empty():
		return
	var normal_count := _count_summoned_role(enemies, &"model_summoned_normal")
	if normal_count < definition.shared_normal_summon_budget \
			and round_number >= 2 and rng.randf() < 0.55:
		var normal_data := load("res://data/units/ennemie/skeleton_melee.tres") as UnitData
		var normal := Unit.from_data(normal_data)
		normal.unit_id = &"model_summoned_normal"
		enemies.append(normal)
		return
	var chief_count := _count_summoned_role(enemies, &"model_summoned_chief")
	var weakened_centurion := living_centurions.any(func(enemy): return enemy.current_hp <= 75)
	if chief_count < definition.shared_chief_summon_budget \
			and weakened_centurion and rng.randf() < 0.45:
		var chief_data := load("res://data/units/ennemie/skeleton_chief.tres") as UnitData
		var chief := Unit.from_data(chief_data)
		chief.unit_id = &"model_summoned_chief"
		chief.current_hp = mini(154, chief.max_hp.get_int())
		enemies.append(chief)


func _model_enemy_actions(
		enemies: Array[Unit],
		states: Array[CharacterRunState],
		room_index: int,
		rng: RandomNumberGenerator
	) -> void:
	var contact_chance: float = [0.20, 0.24, 0.31, 0.39, 0.52, 0.61][room_index]
	for enemy in enemies:
		if not enemy.is_alive or rng.randf() > contact_chance:
			continue
		var living_states := states.filter(func(state):
			return state.unit != null and state.unit.is_alive
		)
		if living_states.is_empty():
			return
		var target_state := living_states[rng.randi_range(0, living_states.size() - 1)] \
			as CharacterRunState
		var damage := maxi(1, roundi(float(enemy.get_attack()) * rng.randf_range(0.88, 1.12)))
		target_state.unit.take_damage(damage, enemy, Spell.DamageType.PHYSICAL)


func _count_summoned_role(enemies: Array[Unit], unit_id: StringName) -> int:
	return enemies.filter(func(enemy): return enemy.unit_id == unit_id).size()


func _living_enemies(enemies: Array[Unit]) -> int:
	return enemies.filter(func(enemy): return enemy.is_alive).size()


func _total_living_hp(states: Array[CharacterRunState]) -> int:
	var total := 0
	for state in states:
		if state.unit != null and state.unit.is_alive:
			total += state.unit.current_hp
	return total


func _simulate_run(profile: StringName, run_seed: int) -> Dictionary:
	var states := _make_states()
	var state_index := {}
	for state in states:
		state_index[state.character_id] = state
	var inventory := RunInventory.new()
	var equipment := EquipmentService.new()
	var rewards := FirstRunEquipmentRewardService.new()
	var progression := CharacterProgressionService.new()
	inventory.initialize(ITEM_CATALOG, 24)
	equipment.initialize(ITEM_CATALOG)
	rewards.reset(ITEM_CATALOG, run_seed)
	progression.reset_run()
	var metrics := {
		"profile": profile,
		"seed": run_seed,
		"victory": false,
		"rooms_completed": 0,
		"transitions": 0,
		"rounds_by_room": [],
		"damage_received_by_room": [],
		"friendly_fire_damage_by_room": [],
		"hero_deaths_by_room": [],
		"failure_reasons_by_room": [],
		"xp_by_room": [],
		"ranks_by_room": [],
		"equipment_chosen": [],
		"normal_summons_resolved": 0,
		"chief_summons_resolved": 0,
		"peak_enemies": 0,
		"room_six_elapsed_ms": 0.0,
		"room_six_peak_runtime_units": 0,
		"full_rank_five_before_room_six": false,
	}
	for room_index in RUN.rooms.size():
		if _living_states(states) == 0:
			break
		var xp_before := _total_xp(states)
		progression.begin_combat()
		var room_started := Time.get_ticks_usec()
		var result := _simulate_room(
			RUN.rooms[room_index],
			states,
			state_index,
			progression,
			profile,
			run_seed,
			room_index,
		)
		metrics.rounds_by_room.append(result.rounds)
		metrics.damage_received_by_room.append(result.damage_received)
		metrics.friendly_fire_damage_by_room.append(result.get("friendly_fire_damage", 0))
		metrics.hero_deaths_by_room.append(result.hero_deaths)
		metrics.failure_reasons_by_room.append(result.get("reason", &""))
		metrics.xp_by_room.append(_total_xp(states) - xp_before)
		metrics.ranks_by_room.append(_rank_snapshot(states))
		metrics.normal_summons_resolved += result.normal_summons_resolved
		metrics.chief_summons_resolved += result.chief_summons_resolved
		metrics.peak_enemies = maxi(metrics.peak_enemies, result.peak_enemies)
		if room_index == 5:
			metrics.room_six_elapsed_ms = float(Time.get_ticks_usec() - room_started) / 1000.0
			metrics.room_six_peak_runtime_units = result.peak_runtime_units
		if not result.victory:
			break
		metrics.rooms_completed += 1
		if room_index < 5:
			metrics.transitions += 1
			if profile != PROFILE_NO_PROGRESSION:
				var chosen := _grant_reward(
					rewards,
					equipment,
					inventory,
					states,
					profile,
					run_seed,
					room_index,
				)
				if chosen != &"":
					metrics.equipment_chosen.append(chosen)
		if room_index < 5 and _all_disciplines_rank_five(states):
			metrics.full_rank_five_before_room_six = true
	metrics.victory = metrics.rooms_completed == 6
	metrics.final_hero_hp = states.map(func(state):
		return state.unit.current_hp if state.unit != null else 0
	)
	metrics.total_xp = _total_xp(states)
	metrics.final_ranks = _rank_snapshot(states)
	metrics.inventory_slots_used = inventory.get_slots().filter(
		func(instance): return instance != null
	).size()
	for state in states:
		state.dispose()
	return metrics


func _simulate_room(
		room: RoomData,
		states: Array[CharacterRunState],
		state_index: Dictionary,
		progression: CharacterProgressionService,
	profile: StringName,
	run_seed: int,
	room_index: int
	) -> Dictionary:
	# DamageResolver et les esquives utilisent le RNG global de Godot : le
	# resemer par salle garantit le même résultat quel que soit l'ordre dans
	# lequel les profils sont lancés.
	seed(run_seed * 7919 + room_index * 104729 + str(profile).hash())
	var grid := _grid_for_room(room)
	var pathfinder := Pathfinder.new(grid)
	var terrain := TerrainEffects.new(grid)
	var caster := SpellCaster.new(grid, pathfinder, terrain)
	var enemy_ai := EnemyAI.new(grid, pathfinder, caster)
	var encounter_runtime := EncounterRuntimeState.new()
	encounter_runtime.initialize(room.encounter_definition)
	caster.set_encounter_runtime_state(encounter_runtime)
	var units: Array = []
	var death_connections: Array[Dictionary] = []
	# La production planifie le roster ennemi avant le déploiement manuel des
	# héros. Garder cet ordre évite de considérer les cases de déploiement déjà
	# occupées comme une zone invalide lorsque la zone contient exactement trois
	# cellules pour trois héros.
	var planner := EncounterFormationPlanner.new(grid, pathfinder)
	var plan := planner.build_plan(
		room.encounter_definition,
		room.hero_spawn_zone,
		room.enemy_spawn_zone,
		run_seed,
	)
	if not plan.get("valid", false):
		return _room_failure(StringName(plan.get("reason", &"placement")))
	var hero_spawn_cursor := 0
	for state in states:
		var hero := state.unit as Unit
		if hero == null or not hero.is_alive:
			continue
		hero.reset_combat_resources()
		while hero_spawn_cursor < room.hero_spawn_zone.size() \
				and not grid.is_walkable(room.hero_spawn_zone[hero_spawn_cursor]):
			hero_spawn_cursor += 1
		if hero_spawn_cursor >= room.hero_spawn_zone.size():
			return _room_failure(StringName(
				"hero_spawn_missing_cursor_%d_zone_%d_units_%d_states_%d" % [
					hero_spawn_cursor,
					room.hero_spawn_zone.size(),
					grid.get_units().size(),
					states.size(),
				]
			))
		grid.place_unit(hero, room.hero_spawn_zone[hero_spawn_cursor])
		hero_spawn_cursor += 1
		units.append(hero)
		_connect_death_cleanup(hero, grid, death_connections)
	for placement_value in plan.get("placements", []):
		var placement := placement_value as Dictionary
		var enemy := Unit.from_data(placement.get("unit_data") as UnitData)
		enemy.reset_combat_resources()
		if not grid.place_unit(enemy, placement.get("cell", Vector2i(-1, -1))):
			_release_room(grid, units, death_connections)
			return _room_failure(&"enemy_spawn_failed")
		units.append(enemy)
		_connect_death_cleanup(enemy, grid, death_connections)
	var room_damage := {"value": 0, "friendly": 0}
	var summons := {&"call_bones": 0, &"raise_chief": 0}
	var on_health_damage := func(
			target: Unit,
		attacker,
			amount: int,
			_category,
			_element,
			_is_crit
		) -> void:
		if target != null and target.team == 0:
			room_damage.value = int(room_damage.value) + amount
			if attacker is Unit and (attacker as Unit).team == target.team:
				room_damage.friendly = int(room_damage.friendly) + amount
	var on_summon := func(
			_caster: Unit,
			_summoned: Unit,
			_cell: Vector2i,
			ability_id: StringName
		) -> void:
		if summons.has(ability_id):
			summons[ability_id] = int(summons[ability_id]) + 1
	EventBus.health_damage_taken.connect(on_health_damage)
	EventBus.summon_resolved.connect(on_summon)
	var rounds := 0
	var peak_enemies := grid.count_living_in_team(1)
	var peak_runtime_units := units.size()
	var heroes_at_start := _living_team(units, 0)
	while rounds < MAX_ROUNDS and _living_team(units, 0) > 0 \
			and _living_team(units, 1) > 0:
		rounds += 1
		var order := units.filter(func(value): return (value as Unit).is_alive)
		order.sort_custom(_initiative_order)
		for unit_value in order:
			var unit := unit_value as Unit
			if unit == null or not unit.is_alive:
				continue
			for participant_value in units:
				(participant_value as Unit).on_actor_activation_started(unit)
			unit.start_turn()
			terrain.on_turn_start(unit)
			unit.process_statuses()
			if not unit.is_alive:
				continue
			var pending := caster.resolve_pending_activation(
				unit,
				units,
				null,
				func(summoned: Unit) -> void:
					_connect_death_cleanup(summoned, grid, death_connections)
			)
			if not pending.consume_activation:
				if unit.team == 1:
					_execute_enemy_plan(unit, units, enemy_ai, caster, grid)
				else:
					_execute_hero_turn(
						unit,
						units,
						state_index,
						progression,
						profile,
						caster,
						pathfinder,
						grid,
						run_seed,
						room_index,
						rounds,
					)
			unit.tick_statuses()
			peak_enemies = maxi(peak_enemies, grid.count_living_in_team(1))
			peak_runtime_units = maxi(peak_runtime_units, units.size())
			if _living_team(units, 0) == 0 or _living_team(units, 1) == 0:
				break
	var victory := _living_team(units, 0) > 0 and _living_team(units, 1) == 0
	if EventBus.health_damage_taken.is_connected(on_health_damage):
		EventBus.health_damage_taken.disconnect(on_health_damage)
	if EventBus.summon_resolved.is_connected(on_summon):
		EventBus.summon_resolved.disconnect(on_summon)
	var result := {
		"victory": victory,
		"reason": &"" if victory else &"combat_lost_or_round_cap",
		"rounds": rounds,
		"damage_received": int(room_damage.value),
		"friendly_fire_damage": int(room_damage.friendly),
		"hero_deaths": heroes_at_start - _living_team(units, 0),
		"normal_summons_resolved": int(summons[&"call_bones"]),
		"chief_summons_resolved": int(summons[&"raise_chief"]),
		"peak_enemies": peak_enemies,
		"peak_runtime_units": peak_runtime_units,
	}
	_release_room(grid, units, death_connections)
	return result


func _execute_hero_turn(
		hero: Unit,
		units: Array,
		state_index: Dictionary,
		progression: CharacterProgressionService,
		profile: StringName,
		caster: SpellCaster,
		pathfinder: Pathfinder,
		grid: GridData,
	run_seed: int,
	room_index: int,
	round_number: int
	) -> void:
	var spells := _ordered_spells(hero, profile, room_index, round_number)
	var moved := false
	var action_steps := 0
	var spell_uses: Dictionary = {}
	while hero.is_alive and hero.current_ap > 0 and action_steps < 8:
		action_steps += 1
		if profile != PROFILE_SPECIALIZED:
			var needs_healing := units.any(func(value):
				var ally := value as Unit
				return ally != null and ally.is_alive and ally.team == hero.team \
					and ally.get_hp_ratio() <= 0.75
			)
			if needs_healing:
				for spell_value in spells:
					var support := spell_value as Spell
					if support != null and support.is_healing():
						spells.erase(support)
						spells.push_front(support)
						break
		var choice := _find_cast_choice(hero, spells, units, caster, grid)
		if choice.is_empty() and not moved:
			_move_toward_nearest_enemy(hero, units, pathfinder, grid)
			moved = true
			choice = _find_cast_choice(hero, spells, units, caster, grid)
		if choice.is_empty():
			break
		var report := caster.cast(
			hero,
			choice.spell as Spell,
			choice.cell as Vector2i,
		)
		if not report.get("failed", false) and profile != PROFILE_NO_PROGRESSION:
			progression.grant_cast_xp(
				state_index,
				hero,
				choice.spell as Spell,
				report,
			)
			_resolve_pending_choices(state_index.values(), profile, run_seed)
		if report.get("failed", false):
			break
		if profile != PROFILE_SPECIALIZED:
			var used_spell := choice.spell as Spell
			var use_count := int(spell_uses.get(used_spell.spell_id, 0)) + 1
			spell_uses[used_spell.spell_id] = use_count
			if use_count >= 8:
				spells.erase(used_spell)
				spells.append(used_spell)
	if hero.can_use_basic_attack():
		var adjacent := _nearest_enemy(hero, units, grid)
		if adjacent != null and grid.are_adjacent(hero.grid_pos, adjacent.grid_pos) \
				and hero.spend_ap(hero.get_basic_attack_ap_cost()):
			adjacent.take_damage(hero.get_attack(), hero, Spell.DamageType.PHYSICAL)


func _find_cast_choice(
		hero: Unit,
		spells: Array,
		units: Array,
		caster: SpellCaster,
		grid: GridData
	) -> Dictionary:
	for spell_value in spells:
		var spell := spell_value as Spell
		if spell == null or not hero.can_use_spell(spell) \
				or hero.current_ap < hero.get_spell_ap_cost(spell):
			continue
		var targetable := caster.get_targetable_cells(hero, spell)
		var allies := units.filter(func(value):
			var unit := value as Unit
			return unit.is_alive and unit.team == hero.team
		)
		if spell.is_healing() or spell.shield_grant > 0:
			allies.sort_custom(func(a: Unit, b: Unit) -> bool:
				return (a.max_hp.get_int() - a.current_hp) > (b.max_hp.get_int() - b.current_hp)
			)
			for ally_value in allies:
				var ally := ally_value as Unit
				if targetable.has(ally.grid_pos) and (
					ally.current_hp < ally.max_hp.get_int() or ally.current_shield == 0
				):
					return {"spell": spell, "cell": ally.grid_pos}
		var enemies := units.filter(func(value):
			var unit := value as Unit
			return unit.is_alive and unit.team != hero.team
		)
		if spell.damage > 0 and spell.aoe_shape != Spell.AoeShape.SINGLE:
			var safe_aoe_cell := _best_safe_offensive_cell(
				hero,
				spell,
				targetable,
				units,
				caster,
			)
			if safe_aoe_cell != Vector2i(-1, -1):
				return {"spell": spell, "cell": safe_aoe_cell}
		enemies.sort_custom(func(a: Unit, b: Unit) -> bool:
			var score_a := _target_priority(hero, a, grid)
			var score_b := _target_priority(hero, b, grid)
			return score_a > score_b
		)
		for enemy_value in enemies:
			var enemy := enemy_value as Unit
			if targetable.has(enemy.grid_pos):
				return {"spell": spell, "cell": enemy.grid_pos}
		if spell.is_self_only() and targetable.has(hero.grid_pos):
			return {"spell": spell, "cell": hero.grid_pos}
	return {}


func _best_safe_offensive_cell(
	hero: Unit,
	spell: Spell,
	targetable: Array,
	units: Array,
	caster: SpellCaster
	) -> Vector2i:
	var candidates: Array[Dictionary] = []
	for cell_value in targetable:
		var cell := cell_value as Vector2i
		var affected := caster.get_aoe_cells(spell, cell, hero.grid_pos)
		var enemy_hits := 0
		var enemy_hp := 0
		var ally_hits := 0
		for unit_value in units:
			var unit := unit_value as Unit
			if unit == null or not unit.is_alive:
				continue
			if unit.team == hero.team:
				if affected.has(unit.grid_pos):
					ally_hits += 1
			elif affected.has(unit.grid_pos):
				enemy_hits += 1
				enemy_hp += unit.current_hp
		if enemy_hits > 0 and ally_hits == 0:
			candidates.append({
				"cell": cell,
				"enemy_hits": enemy_hits,
				"enemy_hp": enemy_hp,
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.enemy_hits) != int(b.enemy_hits):
			return int(a.enemy_hits) > int(b.enemy_hits)
		if int(a.enemy_hp) != int(b.enemy_hp):
			return int(a.enemy_hp) < int(b.enemy_hp)
		var cell_a := a.cell as Vector2i
		var cell_b := b.cell as Vector2i
		return cell_a.y < cell_b.y or (cell_a.y == cell_b.y and cell_a.x < cell_b.x)
	)
	return candidates[0].cell as Vector2i if not candidates.is_empty() \
		else Vector2i(-1, -1)


func _ordered_spells(
		hero: Unit,
		profile: StringName,
		room_index: int,
		round_number: int
	) -> Array:
	var spells := hero.spells.duplicate()
	if spells.is_empty():
		return spells
	if profile == PROFILE_SPECIALIZED:
		var preferred := {
			&"elf": &"mage",
			&"mage": &"mage_pyromancy",
			&"warrior": &"warrior_breaker",
		}.get(hero.unit_id, &"") as StringName
		spells.sort_custom(func(a: Spell, b: Spell) -> bool:
			return (a.discipline_id == preferred) and b.discipline_id != preferred
		)
		return spells
	spells.sort_custom(func(a: Spell, b: Spell) -> bool:
		if a.damage != b.damage:
			return a.damage > b.damage
		return str(a.spell_id) < str(b.spell_id)
	)
	var rotation := posmod(room_index + round_number + hero.activation_index, spells.size())
	if posmod(room_index + round_number + hero.activation_index, 4) == 0:
		spells.append(spells.pop_front())
	if rotation > 0:
		# Le premier sort reste l'ouverture efficace; le reste de la rotation
		# varie de façon déterministe pour exercer plusieurs disciplines.
		var tail := spells.slice(1)
		for _index in posmod(rotation, maxi(1, tail.size())):
			tail.append(tail.pop_front())
		spells = [spells[0]] + tail
	return spells


func _execute_enemy_plan(
		enemy: Unit,
		units: Array,
		enemy_ai: EnemyAI,
		caster: SpellCaster,
		grid: GridData
	) -> void:
	var action_plan := enemy_ai.build_action_plan(enemy, units)
	for action_value in action_plan.actions:
		var action := action_value as Dictionary
		if not enemy.is_alive:
			break
		match StringName(action.get("type", &"")):
			&"move":
				var path := action.get("path", []) as Array
				if path.size() >= 2:
					var steps := mini(enemy.current_mp, path.size() - 1)
					var destination := path[steps] as Vector2i
					if enemy.spend_mp(steps):
						grid.relocate_unit(enemy, destination)
			&"cast":
				var spell := action.get("spell") as Spell
				var cell := action.get("cell", Vector2i(-1, -1)) as Vector2i
				if spell != null:
					caster.cast(enemy, spell, cell)
			&"attack":
				var target := action.get("target") as Unit
				if target != null and target.is_alive \
						and grid.are_adjacent(enemy.grid_pos, target.grid_pos) \
						and enemy.spend_ap(enemy.get_basic_attack_ap_cost()):
					target.take_damage(enemy.get_attack(), enemy, Spell.DamageType.PHYSICAL)


func _move_toward_nearest_enemy(
		hero: Unit,
		units: Array,
		pathfinder: Pathfinder,
		grid: GridData
	) -> void:
	var target := _nearest_enemy(hero, units, grid)
	if target == null:
		return
	var best_path: Array = []
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var edge: Vector2i = target.grid_pos + direction
		if not grid.is_walkable(edge):
			continue
		var path := pathfinder.find_path(hero.grid_pos, edge, hero)
		if path.size() >= 2 and (best_path.is_empty() or path.size() < best_path.size()):
			best_path = path
	if best_path.is_empty():
		return
	var steps := mini(hero.current_mp, best_path.size() - 1)
	if steps > 0 and hero.spend_mp(steps):
		grid.relocate_unit(hero, best_path[steps])


func _resolve_pending_choices(states: Array, profile: StringName, run_seed: int) -> void:
	if profile == PROFILE_NO_PROGRESSION:
		return
	var made_progress := true
	var guard := 0
	while made_progress and guard < 64:
		guard += 1
		made_progress = false
		for state_value in states:
			var state := state_value as CharacterRunState
			if state == null:
				continue
			for choice_value in state.get_pending_progression_choices():
				var choice := choice_value as Dictionary
				var available := choice.get("choices", []) as Array
				if available.is_empty():
					continue
				var selected_index := 0
				if profile == PROFILE_BALANCED:
					selected_index = posmod(
						run_seed + int(choice.get("rank", 0)) + str(choice.get("discipline_id", &"")).hash(),
						available.size(),
					)
				var upgrade := available[selected_index] as SkillUpgradeData
				if state.select_upgrade(
					StringName(choice.get("discipline_id", &"")),
					int(choice.get("rank", 0)),
					upgrade.upgrade_id,
				):
					made_progress = true
					break


func _grant_reward(
		rewards: FirstRunEquipmentRewardService,
		equipment: EquipmentService,
		inventory: RunInventory,
		states: Array[CharacterRunState],
		profile: StringName,
		run_seed: int,
		room_index: int
	) -> StringName:
	var report := CombatReport.new()
	report.report_id = StringName("sim_%s_%d_%d" % [profile, run_seed, room_index])
	report.room_index = room_index
	report.room_name = RUN.rooms[room_index].room_name
	report.finalized = true
	report.victory = true
	var options := rewards.build_options(report, states, inventory, false)
	if options.size() != 2:
		return &""
	var option_index := 0
	if _model_reward_score(options[1] as Dictionary, profile) \
			> _model_reward_score(options[0] as Dictionary, profile):
		option_index = 1
	var option := options[option_index] as Dictionary
	var compatible := option.get("compatible_character_ids", []) as Array
	if compatible.is_empty():
		return &""
	var recipient_id := StringName(compatible[0])
	if compatible.size() > 1:
		var compatible_states := states.filter(func(state):
			return compatible.has(state.character_id)
		)
		compatible_states.sort_custom(func(a: CharacterRunState, b: CharacterRunState) -> bool:
			if not is_equal_approx(a.unit.get_hp_ratio(), b.unit.get_hp_ratio()):
				return a.unit.get_hp_ratio() < b.unit.get_hp_ratio()
			return str(a.character_id) < str(b.character_id)
		)
		if not compatible_states.is_empty():
			recipient_id = (compatible_states[0] as CharacterRunState).character_id
	var result := rewards.apply(
		report,
		StringName(option.get("item_id", &"")),
		recipient_id,
		states,
		inventory,
		equipment,
	)
	return StringName(result.get("item_id", &"")) if result.get("success", false) else &""


func _model_reward_score(option: Dictionary, profile: StringName) -> float:
	var definition := option.get("definition") as ItemDefinition
	if definition == null:
		return -INF
	var offense := 0.0
	var defense := 0.0
	for modifier in definition.stat_modifiers:
		match modifier.stat_id:
			&"max_hp": defense += modifier.value * 0.4
			&"armure", &"resist_magique": defense += modifier.value * 0.25
			&"resistance_ice", &"esquive": defense += modifier.value * 100.0
			&"attack_power": offense += modifier.value * 4.0
			&"max_ap": offense += modifier.value * 18.0
			&"max_mp": defense += modifier.value * 7.0
	for modifier_value in definition.spell_modifiers:
		if modifier_value is ItemSpellModifierData:
			var modifier := modifier_value as ItemSpellModifierData
			offense += modifier.damage_percent * 100.0
			offense += float(modifier.range_bonus + modifier.push_bonus) * 6.0
			defense += modifier.healing_and_shield_percent * 100.0
	return (
		offense * 1.35 + defense
		if profile == PROFILE_SPECIALIZED
		else defense * 1.25 + offense
	)


func _make_states() -> Array[CharacterRunState]:
	var states: Array[CharacterRunState] = []
	for data_value in HERO_DATA:
		var data := data_value as UnitData
		var state := CharacterRunState.new()
		state.initialize(Unit.from_data(data), data)
		states.append(state)
	return states


func _grid_for_room(room: RoomData) -> GridData:
	var battle := room.battle_scene.instantiate()
	var grid := GridData.new(int(battle.grid_cols), int(battle.grid_rows))
	if room.grid_layout != null:
		room.grid_layout.apply_to_grid(grid)
	else:
		var terrain_layer := battle.get_node_or_null("TerrainLayer") as TileMapLayer
		if terrain_layer != null:
			for cell in terrain_layer.get_used_cells():
				var tile_data := terrain_layer.get_cell_tile_data(cell)
				if tile_data == null:
					continue
				match str(tile_data.get_custom_data("cell_type")):
					"WALL": grid.set_type(cell, GridData.CellType.WALL)
					"HOLE": grid.set_type(cell, GridData.CellType.HOLE)
					"LAVA": grid.set_type(cell, GridData.CellType.LAVA)
					"ICE": grid.set_type(cell, GridData.CellType.ICE)
					"SHADOW": grid.set_type(cell, GridData.CellType.SHADOW)
					"RUNE": grid.set_type(cell, GridData.CellType.RUNE)
					_: grid.set_type(cell, GridData.CellType.NORMAL)
	battle.free()
	return grid


func _connect_death_cleanup(
		unit: Unit,
		grid: GridData,
		connections: Array[Dictionary]
	) -> void:
	var callback := func(dead: Unit) -> void: grid.remove_unit(dead)
	unit.died.connect(callback)
	connections.append({"unit": unit, "callback": callback})


func _release_room(
		grid: GridData,
		units: Array,
		connections: Array[Dictionary]
	) -> void:
	for entry in connections:
		var unit := entry.get("unit") as Unit
		var callback: Callable = entry.get("callback", Callable())
		if unit != null and callback.is_valid() and unit.died.is_connected(callback):
			unit.died.disconnect(callback)
	for unit_value in grid.get_units():
		grid.remove_unit(unit_value)
	units.clear()
	connections.clear()


func _nearest_enemy(hero: Unit, units: Array, grid: GridData) -> Unit:
	var enemies := units.filter(func(value):
		var unit := value as Unit
		return unit.is_alive and unit.team != hero.team
	)
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a: Unit, b: Unit) -> bool:
		return _target_priority(hero, a, grid) > _target_priority(hero, b, grid)
	)
	return enemies[0] as Unit


func _target_priority(hero: Unit, target: Unit, grid: GridData) -> float:
	var role_bonus := {
		&"skeleton_centurion": 30.0,
		&"skeleton_chief": 15.0,
	}.get(target.tactical_role_id, 0.0) as float
	return role_bonus - float(grid.manhattan(hero.grid_pos, target.grid_pos)) \
		- float(target.current_hp) * 0.001


func _initiative_order(a: Unit, b: Unit) -> bool:
	if a.get_initiative() != b.get_initiative():
		return a.get_initiative() > b.get_initiative()
	return a.get_runtime_stable_id() < b.get_runtime_stable_id()


func _living_team(units: Array, team: int) -> int:
	return units.filter(func(value):
		var unit := value as Unit
		return unit != null and unit.is_alive and unit.team == team
	).size()


func _living_states(states: Array[CharacterRunState]) -> int:
	return states.filter(func(state): return state.unit != null and state.unit.is_alive).size()


func _total_xp(states: Array[CharacterRunState]) -> int:
	var total := 0
	for state in states:
		for progress in state.get_discipline_progressions().values():
			total += (progress as DisciplineProgressState).xp
	return total


func _rank_snapshot(states: Array[CharacterRunState]) -> Dictionary:
	var snapshot := {}
	for state in states:
		var ranks := {}
		for discipline in state.get_disciplines():
			ranks[str(discipline.discipline_id)] = state.get_discipline_progress(
				discipline.discipline_id
			).rank
		snapshot[str(state.character_id)] = ranks
	return snapshot


func _all_disciplines_rank_five(states: Array[CharacterRunState]) -> bool:
	for state in states:
		for progress in state.get_discipline_progressions().values():
			if (progress as DisciplineProgressState).rank < 5:
				return false
	return true


func _room_failure(reason: StringName) -> Dictionary:
	return {
		"victory": false,
		"reason": reason,
		"rounds": 0,
		"damage_received": 0,
		"friendly_fire_damage": 0,
		"hero_deaths": 0,
		"normal_summons_resolved": 0,
		"chief_summons_resolved": 0,
		"peak_enemies": 0,
		"peak_runtime_units": 0,
	}


func _aggregate(runs: Array[Dictionary]) -> Dictionary:
	var result := {}
	var available_profiles := []
	for run in runs:
		if not available_profiles.has(run.profile):
			available_profiles.append(run.profile)
	for profile in available_profiles:
		var profile_runs := runs.filter(func(run): return run.profile == profile)
		var victories := profile_runs.filter(func(run): return run.victory).size()
		result[str(profile)] = {
			"runs": profile_runs.size(),
			"victories": victories,
			"win_rate": float(victories) / float(maxi(1, profile_runs.size())),
			"average_rooms_completed": _average(profile_runs, &"rooms_completed"),
			"average_total_xp": _average(profile_runs, &"total_xp"),
			"normal_summons_resolved": _sum(profile_runs, &"normal_summons_resolved"),
			"chief_summons_resolved": _sum(profile_runs, &"chief_summons_resolved"),
			"peak_enemies": _maximum(profile_runs, &"peak_enemies"),
			"average_room_six_ms": _average(profile_runs, &"room_six_elapsed_ms"),
		}
	return result


func _sum(values: Array, key: StringName) -> float:
	var total := 0.0
	for value in values:
		total += float((value as Dictionary).get(key, 0.0))
	return total


func _average(values: Array, key: StringName) -> float:
	return _sum(values, key) / float(maxi(1, values.size()))


func _maximum(values: Array, key: StringName) -> float:
	var maximum := 0.0
	for value in values:
		maximum = maxf(maximum, float((value as Dictionary).get(key, 0.0)))
	return maximum


func _validate_payload(
		payload: Dictionary,
		selected_profiles: Array,
		selected_seed_count: int
	) -> bool:
	var runs := payload.get("runs", []) as Array
	if runs.size() != selected_profiles.size() * selected_seed_count:
		push_error("Simulation first run v2 incomplète.")
		return false
	for run_value in runs:
		var run := run_value as Dictionary
		if run.get("full_rank_five_before_room_six", false):
			push_error("Un profil atteint tous les rangs 5 avant la salle 6.")
			return false
		if run.profile != PROFILE_NO_PROGRESSION \
				and int(run.rooms_completed) >= 5 \
				and (run.equipment_chosen as Array).size() != 5:
			push_error("Une run éligible n'a pas attribué cinq équipements.")
			return false
		if run.get("victory", false) and int(run.get("transitions", 0)) != 5:
			push_error("Une victoire n'a pas traversé les cinq transitions.")
			return false
	if selected_profiles.size() == PROFILES.size():
		var summary := payload.get("summary", {}) as Dictionary
		var specialized := summary.get(str(PROFILE_SPECIALIZED), {}) as Dictionary
		var balanced := summary.get(str(PROFILE_BALANCED), {}) as Dictionary
		var no_progression := summary.get(str(PROFILE_NO_PROGRESSION), {}) as Dictionary
		if int(specialized.get("victories", 0)) <= 0 \
				or int(balanced.get("victories", 0)) <= 0:
			push_error("Les deux profils avec progression doivent pouvoir terminer la run.")
			return false
		if float(no_progression.get("win_rate", 1.0)) >= maxf(
			float(specialized.get("win_rate", 0.0)),
			float(balanced.get("win_rate", 0.0)),
		):
			push_error("Le profil sans progression doit rester sensiblement moins performant.")
			return false
		if _maximum(runs, &"peak_enemies") < 8.0 \
				or _sum(runs, &"normal_summons_resolved") <= 0.0 \
				or _sum(runs, &"chief_summons_resolved") <= 0.0:
			push_error("La simulation doit observer le roster de huit et les deux invocations.")
			return false
	return true
