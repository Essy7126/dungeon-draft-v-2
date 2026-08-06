class_name ObservatoryRunDataExporter
extends RefCounted

const MAX_SUMMON_DEPTH := 8
const RUN_ID := "first_run"
const STRATEGY_NAMES := [
	"GENERIC_MELEE",
	"GENERIC_RANGED",
	"GENERIC_HEALER",
	"FORMATION_MELEE",
	"GUARDIAN_CHIEF",
	"RANGED_COMMANDER",
]
const STRATEGY_DESCRIPTIONS := {
	"FORMATION_MELEE": "Cherche a combattre en formation",
	"GUARDIAN_CHIEF": "Protege et maintient la structure du groupe",
	"RANGED_COMMANDER": "Commandant a distance",
}

var _encounter_resources := {}
var _encounter_room_ids := {}
var _encounter_wave_ids := {}
var _enemy_resources := {}
var _enemy_initial_encounters := {}
var _enemy_initial_rooms := {}
var _enemy_reachable_encounters := {}
var _enemy_reachable_rooms := {}
var _enemy_summon_spells := {}
var _enemy_spell_resources := {}
var _enemy_spell_enemy_ids := {}
var _summon_edges: Array[Dictionary] = []
var _ai_profile_resources := {}
var _ai_profile_enemy_ids := {}
var _audits: Array[Dictionary] = []
var _run_data: RunData = null


func export_graph(run_data: RunData, run_path: String) -> Dictionary:
	_reset()
	_run_data = run_data
	if run_data == null:
		return {
			"runs": [], "rooms": [], "waves": [], "encounters": [],
			"enemies": [], "enemy_spells": [], "ai_profiles": [],
			"audits": [],
		}

	var resolved_counts := RunWaveCountResolver.resolve_counts(
		run_data, run_data.default_seed
	)
	var rooms: Array[Dictionary] = []
	var waves: Array[Dictionary] = []
	var run_room_ids: Array[String] = []
	var seen_room_paths := {}
	for room_index in range(run_data.rooms.size()):
		var room := run_data.rooms[room_index]
		var room_id := _room_id(room_index)
		run_room_ids.append(room_id)
		if room == null:
			continue
		var room_path := ObservatorySerializer.resource_path(room)
		if not room_path.is_empty() and seen_room_paths.has(room_path):
			_audits.append(_audit(
				"RUN.DUPLICATE_ROOM_REFERENCE", "warning", "rooms", "room", room_id,
				"La meme RoomData apparait plusieurs fois dans la run.", room_path,
				"Premiere position : %s ; position repetee : %d." % [
					seen_room_paths[room_path], room_index + 1,
				], "Documenter l'intention ou utiliser une ressource distincte.",
			))
		seen_room_paths[room_path] = room_index + 1
		var resolved_count := int(resolved_counts[room_index]) \
			if room_index < resolved_counts.size() else 0
		var room_wave_ids: Array[String] = []
		for wave_index in range(room.get_wave_count()):
			var wave_id := _wave_id(room_index, wave_index)
			room_wave_ids.append(wave_id)
			var wave := room.get_wave(wave_index)
			var encounter := room.get_encounter_for_wave(wave_index)
			var encounter_id := _encounter_id(encounter, wave_id)
			if encounter != null:
				_register_encounter(encounter_id, encounter, room_id, wave_id)
			waves.append(_export_wave(
				wave, encounter, encounter_id, room_id, wave_id, wave_index,
				room.get_minimum_wave_count(), room.get_maximum_wave_count(),
				resolved_count,
			))
		rooms.append(_export_room(
			room, room_id, room_index, run_data.default_seed, resolved_count, room_wave_ids
		))

	_register_initial_enemies(rooms)
	_collect_enemy_graph()
	_propagate_summon_reachability()
	var encounters := _export_encounters()
	var enemies := _export_enemies()
	var enemy_spells := _export_enemy_spells()
	var ai_profiles := _export_ai_profiles()
	_apply_wave_calculations(waves, encounters, enemies)
	var selected_profile_count := 0
	var minimum_profile_count := 0
	var maximum_profile_count := 0
	var selected_health_multiplier_max := 0.0
	var selected_attack_multiplier_max := 0.0
	var selected_reward_multiplier_max := 0.0
	for room_value in rooms:
		var exported_room := room_value as Dictionary
		minimum_profile_count += int(exported_room.get("minimum_wave_count", 0))
		maximum_profile_count += int(exported_room.get("maximum_wave_count", 0))
	for wave_value in waves:
		var exported_wave := wave_value as Dictionary
		if not bool(exported_wave.get("is_selected_by_default_seed", false)):
			continue
		selected_profile_count += 1
		selected_health_multiplier_max = maxf(
			selected_health_multiplier_max,
			float(exported_wave.get("enemy_health_multiplier", 0.0)),
		)
		selected_attack_multiplier_max = maxf(
			selected_attack_multiplier_max,
			float(exported_wave.get("enemy_attack_multiplier", 0.0)),
		)
		selected_reward_multiplier_max = maxf(
			selected_reward_multiplier_max,
			float(exported_wave.get("reward_multiplier", 0.0)),
		)

	var run_errors := _strings(run_data.validation_errors())
	var runs: Array[Dictionary] = [{
		"id": RUN_ID,
		"id_source": "manifest_alias",
		"identity_stability": "derived",
		"name": run_data.run_name,
		"source_path": run_path,
		"default_seed": run_data.default_seed,
		"target_duration_minutes": run_data.target_duration_minutes,
		"extended_duration_minutes": run_data.extended_duration_minutes,
		"maximum_waves_per_room": run_data.maximum_waves_per_room,
		"room_ids": run_room_ids,
		"authored_room_count": run_data.rooms.size(),
		"authored_wave_profile_count": waves.size(),
		"selected_default_seed_wave_profile_count": selected_profile_count,
		"minimum_played_wave_profile_count": minimum_profile_count,
		"maximum_played_wave_profile_count": maximum_profile_count,
		"selected_health_multiplier_max": selected_health_multiplier_max,
		"selected_attack_multiplier_max": selected_attack_multiplier_max,
		"selected_reward_multiplier_max": selected_reward_multiplier_max,
		"validation_status": "valid" if run_data.is_valid() else "invalid",
		"validation_errors": run_errors,
	}]
	return {
		"runs": runs,
		"rooms": rooms,
		"waves": waves,
		"encounters": encounters,
		"enemies": enemies,
		"enemy_spells": enemy_spells,
		"ai_profiles": ai_profiles,
		"audits": _audits,
	}


func _reset() -> void:
	_encounter_resources.clear()
	_encounter_room_ids.clear()
	_encounter_wave_ids.clear()
	_enemy_resources.clear()
	_enemy_initial_encounters.clear()
	_enemy_initial_rooms.clear()
	_enemy_reachable_encounters.clear()
	_enemy_reachable_rooms.clear()
	_enemy_summon_spells.clear()
	_enemy_spell_resources.clear()
	_enemy_spell_enemy_ids.clear()
	_summon_edges.clear()
	_ai_profile_resources.clear()
	_ai_profile_enemy_ids.clear()
	_audits.clear()
	_run_data = null


func _export_room(
		room: RoomData,
		room_id: String,
		room_index: int,
		default_seed: int,
		resolved_count: int,
		wave_ids: Array[String]
	) -> Dictionary:
	var map_kind := "unknown"
	if room.grid_layout != null or room.painted_map_visual_data != null:
		map_kind = "painted"
	elif room.arena_generation_profile != null or room.arena_visual_profile != null:
		map_kind = "generated"
	elif room.battle_scene != null:
		map_kind = "legacy_scene"
	var default_encounter_id := _encounter_id(
		room.encounter_definition, "%s.wave.01" % room_id
	)
	var grid_width: Variant = null
	var grid_height: Variant = null
	var grid_dimensions_status := "runtime_only"
	if room.grid_layout != null:
		grid_width = room.grid_layout.logical_size.x
		grid_height = room.grid_layout.logical_size.y
		grid_dimensions_status = "static_resource"
	var errors: Array[String] = []
	if room.battle_scene == null:
		errors.append("Aucune battle_scene declaree.")
	if room.get_wave_count() <= 0:
		errors.append("Aucun profil de vague disponible.")
	if room.minimum_wave_count > room.maximum_wave_count \
			or room.maximum_wave_count > room.get_wave_count():
		errors.append("Plage min/max de vagues incoherente.")
	if room.ultimate_reward_min_gain_per_wave \
			> room.ultimate_reward_max_gain_per_wave:
		errors.append("Progression de recompense ultime inversee.")
	var legacy_enemy_ids: Array[String] = []
	for enemy in room.enemies:
		if enemy != null:
			legacy_enemy_ids.append(str(enemy.get_effective_unit_id()))
	return {
		"id": room_id,
		"id_source": "ordered_parent_index",
		"identity_stability": "derived",
		"run_id": RUN_ID,
		"index": room_index + 1,
		"name": room.room_name,
		"source_path": ObservatorySerializer.resource_path(room),
		"background_image_path": ObservatorySerializer.resource_path(room.background_image),
		"particles_scene_path": ObservatorySerializer.resource_path(room.particles_scene),
		"battle_scene_path": ObservatorySerializer.resource_path(room.battle_scene),
		"arena_generation_profile_path": ObservatorySerializer.resource_path(
			room.arena_generation_profile
		),
		"arena_visual_profile_path": ObservatorySerializer.resource_path(
			room.arena_visual_profile
		),
		"grid_layout_path": ObservatorySerializer.resource_path(room.grid_layout),
		"painted_map_visual_data_path": ObservatorySerializer.resource_path(
			room.painted_map_visual_data
		),
		"map_kind": map_kind,
		"grid_width": grid_width,
		"grid_height": grid_height,
		"grid_dimensions_status": grid_dimensions_status,
		"available_wave_count": room.get_wave_count(),
		"minimum_wave_count": room.get_minimum_wave_count(),
		"maximum_wave_count": room.get_maximum_wave_count(),
		"resolved_default_seed_wave_count": resolved_count,
		"wave_resolution_status": "exact_production_resolver",
		"wave_resolution_method": "RunWaveCountResolver.resolve_counts",
		"wave_resolution_seed": default_seed,
		"wave_ids": wave_ids,
		"default_encounter_id": default_encounter_id,
		"hero_spawn_cells": ObservatorySerializer.sanitize(room.hero_spawn_zone),
		"enemy_spawn_cells": ObservatorySerializer.sanitize(room.enemy_spawn_zone),
		"hero_spawn_cell_count": room.hero_spawn_zone.size(),
		"enemy_spawn_cell_count": room.enemy_spawn_zone.size(),
		"ultimate_reward_base_chance_percent": room.ultimate_reward_base_chance,
		"ultimate_reward_min_gain_per_wave": room.ultimate_reward_min_gain_per_wave,
		"ultimate_reward_max_gain_per_wave": room.ultimate_reward_max_gain_per_wave,
		"legacy_enemy_ids": legacy_enemy_ids,
		"validation_status": "valid" if errors.is_empty() else "invalid",
		"validation_errors": errors,
	}


func _export_wave(
		wave: RoomWaveData,
		encounter: EncounterDefinition,
		encounter_id: String,
		room_id: String,
		wave_id: String,
		wave_index: int,
		minimum_count: int,
		maximum_count: int,
		resolved_count: int
	) -> Dictionary:
	var source_kind := "historical_fallback" if wave == null else (
		"resource" if not ObservatorySerializer.resource_path(wave).is_empty() else "subresource"
	)
	var health_multiplier := wave.enemy_health_multiplier if wave != null else 1.0
	var attack_multiplier := wave.enemy_attack_multiplier if wave != null else 1.0
	var reward_multiplier := wave.reward_multiplier if wave != null else 1.0
	var errors: Array[String] = []
	if wave != null:
		errors = _strings(wave.validation_errors())
	if encounter == null:
		errors.append("Aucune EncounterDefinition resolue.")
	return {
		"id": wave_id,
		"id_source": "ordered_parent_index",
		"identity_stability": "derived",
		"room_id": room_id,
		"index": wave_index + 1,
		"name": wave.wave_name if wave != null else "Vague historique",
		"source_path": ObservatorySerializer.resource_path(wave),
		"source_kind": source_kind,
		"encounter_id": encounter_id,
		"enemy_health_multiplier": health_multiplier,
		"enemy_attack_multiplier": attack_multiplier,
		"reward_multiplier": reward_multiplier,
		"is_mandatory_profile": wave_index < minimum_count,
		"is_optional_profile": wave_index >= minimum_count and wave_index < maximum_count,
		"is_selected_by_default_seed": wave_index < resolved_count,
		"health_multiplier_runtime_target": "Unit.max_hp via Stat.ModType.PERCENT",
		"attack_multiplier_runtime_target": "Unit.attack_power via Stat.ModType.PERCENT",
		"attack_multiplier_effect_status": "unknown",
		"attack_multiplier_effect_evidence": "Evalue apres resolution du roster.",
		"scaled_initial_totals": {"total_max_hp": null, "total_attack_power": null},
		"calculation_status": "unknown",
		"calculation_evidence": "Rencontre non encore resolue.",
		"validation_status": "valid" if errors.is_empty() else "invalid",
		"validation_errors": errors,
	}


func _register_encounter(
		encounter_id: String,
		encounter: EncounterDefinition,
		room_id: String,
		wave_id: String
	) -> void:
	if not _encounter_resources.has(encounter_id):
		_encounter_resources[encounter_id] = encounter
	_append_unique(_encounter_room_ids, encounter_id, room_id)
	_append_unique(_encounter_wave_ids, encounter_id, wave_id)


func _register_initial_enemies(rooms: Array[Dictionary]) -> void:
	for encounter_id in _sorted_keys(_encounter_resources):
		var encounter := _encounter_resources[encounter_id] as EncounterDefinition
		for enemy in encounter.roster_units:
			if enemy == null:
				continue
			var enemy_id := str(enemy.get_effective_unit_id())
			_enemy_resources[enemy_id] = enemy
			_append_unique(_enemy_initial_encounters, enemy_id, encounter_id)
			_append_unique(_enemy_reachable_encounters, enemy_id, encounter_id)
			for room_id in _encounter_room_ids.get(encounter_id, []) as Array:
				_append_unique(_enemy_initial_rooms, enemy_id, str(room_id))
				_append_unique(_enemy_reachable_rooms, enemy_id, str(room_id))
	# RoomData.enemies n'est un fallback actif que lorsqu'aucune rencontre n'est resolue.
	for room_value in rooms:
		var room_export := room_value as Dictionary
		if not str(room_export.get("default_encounter_id", "")).is_empty():
			continue
		var room_index := int(room_export.get("index", 1)) - 1
		if _run_data == null or room_index < 0 or room_index >= _run_data.rooms.size():
			continue
		for enemy in _run_data.rooms[room_index].enemies:
			if enemy == null:
				continue
			var enemy_id := str(enemy.get_effective_unit_id())
			_enemy_resources[enemy_id] = enemy
			_append_unique(_enemy_initial_rooms, enemy_id, str(room_export.get("id", "")))
			_append_unique(_enemy_reachable_rooms, enemy_id, str(room_export.get("id", "")))


func _collect_enemy_graph() -> void:
	var queue: Array[Dictionary] = []
	for enemy_id in _sorted_keys(_enemy_resources):
		queue.append({"enemy_id": enemy_id, "depth": 0})
	var processed := {}
	while not queue.is_empty():
		var current := queue.pop_front() as Dictionary
		var enemy_id := str(current.get("enemy_id", ""))
		var depth := int(current.get("depth", 0))
		if processed.has(enemy_id):
			continue
		processed[enemy_id] = true
		var enemy := _enemy_resources.get(enemy_id) as UnitData
		if enemy == null:
			continue
		if enemy.ai_profile != null:
			var profile_id := _ai_profile_id(enemy.ai_profile)
			_ai_profile_resources[profile_id] = enemy.ai_profile
			_append_unique(_ai_profile_enemy_ids, profile_id, enemy_id)
		for spell in enemy.spells:
			if spell == null:
				_audits.append(_audit(
					"ENEMY.UNKNOWN_SPELL_REFERENCE", "blocking", "enemies", "enemy",
					enemy_id, "Un sort ennemi reference ne peut pas etre charge.",
					ObservatorySerializer.resource_path(enemy), "Reference Spell nulle.",
					"Retablir la reference de sort.",
				))
				continue
			var spell_id := str(spell.get_effective_spell_id())
			_enemy_spell_resources[spell_id] = spell
			_append_unique(_enemy_spell_enemy_ids, spell_id, enemy_id)
			if not spell.is_summon():
				continue
			if spell.summon_unit_data == null:
				_audits.append(_audit(
					"SUMMON.UNKNOWN_UNIT_REFERENCE", "blocking", "enemy_spells", "enemy_spell",
					spell_id, "Le sort d'invocation ne resout aucune UnitData.",
					ObservatorySerializer.resource_path(spell), "summon_unit_data est null.",
					"Retablir la reference d'invocation.",
				))
				continue
			var target_id := str(spell.summon_unit_data.get_effective_unit_id())
			_summon_edges.append({
				"caster_enemy_id": enemy_id,
				"spell_id": spell_id,
				"summon_enemy_id": target_id,
			})
			_append_unique(_enemy_summon_spells, target_id, spell_id)
			if not _enemy_resources.has(target_id):
				_enemy_resources[target_id] = spell.summon_unit_data
				if depth < MAX_SUMMON_DEPTH:
					queue.append({"enemy_id": target_id, "depth": depth + 1})
				else:
					_audits.append(_audit(
						"SUMMON.TRAVERSAL_DEPTH_LIMIT", "warning", "enemy_spells",
						"enemy_spell", spell_id,
						"Le parcours des invocations a atteint sa profondeur maximale.",
						ObservatorySerializer.resource_path(spell),
						"Profondeur maximale : %d ; cible incluse sans parcourir ses sorts." \
							% MAX_SUMMON_DEPTH,
						"Verifier la chaine d'invocation.",
					))


func _propagate_summon_reachability() -> void:
	# Fermeture fixe bornee : propage les contextes de rencontre du lanceur a l'invoque.
	for _depth in range(MAX_SUMMON_DEPTH):
		var changed := false
		for edge in _summon_edges:
			var caster_id := str(edge.get("caster_enemy_id", ""))
			var target_id := str(edge.get("summon_enemy_id", ""))
			for encounter_id in _enemy_reachable_encounters.get(caster_id, []) as Array:
				changed = _append_unique(
					_enemy_reachable_encounters, target_id, str(encounter_id)
				) or changed
			for room_id in _enemy_reachable_rooms.get(caster_id, []) as Array:
				changed = _append_unique(_enemy_reachable_rooms, target_id, str(room_id)) or changed
		if not changed:
			return
	_audits.append(_audit(
		"SUMMON.TRAVERSAL_DEPTH_LIMIT", "warning", "enemy_spells", "summon_graph",
		"production", "La fermeture des invocations a atteint sa profondeur maximale.",
		"res://tools/observatory/observatory_run_data_exporter.gd",
		"Profondeur maximale : %d." % MAX_SUMMON_DEPTH,
		"Verifier le graphe d'invocation pour un cycle ou une chaine excessive.",
	))


func _export_encounters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for encounter_id in _sorted_keys(_encounter_resources):
		var encounter := _encounter_resources[encounter_id] as EncounterDefinition
		var roster: Array[Dictionary] = []
		for index in range(mini(encounter.roster_units.size(), encounter.roster_counts.size())):
			var enemy := encounter.roster_units[index]
			roster.append({
				"enemy_id": str(enemy.get_effective_unit_id()) if enemy != null else "",
				"count": int(encounter.roster_counts[index]),
			})
		var expanded_ids: Array[String] = []
		var total_hp := 0
		var total_ap := 0
		var total_mp := 0
		var total_attack := 0
		var initiative_total := 0
		var maximum_initiative := 0
		var role_counts := {}
		var faction_counts := {}
		var spell_ids := {}
		var summon_spell_ids := {}
		for enemy in encounter.expanded_roster():
			if enemy == null:
				continue
			var enemy_id := str(enemy.get_effective_unit_id())
			expanded_ids.append(enemy_id)
			total_hp += enemy.max_hp
			total_ap += enemy.max_ap
			total_mp += enemy.max_mp
			total_attack += enemy.attack_power
			initiative_total += enemy.initiative
			maximum_initiative = maxi(maximum_initiative, enemy.initiative)
			_increment(role_counts, str(enemy.tactical_role_id))
			_increment(faction_counts, str(enemy.faction_id))
			for spell in enemy.spells:
				if spell == null:
					continue
				spell_ids[str(spell.get_effective_spell_id())] = true
				if spell.is_summon():
					summon_spell_ids[str(spell.get_effective_spell_id())] = true
		var initial_count := encounter.get_initial_enemy_count()
		var average_initiative := (
			float(initiative_total) / float(initial_count) if initial_count > 0 else 0.0
		)
		result.append({
			"id": encounter_id,
			"id_source": "resource_path" if not ObservatorySerializer.resource_path(
				encounter
			).is_empty() else "ordered_parent_index",
			"identity_stability": "stable" if not ObservatorySerializer.resource_path(
				encounter
			).is_empty() else "derived",
			"source_path": ObservatorySerializer.resource_path(encounter),
			"room_ids": _sorted_strings(_encounter_room_ids.get(encounter_id, []) as Array),
			"wave_ids": _sorted_strings(_encounter_wave_ids.get(encounter_id, []) as Array),
			"declared_room_index": encounter.room_index,
			"roster": roster,
			"roster_unit_entry_count": encounter.roster_units.size(),
			"roster_count_entry_count": encounter.roster_counts.size(),
			"initial_enemy_count": initial_count,
			"expanded_initial_enemy_ids": expanded_ids,
			"allowed_spawn_groups": _strings(encounter.allowed_spawn_groups),
			"formation_profiles": _strings(encounter.formation_profiles),
			"living_enemy_cap": encounter.living_enemy_cap,
			"shared_normal_summon_budget": encounter.shared_normal_summon_budget,
			"shared_chief_summon_budget": encounter.shared_chief_summon_budget,
			"disabled_ability_ids": _strings(encounter.disabled_ability_ids),
			"maximum_formation_attempts": encounter.maximum_formation_attempts,
			"minimum_path_distance_by_role": ObservatorySerializer.sanitize(
				encounter.minimum_path_distance_by_role
			),
			"maximum_path_distance_by_role": ObservatorySerializer.sanitize(
				encounter.maximum_path_distance_by_role
			),
			"summon_free_neighbor_requirement": encounter.summon_free_neighbor_requirement,
			"forbidden_initial_spawn_cells": ObservatorySerializer.sanitize(
				encounter.forbidden_initial_spawn_cells
			),
			"forbidden_initial_spawn_cell_count": encounter.forbidden_initial_spawn_cells.size(),
			"base_totals": {
				"initial_enemy_count": initial_count,
				"total_max_hp": total_hp,
				"total_max_ap": total_ap,
				"total_max_mp": total_mp,
				"total_attack_power": total_attack,
				"average_initiative": average_initiative,
				"maximum_initiative": maximum_initiative,
			},
			"role_counts": role_counts,
			"faction_counts": faction_counts,
			"initial_enemy_spell_count": spell_ids.size(),
			"summon_spell_count": summon_spell_ids.size(),
			"calculation_status": "static_base_only",
			"calculation_evidence": "Somme des UnitData du roster retourne par expanded_roster().",
			"validation_status": "valid" if encounter.is_valid() else "invalid",
			"validation_errors": _strings(encounter.validation_errors()),
		})
	return result


func _export_enemies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy_id in _sorted_keys(_enemy_resources):
		var enemy := _enemy_resources[enemy_id] as UnitData
		var spell_ids: Array[String] = []
		var effect_tags := {}
		if enemy.combat_style == 0:
			effect_tags["melee"] = true
		elif enemy.combat_style == 1:
			effect_tags["ranged"] = true
		for spell in enemy.spells:
			if spell == null:
				continue
			spell_ids.append(str(spell.get_effective_spell_id()))
			for tag in _spell_effect_tags(spell):
				effect_tags[tag] = true
		if enemy.ai_profile != null:
			if enemy.tactical_role_id == enemy.ai_profile.commander_role_id:
				effect_tags["commander"] = true
			if enemy.tactical_role_id == enemy.ai_profile.chief_role_id:
				effect_tags["tank"] = true
			if enemy.ai_profile.strategy == EnemyAIProfile.Strategy.GENERIC_HEALER:
				effect_tags["support"] = true
		var initial_encounters := _sorted_strings(
			_enemy_initial_encounters.get(enemy_id, []) as Array
		)
		var initial_rooms := _sorted_strings(_enemy_initial_rooms.get(enemy_id, []) as Array)
		var summon_spells := _sorted_strings(_enemy_summon_spells.get(enemy_id, []) as Array)
		var validation_errors: Array[String] = []
		if str(enemy.unit_id).strip_edges().is_empty():
			validation_errors.append("unit_id explicite absent.")
		if enemy.team != 1:
			validation_errors.append("Equipe differente de l'equipe ennemie.")
		result.append({
			"id": enemy_id,
			"id_source": "explicit" if not str(enemy.unit_id).strip_edges().is_empty() \
				else "resource_path",
			"identity_stability": "stable",
			"name": enemy.unit_name,
			"description": enemy.description,
			"source_path": ObservatorySerializer.resource_path(enemy),
			"reachability": {
				"initial_encounter_ids": initial_encounters,
				"initial_room_ids": initial_rooms,
				"summonable_by_spell_ids": summon_spells,
				"initial_roster": not initial_encounters.is_empty(),
				"summon_only": initial_encounters.is_empty() and not summon_spells.is_empty(),
			},
			"team": enemy.team,
			"max_hp": enemy.max_hp,
			"initiative": enemy.initiative,
			"max_ap": enemy.max_ap,
			"max_mp": enemy.max_mp,
			"attack_power": enemy.attack_power,
			"force": enemy.force,
			"armour": enemy.armure,
			"magic_resistance": enemy.resist_magique,
			"dodge": enemy.esquive,
			"resistances": ObservatorySerializer.sanitize(enemy.resistances),
			"critical_chance": enemy.crit_chance,
			"critical_multiplier": enemy.crit_multi,
			"basic_attack_enabled": enemy.basic_attack_enabled,
			"active_spell_slots": enemy.active_spell_slots,
			"spell_ids": spell_ids,
			"ai_behavior": _enum_pair(enemy.ai_behavior, ["melee", "ranged", "healer"]),
			"combat_style": _enum_pair(enemy.combat_style, ["melee", "ranged"]),
			"preferred_range": enemy.preferred_range,
			"minimum_range": enemy.minimum_range,
			"maximum_range": enemy.maximum_range,
			"keep_distance": enemy.keep_distance,
			"ai_profile_id": _ai_profile_id(enemy.ai_profile),
			"faction_id": str(enemy.faction_id),
			"tactical_role_id": str(enemy.tactical_role_id),
			"linked_commander_role_id": str(enemy.linked_commander_role_id),
			"proximity_armor_source": str(enemy.proximity_armor_source),
			"proximity_armor_per_living_neighbor": enemy.proximity_armor_per_living_neighbor,
			"proximity_armor_max_neighbors": enemy.proximity_armor_max_neighbors,
			"first_forced_movement_reduction_per_activation": (
				enemy.first_forced_movement_reduction_per_activation
			),
			"visual_scene_path": ObservatorySerializer.resource_path(enemy.visual_scene),
			"preview_visual_scene_path": ObservatorySerializer.resource_path(
				enemy.preview_visual_scene
			),
			"effect_tags": _sorted_keys(effect_tags),
			"validation_status": "valid" if validation_errors.is_empty() else "invalid",
			"validation_errors": validation_errors,
		})
	return result


func _export_enemy_spells() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spell_id in _sorted_keys(_enemy_spell_resources):
		var spell := _enemy_spell_resources[spell_id] as Spell
		var owners := _sorted_strings(_enemy_spell_enemy_ids.get(spell_id, []) as Array)
		var base := ObservatoryResourceExporters.export_spell(spell, [])
		base.erase("referenced_by_character_ids")
		var enabled: Array[String] = []
		var disabled: Array[String] = []
		for owner_id in owners:
			for encounter_id in _enemy_reachable_encounters.get(owner_id, []) as Array:
				var encounter := _encounter_resources.get(str(encounter_id)) as EncounterDefinition
				if encounter != null and str(spell.get_effective_spell_id()) \
						in _strings(encounter.disabled_ability_ids):
					if str(encounter_id) not in disabled:
						disabled.append(str(encounter_id))
				elif str(encounter_id) not in enabled:
					enabled.append(str(encounter_id))
		enabled.sort()
		disabled.sort()
		base["referenced_by_enemy_ids"] = owners
		base["summon_enemy_id"] = str(spell.summon_unit_data.get_effective_unit_id()) \
			if spell.summon_unit_data != null else ""
		base["summon_type"] = str(spell.summon_type)
		base["summon_starting_hp"] = spell.summon_starting_hp
		base["summon_max_living_team"] = spell.summon_max_living_team
		base["summon_initial_cooldowns"] = ObservatorySerializer.sanitize(
			spell.summon_initial_cooldowns
		)
		base["condition_hp_at_or_below"] = spell.condition_hp_at_or_below
		base["requires_absent_unit_id"] = str(spell.requires_absent_unit_id)
		base["encounter_enabled_in_ids"] = enabled
		base["encounter_disabled_in_ids"] = disabled
		base["effect_tags"] = _spell_effect_tags(spell)
		result.append(base)
	return result


func _export_ai_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile_id in _sorted_keys(_ai_profile_resources):
		var profile := _ai_profile_resources[profile_id] as EnemyAIProfile
		var strategy_name: String = STRATEGY_NAMES[profile.strategy] \
			if profile.strategy >= 0 and profile.strategy < STRATEGY_NAMES.size() \
			else "UNKNOWN"
		result.append({
			"id": profile_id,
			"source_path": ObservatorySerializer.resource_path(profile),
			"strategy": {
				"name": strategy_name,
				"value": profile.strategy,
				"description": str(STRATEGY_DESCRIPTIONS.get(
					strategy_name, "Strategie generique declaree"
				)),
			},
			"marked_status_id": str(profile.marked_status_id),
			"normal_role_id": str(profile.normal_role_id),
			"chief_role_id": str(profile.chief_role_id),
			"commander_role_id": str(profile.commander_role_id),
			"sentence_hp_ratio_threshold": profile.sentence_hp_ratio_threshold,
			"commander_emergency_hp": profile.commander_emergency_hp,
			"summon_when_normals_below": profile.summon_when_normals_below,
			"ideal_minimum_range": profile.ideal_minimum_range,
			"ideal_maximum_range": profile.ideal_maximum_range,
			"avoid_hero_adjacency": profile.avoid_hero_adjacency,
			"prefer_living_neighbors": profile.prefer_living_neighbors,
			"protect_commander_paths": profile.protect_commander_paths,
			"commander_distance_penalty_per_cell": (
				profile.commander_distance_penalty_per_cell
			),
			"commander_path_block_bonus": profile.commander_path_block_bonus,
			"referenced_by_enemy_ids": _sorted_strings(
				_ai_profile_enemy_ids.get(profile_id, []) as Array
			),
		})
	return result


func _apply_wave_calculations(
		waves: Array[Dictionary],
		encounters: Array[Dictionary],
		enemies: Array[Dictionary]
	) -> void:
	var encounter_map := _id_map(encounters)
	var enemy_map := _id_map(enemies)
	for wave in waves:
		var encounter_value: Variant = encounter_map.get(str(wave.get("encounter_id", "")))
		if not encounter_value is Dictionary:
			continue
		var encounter := encounter_value as Dictionary
		var total_hp := 0
		var total_attack := 0
		var has_basic_attack := false
		var has_spell_damage := false
		for enemy_id_value in encounter.get("expanded_initial_enemy_ids", []) as Array:
			var enemy := enemy_map.get(str(enemy_id_value)) as Dictionary
			if enemy == null:
				continue
			total_hp += int(round(
				float(enemy.get("max_hp", 0)) * float(wave.get("enemy_health_multiplier", 1.0))
			))
			total_attack += int(round(
				float(enemy.get("attack_power", 0)) \
				* float(wave.get("enemy_attack_multiplier", 1.0))
			))
			has_basic_attack = has_basic_attack or bool(enemy.get("basic_attack_enabled", false))
			for spell_id in enemy.get("spell_ids", []) as Array:
				var spell := _enemy_spell_resources.get(str(spell_id)) as Spell
				has_spell_damage = has_spell_damage or (spell != null and spell.damage > 0)
		var effect_status := "no_active_source_detected"
		if has_basic_attack and has_spell_damage:
			effect_status = "partially_effective"
		elif has_basic_attack:
			effect_status = "effective"
		wave["attack_multiplier_effect_status"] = effect_status
		wave["attack_multiplier_effect_evidence"] = (
			"Battle applique le modificateur a Unit.attack_power ; les attaques de base "
			+ "lisent Unit.get_attack(), tandis que SpellCaster lit Spell.damage. "
			+ "Attaque de base active dans le roster : %s ; sort de degats present : %s."
			% [str(has_basic_attack), str(has_spell_damage)]
		)
		wave["scaled_initial_totals"] = {
			"total_max_hp": total_hp,
			"total_attack_power": total_attack,
		}
		wave["calculation_status"] = "exact_runtime_equivalent"
		wave["calculation_evidence"] = (
			"Somme par unite de round(base * multiplicateur), equivalente a "
			+ "Stat.get_int() apres Stat.ModType.PERCENT dans Battle."
		)


func _spell_effect_tags(spell: Spell) -> Array[String]:
	var tags := {}
	if spell.damage > 0:
		tags["damage"] = true
	if spell.heal > 0:
		tags["heal"] = true
		tags["support"] = true
	if spell.shield_grant > 0:
		tags["shield"] = true
		tags["support"] = true
	if spell.applied_status != null:
		tags["status"] = true
		tags["control"] = true
		if str(spell.get_effective_spell_id()) == "centurion_mark":
			tags["mark"] = true
	if spell.terrain_effect != null:
		tags["terrain"] = true
	if spell.push_distance > 0 or spell.pull_distance > 0:
		tags["forced_movement"] = true
		tags["control"] = true
	if spell.ap_drain > 0 or spell.forces_taunt:
		tags["control"] = true
	if spell.is_delayed():
		tags["delayed"] = true
	if spell.summon_unit_data != null:
		tags["summoner"] = true
	return _sorted_keys(tags)


func _encounter_id(encounter: EncounterDefinition, wave_id: String) -> String:
	if encounter == null:
		return ""
	var path := ObservatorySerializer.resource_path(encounter)
	return _normalized_resource_id(path) if not path.is_empty() else "%s.encounter" % wave_id


func _ai_profile_id(profile: EnemyAIProfile) -> String:
	if profile == null:
		return ""
	if not str(profile.profile_id).strip_edges().is_empty():
		return str(profile.profile_id)
	return _normalized_resource_id(ObservatorySerializer.resource_path(profile))


func _normalized_resource_id(path: String) -> String:
	var value := path.trim_prefix("res://").trim_suffix(".tres")
	return value.replace("/", ".").replace("\\", ".").to_lower()


func _room_id(room_index: int) -> String:
	return "%s.room.%02d" % [RUN_ID, room_index + 1]


func _wave_id(room_index: int, wave_index: int) -> String:
	return "%s.wave.%02d" % [_room_id(room_index), wave_index + 1]


func _enum_pair(value: int, names: Array[String]) -> Dictionary:
	return {
		"value": value,
		"name": names[value] if value >= 0 and value < names.size() else "unknown",
	}


func _id_map(values: Array[Dictionary]) -> Dictionary:
	var result := {}
	for value in values:
		result[str(value.get("id", ""))] = value
	return result


func _increment(counts: Dictionary, key: String) -> void:
	if key.is_empty():
		key = "unknown"
	counts[key] = int(counts.get(key, 0)) + 1


func _append_unique(target: Dictionary, key: String, value: String) -> bool:
	if value.is_empty():
		return false
	if not target.has(key):
		target[key] = []
	var values := target[key] as Array
	if value in values:
		return false
	values.append(value)
	return true


func _sorted_keys(dictionary: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in dictionary:
		result.append(str(key))
	result.sort()
	return result


func _sorted_strings(values: Array) -> Array[String]:
	var result := _strings(values)
	result.sort()
	return result


func _strings(values: Variant) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _audit(
		rule_id: String,
		severity: String,
		domain: String,
		entity_type: String,
		entity_id: String,
		message: String,
		source_path: String,
		evidence: String,
		action: String
	) -> Dictionary:
	var affected_ids: Array[String] = []
	if not entity_id.is_empty():
		affected_ids.append(entity_id)
	return {
		"rule_id": rule_id,
		"severity": severity,
		"status": "open",
		"truth_status": "verified",
		"suggested_action_truth_status": "recommendation",
		"domain": domain,
		"entity_type": entity_type,
		"entity_id": entity_id,
		"affected_entity_type": entity_type,
		"affected_entity_ids": affected_ids,
		"message": message,
		"source_path": source_path,
		"evidence": evidence,
		"suggested_action": action,
	}
