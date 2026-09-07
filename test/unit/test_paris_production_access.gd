extends GutTest

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const PARIS: UnitData = preload("res://data/units/enemies/catabase_shadow_paris.tres")
const SOURCE_ARENA: ArenaDefinition = preload("res://data/arenas/silent_judgment_courtyard_v1/arena.tres")
const SOURCE_FINAL: ArenaDefinition = preload("res://data/arenas/black_oath_temple_v1/arena.tres")
const CASES := preload("res://tools/paris_sprite_validation/cases.gd")


func test_normal_catabase_selection_reaches_the_canonical_paris_room_without_extra_card() -> void:
	var entries := CharacterSelectionCatalog.get_entries()
	var selected: Dictionary = {}
	for entry: Dictionary in entries:
		if entry.get("run") == RUN:
			assert_true(selected.is_empty(), "one canonical solo Catabase entry")
			selected = entry
	assert_false(selected.is_empty(), "Paris is accessible from the normal Catabase menu")
	assert_eq(selected.get("id"), &"achilles")
	assert_eq(RUN.rooms.size(), 5)
	var room := RUN.rooms[4] as ArenaDefinition
	assert_not_null(room)
	if room == null:
		return
	assert_not_null(room.grid_layout)
	var final_visual: PaintedMapVisualData = room.painted_map_visual_data
	assert_not_null(final_visual)
	if final_visual == null:
		return
	assert_not_null(final_visual.presentation_profile)
	assert_same(final_visual.presentation_profile, load(SOURCE_FINAL.presentation_profile_path))
	assert_true(room.enemies.has(PARIS))
	assert_true(room.encounter_definition.expanded_roster().has(PARIS))
	assert_true(SOURCE_FINAL.encounter_definition.expanded_roster().has(PARIS), "final source arena and room share the exact boss")
	assert_eq(room.resource_path, "res://data/rooms/odyssey/room_05.tres")
	assert_eq(room.encounter_definition.room_index, 5)
	for index in range(4):
		assert_false(RUN.rooms[index].enemies.has(PARIS), "Paris is exclusive to the final room")
		assert_false(RUN.rooms[index].encounter_definition.expanded_roster().has(PARIS))
	assert_false(SOURCE_ARENA.encounter_definition.expanded_roster().has(PARIS))
	assert_eq(PARIS.visual_scene.resource_path, "res://characters/paris/ParisIsoUnitView.tscn")
	assert_null(PARIS.preview_visual_scene)
	assert_not_null(PARIS.preview_sprite_frames)
	assert_true(PARIS.preview_sprite_frames.has_animation(PARIS.preview_sprite_animation))
	assert_false(PARIS.description.contains("PLACEHOLDER"))


func test_combat_fixtures_preserve_canonical_enemy_rules_and_source_arena() -> void:
	var source_cells := SOURCE_ARENA.spawns.duplicate()
	var source_enemies := SOURCE_ARENA.enemies.duplicate()
	var source_visual: PaintedMapVisualData = SOURCE_ARENA.painted_map_visual_data
	var source_profile_path: String = SOURCE_ARENA.presentation_profile_path
	var source_profile := load(source_profile_path) as BattlePresentationProfile
	assert_not_null(source_profile)
	for scenario: String in CASES.SCENARIOS:
		for direction: String in CASES.DIRECTIONS:
			var arena := ArenaRuntimeBridge.build_runtime_projection(SOURCE_ARENA)
			assert_not_null(arena)
			if arena == null:
				continue
			assert_not_null(arena.painted_map_visual_data)
			assert_same(arena.painted_map_visual_data.presentation_profile, source_profile)
			var result: Dictionary = CASES.configure(arena, scenario, direction)
			assert_true(result.get("ok", false), "%s %s: %s" % [scenario, direction, result])
			if not result.get("ok", false):
				continue
			assert_eq(arena.enemies.size(), 1)
			var enemy := arena.enemies[0]
			assert_eq(enemy.unit_id, PARIS.unit_id)
			assert_eq(enemy.max_hp, PARIS.max_hp)
			assert_eq(enemy.max_ap, PARIS.max_ap)
			assert_eq(enemy.max_mp, PARIS.max_mp)
			assert_eq(enemy.spells, PARIS.spells)
			assert_same(enemy.ai_profile, PARIS.ai_profile)
			assert_same(enemy.combat_form_change, PARIS.combat_form_change)
			assert_same(enemy.visual_scene, PARIS.visual_scene)
	assert_eq(SOURCE_ARENA.spawns, source_cells, "no source map spawn writes")
	assert_eq(SOURCE_ARENA.enemies, source_enemies, "no source encounter writes")
	assert_same(SOURCE_ARENA.painted_map_visual_data, source_visual, "source projection was not installed or replaced")
	assert_eq(SOURCE_ARENA.presentation_profile_path, source_profile_path)
	assert_same(load(source_profile_path), source_profile)
