extends "res://tools/catabase_monster_validation/combat_probe.gd"
## Bounded experiment: production visual controller and four real estocs in one room.
## All replacements live in duplicated in-memory resources; production assets are hashed.

const Clips := preload("res://addons/dungeon_draft_arena_studio/services/sprite_clip_service.gd")
const SOURCE := "res://art/source/sprite_workshop/sentinelle_attack_pilot_2026-09-09/"
const PROFILE := "res://data/visuals/catabase_monsters/sentinelle_airain_sprite_profile.tres"
var _exports: Dictionary = {}
var _profiles: Dictionary = {}
var _controller_results: Array[Dictionary] = []
var _combat_results: Array[Dictionary] = []
var _protected_hashes: Dictionary = {}


func _ready() -> void:
	_output = ProjectSettings.globalize_path("res://artifacts/sprite_workshop/sentinelle_attack_pilot_2026-09-09/runtime")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(_output)
	_resolution = Vector2i(1280, 720)
	get_window().size = _resolution
	get_tree().create_timer(120.0).timeout.connect(_watchdog)
	_run.call_deferred()


func _run() -> void:
	var profile := load(PROFILE) as CatabaseMonsterSpriteProfile
	var originals := load(profile.sprite_frames_path) as SpriteFrames
	for path: String in [PROFILE, profile.sprite_frames_path,
			"res://assets/characters/catabase_monsters/sentinelle_airain/atlas_E.png"]:
		_protected_hashes[path] = FileAccess.get_sha256(path)
	var documents := {"original": "res://art/source/sprite_workshop/sentinelle_attack_e.json",
		"a": SOURCE + "variant_a.json", "b": SOURCE + "variant_b.json",
		"b_held": SOURCE + "variant_b_held.json"}
	for key: String in documents:
		var read := Clips.read_document(documents[key])
		_check(read.ok, key + ": document readable")
		if not read.ok: continue
		var exported := Clips.export_clip(read.document)
		_exports[key] = exported
		_check(exported.ok, key + ": exported with exact pixel and timing roundtrip")
		if not exported.ok: continue
		var clip := load(exported.sprite_frames) as SpriteFrames
		var merged := originals.duplicate(false) as SpriteFrames
		merged.clear(&"attack_E")
		merged.set_animation_speed(&"attack_E", clip.get_animation_speed(&"attack_E"))
		merged.set_animation_loop(&"attack_E", false)
		for index in clip.get_frame_count(&"attack_E"):
			merged.add_frame(&"attack_E", clip.get_frame_texture(&"attack_E", index),
				clip.get_frame_duration(&"attack_E", index))
		var unchanged := 0
		for animation: StringName in originals.get_animation_names():
			if animation == &"attack_E": continue
			var same := merged.get_frame_count(animation) == originals.get_frame_count(animation)
			same = same and merged.get_animation_speed(animation) == originals.get_animation_speed(animation)
			same = same and merged.get_animation_loop(animation) == originals.get_animation_loop(animation)
			for index in originals.get_frame_count(animation):
				same = same and merged.get_frame_texture(animation, index) == originals.get_frame_texture(animation, index)
				same = same and merged.get_frame_duration(animation, index) == originals.get_frame_duration(animation, index)
			_check(same, key + ": unchanged clip " + str(animation))
			if same: unchanged += 1
		_check(unchanged == 23, key + ": preserves other 23 clips")
		var candidate := profile.duplicate(false) as CatabaseMonsterSpriteProfile
		candidate.frames = merged
		_check(candidate.validation_error(merged) == &"", key + ": full production profile contract")
		_profiles[key] = candidate
		_test_controller(key, candidate)
	if _profiles.size() == 4 and _errors.is_empty():
		await _test_combat()
	for path: String in _protected_hashes:
		_check(FileAccess.get_sha256(path) == _protected_hashes[path], "Production source unchanged: " + path)
	for frame in 4: await get_tree().process_frame
	_verify_teardown()
	_check(_controller_results.size() == 4, "Four controller variants exercised")
	_check(_combat_results.size() == 4, "Four real combat estocs exercised")
	var deadline := Time.get_ticks_msec() + 3000
	while _capture_jobs > 0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		for key: String in documents:
			_check(_captures.has(key + "_attack"), key + ": GPU impact capture exists")
	_finished = true
	_write_report()
	get_tree().quit(0 if _errors.is_empty() else 1)


func _test_controller(key: String, profile: CatabaseMonsterSpriteProfile) -> void:
	var view := CatabaseMonsterIsoUnitView.new()
	view.sprite_profile = profile
	add_child(view)
	view.set_process(false)
	view.set_facing_label("E")
	var signals_seen: Array[Dictionary] = []
	view.cast_release_reached.connect(func() -> void:
		signals_seen.append(view.get_visual_runtime_state().duplicate(true)))
	_check(view.play_basic_attack(), key + ": attack starts")
	view.advance_simulation(0.399)
	_check(signals_seen.is_empty() and view.animated_sprite.frame == 3, key + ": no early release at 399 ms")
	view.advance_simulation(0.001)
	_check(signals_seen.size() == 1, key + ": release at 400 ms exactly once")
	if signals_seen.size() == 1:
		_check(signals_seen[0].frame == 4 and is_equal_approx(signals_seen[0].action_elapsed, 0.4),
			key + ": callback sees impact pose at authored time")
	view.advance_simulation(0.4)
	_check(view.animated_sprite.animation == &"idle_E" and not view.get_visual_runtime_state().action_pending,
		key + ": returns to idle at 800 ms")
	var sprite := view.animated_sprite
	_check(not sprite.flip_h and not sprite.flip_v, key + ": no mirroring")
	_check(sprite.transform * (sprite.offset + profile.foot_anchor) == Vector2.ZERO, key + ": fixed logical ground anchor")
	_check(view.play_basic_attack(), key + ": cancellation fixture starts")
	view.advance_simulation(0.2)
	view.cancel_pending_visual_actions()
	view.advance_simulation(1.0)
	_check(signals_seen.size() == 1, key + ": cancellation suppresses stale release")
	_check(view.play_basic_attack(), key + ": slow frame fixture starts")
	view.advance_simulation(1.2)
	_check(signals_seen.size() == 2 and signals_seen[-1].frame == 4, key + ": large delta preserves single impact callback")
	_controller_results.append({"variant":key, "release_ms":400, "duration_ms":800,
		"release_samples":signals_seen, "other_clips_preserved":23})
	view.free()


func _test_combat() -> void:
	GameManager.expedition_save_path = _output.path_join("isolated_save.json")
	GameManager.set_reduced_motion_enabled(false)
	# Current routes use evolved brutes with other spell kits. Use a declared
	# canonical-Sentinelle fixture inside an actual route room, not a fake attack.
	var route_node: Dictionary = {}
	for node: Dictionary in ExpeditionRouteCatalog.create_nodes(SEED):
		if int(node.depth) == 2 and str(node.get("reward", "")) == "melee":
			route_node = node
			break
	_check(not route_node.is_empty(), "Production portico room selected")
	if route_node.is_empty(): return
	var room := ExpeditionRunFactory.make_room(route_node, SEED)
	var sentinel := load("res://data/units/enemies/catabase_sentinelle_airain.tres") as UnitData
	var encounter := room.encounter_definition.duplicate(false) as EncounterDefinition
	encounter.roster_units = [sentinel]
	encounter.roster_counts = PackedInt32Array([1])
	encounter.living_enemy_cap = 1
	encounter.minimum_path_distance_by_role = {sentinel.tactical_role_id:5}
	encounter.maximum_path_distance_by_role = {sentinel.tactical_role_id:13}
	room.encounter_definition = encounter
	room.enemies = encounter.expanded_roster()
	var run := ExpeditionRunFactory.create(SEED, {"achilles":"painted_g"})
	run.rooms = [room]
	var resolution = GameManager.resolve_run_hero_data(run, false)
	_check(resolution.is_valid(), "Canonical hero resolution")
	if not resolution.is_valid(): return
	_check(GameManager._prepare_preconfigured_run(run, resolution.heroes), "Runtime preparation")
	var build := ExpeditionBuildState.new()
	_check(build.initialize(GameManager.get_character_state(&"achilles")), "Canonical hero kit")
	GameManager.current_room_index = 0
	var battle := room.battle_scene.instantiate()
	add_child(battle)
	var deadline := Time.get_ticks_msec() + 25000
	while not bool(battle.get("runtime_ready_state")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(bool(battle.get("runtime_ready_state")), "Real Battle ready")
	if not bool(battle.get("runtime_ready_state")):
		await _close_battle(battle)
		return
	var enemy: Unit
	for unit: Unit in battle.get("units"):
		if unit.unit_id == &"catabase_sentinelle_airain": enemy = unit
	_check(enemy != null, "Real Sentinelle spawned")
	if enemy == null:
		await _close_battle(battle)
		return
	var hero: Unit = GameManager.heroes[0]
	var hp_fixture := hero.current_hp
	var view = battle.get("_unit_views").get(enemy)
	var visual := view.get_optional_visual() as CatabaseMonsterIsoUnitView
	_check(visual != null, "Production painted backend bound")
	if visual == null:
		await _close_battle(battle)
		return
	var deployment = battle.get("_deployment")
	if deployment != null and deployment.is_active(): deployment.on_cell_clicked(room.hero_spawn_zone[0])
	deadline = Time.get_ticks_msec() + 10000
	while not bool(battle.call("_can_accept_player_intent")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(bool(battle.call("_can_accept_player_intent")), "Deployment completed")
	await _wait_for_intro(battle, "Sentinelle pilot")
	var spell: Spell
	for candidate: Spell in enemy.spells:
		if candidate.get_effective_spell_id() == &"catabase_airain_estoc": spell = candidate
	_check(spell != null, "Real estoc spell exists")
	if spell == null:
		await _close_battle(battle)
		return
	var grid := battle.get("grid") as GridData
	var caster := battle.get("spell_caster") as SpellCaster
	var found := false
	for x in range(enemy.grid_pos.x + 1, grid.cols):
		var target := Vector2i(x, enemy.grid_pos.y)
		if not grid.is_walkable(target, hero) or (grid.has_unit(target) and grid.get_unit(target) != hero): continue
		var previous := hero.grid_pos
		if not grid.relocate_unit(hero, target): continue
		enemy.start_turn()
		if caster.can_cast(enemy, spell, target):
			found = true
			break
		grid.relocate_unit(hero, previous)
	_check(found, "Legal estoc target in E direction")
	if not found:
		await _close_battle(battle)
		return
	var hero_view = battle.get("_unit_views").get(hero)
	hero_view.position = battle.call("grid_cell_to_parent_local", hero.grid_pos, hero_view.get_parent())
	hero_view.synchronize_external_movement()
	var runner := battle.get("_enemy_turn") as EnemyTurnRunner
	for key: String in _profiles:
		# Explicit repeatable fixture: heal between comparisons and refresh cooldowns.
		hero.current_hp = hp_fixture
		for activation in 4: enemy.start_turn()
		_check(visual.configure_profile(_profiles[key]), key + ": temporary profile configured in Battle")
		visual.set_facing_label("E")
		_active_views.clear()
		_active_views[key] = visual.animated_sprite
		var release_samples: Array[Dictionary] = []
		var callback := func() -> void: release_samples.append(visual.get_visual_runtime_state().duplicate(true))
		visual.cast_release_reached.connect(callback)
		var hp_before := hero.current_hp
		var ap_before := enemy.current_ap
		var uses_before := enemy.get_spell_uses(spell)
		_check(caster.can_cast(enemy, spell, hero.grid_pos), key + ": real cast legal")
		await runner._execute_cast(enemy, spell, hero.grid_pos)
		visual.cast_release_reached.disconnect(callback)
		_check(hero.current_hp < hp_before, key + ": actual damage applied")
		_check(enemy.current_ap == ap_before - spell.ap_cost, key + ": actual AP cost applied")
		_check(enemy.get_spell_uses(spell) == uses_before + 1, key + ": one actual cast use")
		_check(release_samples.size() == 1, key + ": one live release signal")
		if release_samples.size() == 1:
			_check(release_samples[0].animation == "attack_E" and release_samples[0].frame == 4,
				key + ": real E impact pose")
			_check(is_equal_approx(release_samples[0].action_elapsed,0.4), key + ": live release at 400 ms")
		_combat_results.append({"variant":key, "spell":str(spell.spell_id), "enemy_cell":_cell(enemy.grid_pos),
			"target_cell":_cell(hero.grid_pos), "hp_before":hp_before, "hp_after":hero.current_hp,
			"ap_before":ap_before, "ap_after":enemy.current_ap, "uses_before":uses_before,
			"uses_after":enemy.get_spell_uses(spell), "release_samples":release_samples})
		await _capture(key + "_resolved")
	_active_views.clear()
	await _close_battle(battle)


func _write_report() -> void:
	var report := {"passed":_errors.is_empty(), "checks":_checks, "errors":_errors,
		"exports":_exports, "controller":_controller_results, "combat":_combat_results,
		"captures":_captures, "resolution":[1280,720], "engine":Engine.get_version_info().string,
		"protected_source_hashes":_protected_hashes, "visual_quality_approved":false,
		"scope":"Four visual variants, deterministic controller checks, four legal real estocs in one production room. Explicit fixture replaces evolved-brute roster by canonical Sentinelle, positions hero and heals between casts. No full run, current evolved kits or all-direction art validation."}
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t"))
	print("SENTINELLE_PILOT=" + JSON.stringify({"passed":report.passed,"checks":_checks,"errors":_errors,"report":_output.path_join("report.json")}))
