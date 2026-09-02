extends GutTest

const Factory = preload("res://test/support/factory.gd")
const GameManagerScript = preload("res://core/game_manager.gd")
const UnitViewScript = preload("res://battle/unit_view.gd")
const RecraftedHUDScene = preload(
	"res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn"
)

const ODYSSEY_PATH := "res://data/runs/odyssey.tres"
const MAIN_PATH := "res://data/runs/first_run.tres"
const TEST_PATH := "res://data/runs/fixed_trio_prototype_run.tres"
const SPELL_IDS: Array[StringName] = [
	&"achilles_spear_thrust",
	&"achilles_advance",
	&"achilles_sweep",
	&"achilles_guard",
]
const DISCIPLINE_IDS: Array[StringName] = [
	&"spear", &"advance", &"sweep", &"guard",
]


func test_odyssey_is_a_valid_three_room_single_encounter_run() -> void:
	var run := _run()
	assert_not_null(run)
	assert_eq(run.run_name, "Catabase")
	assert_true(run.is_single_encounter_flow())
	assert_eq(run.maximum_waves_per_room, 1)
	assert_eq(run.rooms.size(), 3)
	assert_true(run.is_valid(), str(run.validation_errors()))
	var room_paths := {}
	var encounter_paths := {}
	var visual_paths := {}
	for index in range(run.rooms.size()):
		var room := run.rooms[index]
		assert_eq(room.minimum_wave_count, 1, room.resource_path)
		assert_eq(room.maximum_wave_count, 1, room.resource_path)
		assert_true(room.waves.is_empty(), room.resource_path)
		assert_not_null(room.encounter_definition, room.resource_path)
		assert_true(
			room.encounter_definition.is_valid(),
			str(room.encounter_definition.validation_errors()),
		)
		assert_not_null(room.painted_map_visual_data, room.resource_path)
		assert_true(
			room.painted_map_visual_data.validation_errors().is_empty(),
			str(room.painted_map_visual_data.validation_errors()),
		)
		assert_eq(room.encounter_definition.room_index, index + 1)
		room_paths[room.resource_path] = true
		encounter_paths[room.encounter_definition.resource_path] = true
		visual_paths[room.painted_map_visual_data.resource_path] = true
	assert_eq(room_paths.size(), 3)
	assert_eq(encounter_paths.size(), 3)
	assert_eq(visual_paths.size(), 3)


func test_achilles_profile_chain_and_chassis_are_exact() -> void:
	var run := _run()
	assert_not_null(run.content_profile)
	assert_eq(run.content_profile.profile_id, &"odyssey")
	assert_eq(run.content_profile.hero_profiles.size(), 1)
	var hero_profile := run.content_profile.hero_profiles[0]
	assert_eq(hero_profile.character_id, &"achilles")
	assert_not_null(hero_profile.base_unit_data)
	assert_not_null(hero_profile.progression_profile)
	assert_eq(hero_profile.progression_profile.character_id, &"achilles")
	assert_true(hero_profile.validation_errors().is_empty())
	var data := hero_profile.base_unit_data
	assert_eq(data.get_effective_unit_id(), &"achilles")
	assert_eq(
		[data.max_hp, data.initiative, data.max_ap, data.max_mp, data.attack_power],
		[110, 14, 6, 3, 18],
	)
	assert_false(data.basic_attack_enabled)
	assert_eq(data.active_spell_slots, 4)
	assert_true(data.spells.is_empty(), "La progression est l'autorité des sorts.")
	assert_true(data.disciplines.is_empty(), "La progression est l'autorité des disciplines.")
	var progression := hero_profile.progression_profile
	assert_eq(progression.active_spell_slots, 4)
	assert_eq(_spell_ids(progression.spells), SPELL_IDS)
	assert_eq(_discipline_ids(progression.disciplines), DISCIPLINE_IDS)


func test_achilles_spells_and_initial_disciplines_match_contract() -> void:
	var progression := _progression()
	var spells := progression.spells
	assert_eq([spells[0].ap_cost, spells[0].minimum_range, spells[0].spell_range], [2, 1, 2])
	assert_eq([spells[0].damage, spells[0].damage_type], [9, Spell.DamageType.PHYSICAL])
	assert_eq(
		[spells[1].ap_cost, spells[1].minimum_range,
		spells[1].spell_range, spells[1].damage],
		[2, 2, 3, 5],
	)
	assert_true(spells[1].line_from_caster)
	assert_eq(spells[1].modifiers.size(), 1)
	assert_eq(spells[1].modifiers[0].effect_type, 29)
	assert_true(spells[1].modifiers[0].movement_requires_clear_path)
	assert_eq([spells[2].ap_cost, spells[2].spell_range, spells[2].damage], [3, 0, 6])
	assert_eq(spells[2].aoe_shape, Spell.AoeShape.CROSS)
	assert_eq(spells[2].aoe_size, 1)
	assert_eq(spells[2].push_distance, 1)
	assert_true(spells[2].push_affected_units)
	assert_true(spells[2].exclude_caster_from_area_effects)
	assert_eq([spells[3].ap_cost, spells[3].spell_range, spells[3].shield_grant], [2, 0, 10])
	assert_true(spells[3].is_self_only())
	for spell in spells:
		assert_true(spell.once_per_activation, spell.resource_path)
		assert_false(spell.description.strip_edges().is_empty(), spell.resource_path)
		assert_false(
			spell.description.to_lower().contains("prototype"),
			spell.resource_path,
		)
	for index in range(progression.disciplines.size()):
		var discipline := progression.disciplines[index]
		assert_eq(discipline.ranks.size(), 2, discipline.resource_path)
		assert_eq(discipline.ranks[0].rank, 1, discipline.resource_path)
		assert_true(discipline.ranks[0].choices.is_empty(), discipline.resource_path)
		assert_eq(discipline.ranks[1].rank, 2, discipline.resource_path)
		assert_eq(discipline.ranks[1].required_total_xp, 3, discipline.resource_path)
		assert_eq(discipline.ranks[1].choices.size(), 2, discipline.resource_path)
		for choice in discipline.ranks[1].choices:
			assert_eq(choice.discipline_id, discipline.discipline_id)
			assert_eq(choice.target_spell_id, spells[index].spell_id)
			assert_eq(choice.spell_modifiers.size(), 1)


func test_odyssey_enemy_stats_and_room_rosters_are_exact() -> void:
	var skirmisher := load(
		"res://data/units/enemies/odyssey_skirmisher.tres"
	) as UnitData
	var guard := load("res://data/units/enemies/odyssey_guard.tres") as UnitData
	var champion := load(
		"res://data/units/enemies/odyssey_champion.tres"
	) as UnitData
	assert_eq(
		[skirmisher.max_hp, skirmisher.initiative, skirmisher.max_ap,
		skirmisher.max_mp, skirmisher.attack_power, skirmisher.armure],
		[45, 10, 4, 4, 10, 0.0],
	)
	assert_eq(
		[guard.max_hp, guard.initiative, guard.max_ap, guard.max_mp,
		guard.attack_power, guard.armure],
		[70, 8, 4, 3, 12, 20.0],
	)
	assert_eq(
		[champion.max_hp, champion.initiative, champion.max_ap,
		champion.max_mp, champion.attack_power, champion.armure],
		[115, 9, 4, 3, 16, 30.0],
	)
	for enemy in [skirmisher, guard, champion]:
		assert_true(enemy.basic_attack_enabled)
		assert_eq(enemy.team, 1)
		assert_true(enemy.spells.is_empty())
	var run := _run()
	assert_eq(_roster_ids(run.rooms[0]), [&"catabase_frail_hellspawn"])
	assert_eq(_roster_ids(run.rooms[1]), [
		&"odyssey_skirmisher", &"odyssey_skirmisher", &"odyssey_guard",
	])
	assert_eq(_roster_ids(run.rooms[2]), [
		&"odyssey_champion", &"catabase_shadow_paris",
	])


func test_resolver_and_game_manager_construct_exactly_one_runtime_hero() -> void:
	var run := _run()
	var resolved := RunHeroResolver.resolve_runtime_hero_data(run, false)
	assert_true(resolved.is_valid(), str(resolved.errors))
	assert_false(resolved.used_legacy_fallback)
	assert_eq(resolved.heroes.size(), 1)
	assert_eq(resolved.hero_profiles.size(), 1)
	var runtime_data := resolved.heroes[0]
	assert_not_same(runtime_data, run.content_profile.hero_profiles[0].base_unit_data)
	assert_eq(runtime_data.get_effective_unit_id(), &"achilles")
	assert_eq(_spell_ids(runtime_data.spells), SPELL_IDS)
	assert_eq(_discipline_ids(runtime_data.disciplines), DISCIPLINE_IDS)
	var manager = GameManagerScript.new()
	assert_true(manager._prepare_preconfigured_run(run, resolved.heroes))
	assert_eq(manager.heroes.size(), 1)
	assert_eq(manager.character_states.size(), 1)
	assert_not_null(manager.get_character_state(&"achilles"))
	manager.cleanup_run_state()
	manager.free()


func test_invalid_empty_duplicate_and_mismatched_profiles_are_rejected() -> void:
	var empty := RunContentProfile.new()
	empty.profile_id = &"empty"
	empty.display_name = "Vide"
	assert_false(empty.is_valid())
	assert_true(str(empty.validation_errors()).contains("au moins un heros"))

	var source_profile := _run().content_profile.hero_profiles[0]
	var duplicate := RunContentProfile.new()
	duplicate.profile_id = &"duplicate"
	duplicate.display_name = "Doublon"
	duplicate.hero_profiles = [source_profile, source_profile]
	assert_false(duplicate.is_valid())
	assert_true(str(duplicate.validation_errors()).contains("duplique"))

	var mismatch := RunHeroProfile.new()
	mismatch.character_id = &"not_achilles"
	mismatch.base_unit_data = source_profile.base_unit_data
	mismatch.progression_profile = source_profile.progression_profile
	assert_false(mismatch.is_valid())
	assert_true(mismatch.validation_errors().size() >= 2)

	var invalid_run := RunData.new()
	invalid_run.run_name = "Profil invalide"
	invalid_run.rooms = _run().rooms.duplicate()
	invalid_run.content_profile = empty
	var resolution := RunHeroResolver.resolve_runtime_hero_data(
		invalid_run, false
	)
	assert_false(resolution.is_valid())
	assert_true(resolution.heroes.is_empty())


func test_odyssey_victory_defeat_relaunch_and_trio_switches_are_clean() -> void:
	var run := _run()
	var manager = GameManagerScript.new()
	var resolved := RunHeroResolver.resolve_runtime_hero_data(run, false)
	assert_true(manager._prepare_preconfigured_run(run, resolved.heroes))
	for room_index in range(run.rooms.size()):
		manager.current_room_index = room_index
		manager._room_outcome_resolved = false
		manager.begin_combat_report()
		manager.on_battle_won()
		var report := manager.get_current_combat_report()
		assert_not_null(report)
		assert_true(report.victory)
		assert_true(manager.complete_post_combat_transition(report.report_id))
	assert_true(bool(manager.get_last_run_result().get("victory", false)))
	assert_eq(manager.get_last_run_result().get("run_name"), "Catabase")

	assert_true(manager._prepare_preconfigured_run(run, resolved.heroes))
	manager.current_room_index = 0
	manager.begin_combat_report()
	manager.on_battle_lost()
	assert_false(bool(manager.get_last_run_result().get("victory", true)))

	for path in [TEST_PATH, ODYSSEY_PATH, MAIN_PATH, ODYSSEY_PATH]:
		var next_run := load(path) as RunData
		var next_resolution := RunHeroResolver.resolve_runtime_hero_data(
			next_run, false
		)
		assert_true(next_resolution.is_valid(), path)
		assert_true(manager._prepare_preconfigured_run(
			next_run, next_resolution.heroes
		), path)
		var expected_size := 1 if path == ODYSSEY_PATH else 3
		assert_eq(manager.heroes.size(), expected_size, path)
		assert_eq(manager.character_states.size(), expected_size, path)
		assert_eq(
			manager.get_character_state(&"achilles") != null,
			path == ODYSSEY_PATH,
			path,
		)
	manager.cleanup_run_state()
	assert_true(manager.heroes.is_empty())
	assert_true(manager.character_states.is_empty())
	manager.free()


func test_spear_guard_and_once_per_activation_use_real_spell_caster() -> void:
	var spear := _progression().spells[0]
	var guard := _progression().spells[3]
	var spear_field := Factory.make_battlefield(5, 1)
	var achilles := _runtime_unit()
	var target := Unit.new("Cible", 1, 100)
	spear_field.grid.place_unit(achilles, Vector2i(0, 0))
	spear_field.grid.place_unit(target, Vector2i(2, 0))
	var report := spear_field.caster.cast(achilles, spear, target.grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq(target.current_hp, 91)
	assert_eq(achilles.current_ap, 4)
	var duplicate := spear_field.caster.cast(achilles, spear, target.grid_pos)
	assert_true(duplicate.get("failed", false))
	assert_eq(target.current_hp, 91)

	var guard_field := Factory.make_battlefield(1, 1)
	var guarded := _runtime_unit()
	guard_field.grid.place_unit(guarded, Vector2i.ZERO)
	var guard_report := guard_field.caster.cast(guarded, guard, guarded.grid_pos)
	assert_false(guard_report.get("failed", false), str(guard_report))
	assert_eq(guarded.current_shield, 10)
	assert_eq(guarded.current_ap, 4)


func test_advance_moves_to_contact_and_never_crosses_wall_or_unit() -> void:
	var advance := _progression().spells[1]
	var open_field := Factory.make_battlefield(5, 1)
	var achilles := _runtime_unit()
	var target := Unit.new("Cible", 1, 100)
	open_field.grid.place_unit(achilles, Vector2i(0, 0))
	open_field.grid.place_unit(target, Vector2i(3, 0))
	var visual_sync := {
		"count": 0,
		"unit": null,
		"from": Vector2i(-1, -1),
		"to": Vector2i(-1, -1),
	}
	var capture_visual_sync := func(
			moved_unit: Unit,
			from_cell: Vector2i,
			to_cell: Vector2i,
			_collision: bool
		) -> void:
		visual_sync.count += 1
		visual_sync.unit = moved_unit
		visual_sync.from = from_cell
		visual_sync.to = to_cell
	EventBus.unit_pushed.connect(capture_visual_sync)
	var report := open_field.caster.cast(achilles, advance, target.grid_pos)
	EventBus.unit_pushed.disconnect(capture_visual_sync)
	assert_false(report.get("failed", false), str(report))
	assert_eq(target.current_hp, 95)
	assert_eq(achilles.grid_pos, Vector2i(2, 0))
	assert_eq(visual_sync.count, 1)
	assert_same(visual_sync.unit, achilles)
	assert_eq(visual_sync.from, Vector2i(0, 0))
	assert_eq(visual_sync.to, Vector2i(2, 0))

	var wall_field := Factory.make_battlefield(5, 1)
	var wall_achilles := _runtime_unit()
	var wall_target := Unit.new("Cible mur", 1, 100)
	wall_field.grid.place_unit(wall_achilles, Vector2i(0, 0))
	wall_field.grid.place_unit(wall_target, Vector2i(3, 0))
	wall_field.grid.set_type(Vector2i(1, 0), GridData.CellType.WALL)
	var wall_report := wall_field.caster.cast(
		wall_achilles, advance, wall_target.grid_pos
	)
	assert_true(wall_report.get("failed", false), str(wall_report))
	assert_eq(wall_achilles.grid_pos, Vector2i(0, 0))
	assert_eq(wall_achilles.current_ap, 6)
	assert_eq(wall_target.current_hp, 100)

	var unit_field := Factory.make_battlefield(5, 1)
	var unit_achilles := _runtime_unit()
	var blocker := Unit.new("Bloqueur", 1, 100)
	var unit_target := Unit.new("Cible unité", 1, 100)
	unit_field.grid.place_unit(unit_achilles, Vector2i(0, 0))
	unit_field.grid.place_unit(blocker, Vector2i(1, 0))
	unit_field.grid.place_unit(unit_target, Vector2i(3, 0))
	var blocked_report := unit_field.caster.cast(
		unit_achilles, advance, unit_target.grid_pos
	)
	assert_true(blocked_report.get("failed", false), str(blocked_report))
	assert_eq(blocked_report.get("reason"), "movement_path")
	assert_eq(unit_achilles.grid_pos, Vector2i(0, 0))
	assert_eq(unit_achilles.current_ap, 6)
	assert_eq(unit_target.current_hp, 100)

	var adjacent_field := Factory.make_battlefield(3, 1)
	var adjacent_achilles := _runtime_unit()
	var adjacent_target := Unit.new("Cible déjà au contact", 1, 100)
	adjacent_field.grid.place_unit(adjacent_achilles, Vector2i(0, 0))
	adjacent_field.grid.place_unit(adjacent_target, Vector2i(1, 0))
	assert_false(
		adjacent_field.caster.get_targetable_cells(adjacent_achilles, advance) \
			.has(adjacent_target.grid_pos)
	)
	var adjacent_report := adjacent_field.caster.cast(
		adjacent_achilles, advance, adjacent_target.grid_pos
	)
	assert_true(adjacent_report.get("failed", false), str(adjacent_report))
	assert_eq(adjacent_achilles.current_ap, 6)
	assert_eq(adjacent_target.current_hp, 100)

	var lethal_field := Factory.make_battlefield(5, 1)
	var lethal_achilles := _runtime_unit()
	var lethal_target := Unit.new("Cible fragile", 1, 5)
	lethal_field.grid.place_unit(lethal_achilles, Vector2i(0, 0))
	lethal_field.grid.place_unit(lethal_target, Vector2i(3, 0))
	var lethal_movement: Array[Vector2i] = []
	var capture_lethal_move := func(
			moved_unit: Unit,
			_from: Vector2i,
			to: Vector2i,
			_collision: bool
		) -> void:
		if moved_unit == lethal_achilles:
			lethal_movement.append(to)
	EventBus.unit_pushed.connect(capture_lethal_move)
	var lethal_report := lethal_field.caster.cast(
		lethal_achilles, advance, lethal_target.grid_pos
	)
	EventBus.unit_pushed.disconnect(capture_lethal_move)
	assert_false(lethal_report.get("failed", false), str(lethal_report))
	assert_false(lethal_target.is_alive)
	assert_eq(lethal_achilles.grid_pos, Vector2i(2, 0))
	assert_eq(lethal_movement, [Vector2i(2, 0)])


func test_sweep_hits_and_pushes_only_cardinal_adjacent_enemies() -> void:
	var sweep := _progression().spells[2]
	var field := Factory.make_battlefield(7, 7)
	var achilles := _runtime_unit()
	var north := Unit.new("Nord", 1, 100)
	var east := Unit.new("Est", 1, 100)
	var diagonal := Unit.new("Diagonale", 1, 100)
	field.grid.place_unit(achilles, Vector2i(3, 3))
	field.grid.place_unit(north, Vector2i(3, 2))
	field.grid.place_unit(east, Vector2i(4, 3))
	field.grid.place_unit(diagonal, Vector2i(4, 4))
	var report := field.caster.cast(achilles, sweep, achilles.grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq([north.current_hp, east.current_hp, diagonal.current_hp], [94, 94, 100])
	assert_eq(north.grid_pos, Vector2i(3, 1))
	assert_eq(east.grid_pos, Vector2i(5, 3))
	assert_eq(diagonal.grid_pos, Vector2i(4, 4))
	assert_eq(achilles.current_hp, 110)
	assert_eq(achilles.current_ap, 3)


func test_odyssey_economy_has_only_three_consumables_and_no_reward_deck() -> void:
	var run := _run()
	assert_not_null(run.economy_profile)
	assert_false(run.economy_profile.equipment_rewards_enabled)
	var resolved := RunHeroResolver.resolve_runtime_hero_data(run, false)
	var manager = GameManagerScript.new()
	assert_true(manager._prepare_preconfigured_run(run, resolved.heroes))
	assert_false(manager.are_equipment_rewards_enabled())
	assert_same(manager.get_active_economy_profile(), run.economy_profile)
	var quantities := _inventory_quantities(manager.get_run_inventory())
	assert_eq(quantities, {
		&"minor_healing_potion": 2,
		&"minor_action_scroll": 1,
	})
	for instance in manager.get_run_inventory().get_slots():
		if instance == null:
			continue
		var definition := manager.get_item_catalog().get_definition(instance.definition_id)
		assert_not_null(definition)
		assert_false(definition.is_equippable())
	var reward_snapshot := manager.get_equipment_reward_deck_snapshot()
	assert_true((reward_snapshot.get("deck", []) as Array).is_empty())
	assert_true((reward_snapshot.get("eligible_ids", []) as Array).is_empty())
	manager.current_room_index = 0
	manager.begin_combat_report()
	manager.on_battle_won()
	var report_id: StringName = manager.get_current_combat_report().report_id
	assert_true(manager.get_post_combat_reward_options().is_empty())
	assert_false(manager.can_claim_post_combat_equipment(report_id))
	assert_true(manager.complete_post_combat_transition(report_id))
	manager.cleanup_run_state()
	manager.free()


func test_catabase_disciplines_offer_one_signature_evolution_each() -> void:
	var run := _run()
	var resolved := RunHeroResolver.resolve_runtime_hero_data(run, false)
	var manager = GameManagerScript.new()
	assert_true(manager._prepare_preconfigured_run(run, resolved.heroes))
	var state: CharacterRunState = manager.get_character_state(&"achilles")
	for discipline_id in DISCIPLINE_IDS:
		state.add_discipline_xp(discipline_id, 3)
		var progress := state.get_discipline_progress(discipline_id)
		assert_eq(progress.rank, 2)
		assert_eq(progress.get_pending_rank_choices(), [2])
	var pending := manager.get_pending_progression_choices()
	assert_eq(pending.size(), 4)
	assert_eq(
		pending.map(func(choice): return choice["discipline_id"]),
		DISCIPLINE_IDS,
	)
	assert_true(pending.all(func(choice): return choice["choices"].size() == 2))
	for choice in pending:
		var selected = choice["choices"][0]
		assert_true(manager.choose_progression_upgrade(
			&"achilles",
			choice["discipline_id"],
			choice["rank"],
			selected.upgrade_id,
		))
		assert_eq(
			state.get_discipline_progress(choice["discipline_id"]).rank,
			2,
		)
	assert_true(manager.get_pending_progression_choices().is_empty())
	manager.cleanup_run_state()
	manager.free()


func test_runtime_visual_adapter_releases_falls_back_and_dies_cleanly() -> void:
	var view = UnitViewScript.new()
	add_child(view)
	var unit := _runtime_unit()
	view.setup(unit)
	await wait_process_frames(2)
	var adapter := view.get_optional_visual() as AchillesIsoUnitView
	assert_not_null(adapter)
	await wait_process_frames(4)
	assert_eq(adapter.get_active_backend_name(), &"Viewport3DBackend")
	assert_eq(adapter.get_default_cast_effect_origin(), Vector2(0.0, -92.0))
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		adapter.set_facing(direction)
	assert_eq(adapter.viewport_backend.get_facing_label(), "N")
	assert_true(adapter.find_children(
		"*", "AchillesVisual2D", true, false
	).is_empty())
	var releases := {"count": 0}
	adapter.cast_release_reached.connect(func(): releases.count += 1)
	assert_true(adapter.play_spell_action(_progression().spells[0]))
	adapter._on_backend_action_release(adapter.viewport_backend)
	adapter._on_backend_action_release(adapter.viewport_backend)
	assert_eq(releases.count, 1)
	adapter._on_backend_action_finished(
		&"ACTION_FALLBACK", adapter.viewport_backend
	)
	var deaths := {"count": 0}
	adapter.death_animation_finished.connect(func(): deaths.count += 1)
	unit.take_damage(999)
	await get_tree().create_timer(0.4).timeout
	assert_eq(deaths.count, 1)
	assert_false(is_instance_valid(view))


func test_visual_cleanup_cancels_pending_action_without_late_release() -> void:
	var adapter := preload(
		"res://characters/achilles/AchillesIsoUnitView.tscn"
	).instantiate() as AchillesIsoUnitView
	add_child(adapter)
	await wait_process_frames(2)
	var releases := {"count": 0}
	adapter.cast_release_reached.connect(func(): releases.count += 1)
	assert_true(adapter.play_cast())
	adapter.cancel_pending_visual_actions()
	adapter.queue_free()
	await wait_process_frames(3)
	assert_eq(releases.count, 0)
	assert_false(is_instance_valid(adapter))


func test_refined_hud_resolves_portrait_icons_utilities_and_no_basic_attack() -> void:
	var unit := _runtime_unit()
	var hud = RecraftedHUDScene.instantiate()
	hud.skin_variant = hud.HudSkinVariant.REFINED
	add_child_autofree(hud)
	await wait_process_frames(2)
	hud.update_info(unit)
	hud.build_spell_buttons(unit)
	var theme: CharacterHUDThemeData = hud.get_active_character_theme()
	assert_not_null(theme)
	assert_eq(theme.character_id, &"achilles")
	assert_true(theme.refined_components)
	assert_not_null(theme.portrait_texture)
	assert_eq(hud._spell_buttons.size(), 4)
	for spell in unit.spells:
		assert_not_null(theme.get_spell_icon_for(spell), spell.resource_path)
	assert_false(hud._attack_btn.visible)
	assert_true(hud._utility_dock.visible)
	assert_true(hud._inventory_button.visible)
	assert_true(hud._skills_button.visible)


func test_studio_catalogs_open_odyssey_hero_and_all_three_rooms() -> void:
	var run := _run()
	var discovered := RunContentCatalogService.discover_runs()
	assert_true(discovered.any(func(item: RunData): return item.resource_path == ODYSSEY_PATH))
	assert_eq(RunContentCatalogService.heroes_for_run(run).size(), 1)
	var skill_session := SkillTreeEditSession.new()
	assert_true(skill_session.open_progression(
		run, run.content_profile.hero_profiles[0]
	))
	assert_eq(skill_session.working_unit.unit_id, &"achilles")
	var encounter_session := EncounterEditSession.new()
	assert_true(encounter_session.open(run, ODYSSEY_PATH))
	assert_eq(encounter_session.working_run.rooms.size(), 3)
	for room in encounter_session.working_run.rooms:
		assert_not_null(room.encounter_definition)


func test_main_and_test_runs_keep_their_existing_contracts() -> void:
	var main := load(MAIN_PATH) as RunData
	var test_run := load(TEST_PATH) as RunData
	assert_eq([main.run_name, main.rooms.size()], ["Principal", 6])
	assert_eq([test_run.run_name, test_run.rooms.size()], ["Run de test", 4])
	assert_null(main.economy_profile)
	assert_null(test_run.economy_profile)
	assert_eq(RunHeroResolver.resolve_runtime_hero_data(main, false).heroes.size(), 3)
	assert_eq(RunHeroResolver.resolve_runtime_hero_data(test_run, false).heroes.size(), 3)
	var isolation := RunContentIsolationAuditService.compare_runs(main, test_run)
	assert_eq(isolation.get("verdict"), "VALID")
	assert_eq(isolation.get("progression_shared_count"), 0)


func test_odyssey_rooms_encounters_and_progression_are_isolated() -> void:
	var odyssey := _run()
	var odyssey_room_paths := {}
	var odyssey_encounter_paths := {}
	for room in odyssey.rooms:
		odyssey_room_paths[room.resource_path] = true
		odyssey_encounter_paths[room.encounter_definition.resource_path] = true
	var odyssey_progression = (
		odyssey.content_profile.hero_profiles[0].progression_profile
	)
	for other_path in [MAIN_PATH, TEST_PATH]:
		var other := load(other_path) as RunData
		for room in other.rooms:
			assert_false(odyssey_room_paths.has(room.resource_path), other_path)
			if room.encounter_definition != null:
				assert_false(
					odyssey_encounter_paths.has(
						room.encounter_definition.resource_path
					),
					other_path,
				)
		for hero_profile in other.content_profile.hero_profiles:
			assert_not_same(
				odyssey_progression,
				hero_profile.progression_profile,
				other_path,
			)
		var audit := RunContentIsolationAuditService.compare_runs(
			odyssey, other
		)
		assert_eq(audit.get("verdict"), "VALID", str(audit))
		assert_eq(audit.get("progression_shared_count"), 0, other_path)


func test_odyssey_never_mutates_or_consumes_the_main_reward_deck() -> void:
	var manager = GameManagerScript.new()
	var main := load(MAIN_PATH) as RunData
	var main_resolution := RunHeroResolver.resolve_runtime_hero_data(main, false)
	assert_true(manager._prepare_preconfigured_run(
		main, main_resolution.heroes
	))
	var before := manager.get_equipment_reward_deck_snapshot()
	assert_true((before.get("deck", []) as Array).size() > 0)

	var odyssey := _run()
	var odyssey_resolution := RunHeroResolver.resolve_runtime_hero_data(
		odyssey, false
	)
	assert_true(manager._prepare_preconfigured_run(
		odyssey, odyssey_resolution.heroes
	))
	var during := manager.get_equipment_reward_deck_snapshot()
	assert_true((during.get("deck", []) as Array).is_empty())
	assert_true((during.get("offered_ids", []) as Array).is_empty())

	assert_true(manager._prepare_preconfigured_run(
		main, main_resolution.heroes
	))
	var after := manager.get_equipment_reward_deck_snapshot()
	# Le run principal randomise volontairement sa graine a chaque lancement :
	# l'ordre de la pioche peut donc changer, mais jamais son contenu ni son etat.
	var normalized_before := before.duplicate(true)
	var normalized_after := after.duplicate(true)
	var before_deck := normalized_before.get("deck", []) as Array
	var after_deck := normalized_after.get("deck", []) as Array
	before_deck.sort()
	after_deck.sort()
	normalized_before["deck"] = before_deck
	normalized_after["deck"] = after_deck
	assert_eq(normalized_after, normalized_before)
	manager.cleanup_run_state()
	manager.free()


func _run() -> RunData:
	return load(ODYSSEY_PATH) as RunData


func _progression() -> CharacterProgressionProfile:
	return _run().content_profile.hero_profiles[0].progression_profile


func _runtime_unit() -> Unit:
	var result := RunHeroResolver.resolve_runtime_hero_data(_run(), false)
	return Unit.from_data(result.heroes[0])


func _spell_ids(spells: Array[Spell]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for spell in spells:
		ids.append(spell.get_effective_spell_id())
	return ids


func _discipline_ids(disciplines: Array[DisciplineData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for discipline in disciplines:
		ids.append(discipline.discipline_id)
	return ids


func _inventory_quantities(inventory: RunInventory) -> Dictionary:
	var quantities := {}
	for instance in inventory.get_slots():
		if instance != null:
			quantities[instance.definition_id] = int(
				quantities.get(instance.definition_id, 0)
			) + instance.quantity
	return quantities


func _roster_ids(room: RoomData) -> Array[StringName]:
	var ids: Array[StringName] = []
	for unit_data in room.encounter_definition.expanded_roster():
		ids.append(unit_data.get_effective_unit_id())
	return ids
