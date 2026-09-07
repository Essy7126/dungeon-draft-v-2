extends Node

const PROBE := preload("res://tools/paris_sprite_validation/final_boss_probe.gd")
const RUN_PATH := "res://data/runs/odyssey.tres"
const ROOM_PATH := "res://data/rooms/odyssey/room_05.tres"


func _ready() -> void:
	_launch.call_deferred()


func _launch() -> void:
	var probe := PROBE.new()
	probe.configuration = {"scenario": "production_final", "direction": "observed_from_spawn",
		"source_run_path": RUN_PATH, "source_room_index": 4, "room_path": ROOM_PATH,
		"scope": "Canonical final encounter, unchanged map/spawns/roster. A memory-only run starts directly in this room and awards level 6 before combat; no preceding campaign rooms are claimed."}
	probe.placement = {"ok": true, "scope": "Production enemy and hero spawn zones and formation planner are unmodified.",
		"modified_initial_fields": []}
	get_tree().root.add_child(probe)
	var production := load(RUN_PATH) as RunData
	if production == null or production.rooms.size() != 5 or production.rooms[4].resource_path != ROOM_PATH:
		_fail(probe, "canonical_final_room_not_fifth")
		return
	var final_room := production.rooms[4] as ArenaDefinition
	if final_room == null or final_room.grid_layout == null or final_room.painted_map_visual_data == null:
		_fail(probe, "canonical_final_room_runtime_projection_missing")
		return
	var final_visual := final_room.painted_map_visual_data
	if final_visual.presentation_profile == null or final_visual.presentation_profile.resource_path != final_room.presentation_profile_path:
		_fail(probe, "canonical_final_presentation_profile_missing_or_stale")
		return
	probe.configuration.presentation_profile_path = final_visual.presentation_profile.resource_path
	var boss := load("res://data/units/enemies/catabase_shadow_paris.tres") as UnitData
	if final_room.encounter_definition == null or not final_room.encounter_definition.expanded_roster().has(boss):
		_fail(probe, "canonical_final_roster_does_not_include_paris")
		return
	for index in range(4):
		if production.rooms[index].encounter_definition.expanded_roster().has(boss):
			_fail(probe, "paris_appears_before_final_room")
			return
	var run := production.duplicate(false) as RunData
	run.run_name = "Paris final-room production verification"
	run.rooms = [final_room]
	run.default_seed = 9062026
	run.randomize_seed_each_run = false
	run.hub_room_selection_enabled = false
	probe.configuration.action_classification_catalog = run.action_classification_catalog.resource_path
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	if not resolution.is_valid():
		_fail(probe, "canonical_hero_resolution_failed")
		return
	var options := ArenaDirectTestConfiguration.resolve(&"real_encounter")
	options["camera_mode"] = "PRODUCTION"
	if not GameManager.start_direct_encounter_test(run, resolution.heroes, options):
		_fail(probe, "final_encounter_launch_failed")
		return
	var state := GameManager.get_character_state(&"achilles") as CharacterRunState
	if state == null or not state.uses_champion_progression():
		_fail(probe, "canonical_champion_state_missing")
		return
	var award := state.award_encounter_xp(&"paris_final_production_fixture", state.champion_progression.profile.xp_for_level(6), true)
	probe.progression = {"ok": bool(award.get("granted", false)), "level": 6, "xp_award": award,
		"scope": "Level 6 awarded before combat without mastery purchases or point allocation. No HP/AP/MP writes; this is final-room verification, not a campaign playthrough."}
	if not bool(probe.progression.ok):
		_fail(probe, "precombat_progression_fixture_failed")


func _fail(probe: Node, reason: String) -> void:
	(probe.get("_errors") as Array).append(reason)
	probe._finish({"launch_failed": true})
