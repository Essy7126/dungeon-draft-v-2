extends GutTest

const Factory = preload("res://test/support/factory.gd")
const CATABASE_RUN: RunData = preload("res://data/runs/odyssey.tres")
const CATABASE_SEQUENCE: CinematicSequenceData = preload(
	"res://cinematics/catabase/catabase_intro_v4.tres"
)
const LEGACY_SEQUENCE: CinematicSequenceData = preload(
	"res://cinematics/intro/sequences/legacy_intro_sequence.tres"
)
const ARCHIVIST_PANEL := preload("res://hub/ui/ArchivistPanel.tscn")
const ARCHIVIST_DATA: LanternboundArchivistData = preload(
	"res://hub/data/lanternbound_archivist.tres"
)
const RunManagerSpyScript := preload("res://test/unit/helpers/intro_run_manager_spy.gd")


class FakeBattleView:
	extends Node2D

	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2(cell.x * 64.0, cell.y * 32.0)

const EXPECTED_FRAME_BOUNDS := [
	[0.0, 6.0],
	[6.0, 10.5],
	[10.5, 25.0],
	[25.0, 32.5],
	[32.5, 40.5],
	[40.5, 50.5],
	[50.5, 57.5],
	[57.5, 63.5],
	[63.5, 67.5],
	[67.5, 72.0],
]
const EXPECTED_FRAME_PATHS := [
	"res://cinematics/catabase/assets/00_contexte_fond.png",
	"res://cinematics/catabase/assets/01_troie_assiegee.png",
	"res://cinematics/catabase/assets/02_achille_deux_destins.png",
	"res://cinematics/catabase/assets/03_achille_choisit_troie.png",
	"res://cinematics/catabase/assets/04_mort_achille.png",
	"res://cinematics/catabase/assets/05_ame_quitte_corps.png",
	"res://cinematics/catabase/assets/06_passions_du_vivant.png",
	"res://cinematics/catabase/assets/07_enfers.png",
	"res://cinematics/catabase/assets/08_paris.png",
	"res://cinematics/catabase/assets/09_titre.png",
]
const STYLE_IDS := {
	"ContextTitle": &"context_title",
	"ContextLine": &"context_line",
	"ContextStrong": &"context_strong",
	"Narrative": &"narrative",
	"NarrativeSmall": &"narrative_small",
	"Key": &"key",
	"Passions": &"passions",
	"Paris": &"paris",
	"MainTitle": &"main_title",
	"SubTitle": &"subtitle",
}


func before_each() -> void:
	GameManager.cleanup_run_state()


func after_each() -> void:
	GameManager.cleanup_run_state()


func test_run_data_can_reference_intro_sequence() -> void:
	var run := RunData.new()
	run.intro_sequence = CATABASE_SEQUENCE
	assert_eq(run.intro_sequence.sequence_id, &"catabase_intro_v4")


func test_catabase_public_name_is_catabase() -> void:
	assert_eq(CATABASE_RUN.run_name, "Catabase")
	assert_eq(CATABASE_RUN.resource_path, "res://data/runs/odyssey.tres")


func test_catabase_intro_has_ten_frames() -> void:
	assert_eq(CATABASE_SEQUENCE.frames.size(), 10)
	for index in range(CATABASE_SEQUENCE.frames.size()):
		assert_not_null(CATABASE_SEQUENCE.frames[index].texture)
		assert_eq(
			CATABASE_SEQUENCE.frames[index].texture.resource_path,
			EXPECTED_FRAME_PATHS[index],
		)


func test_catabase_intro_has_twenty_four_text_cues() -> void:
	assert_eq(CATABASE_SEQUENCE.text_cues.size(), 24)
	for index in range(CATABASE_SEQUENCE.text_cues.size()):
		assert_eq(
			CATABASE_SEQUENCE.text_cues[index].localization_key,
			StringName("CATABASE_INTRO_%03d" % (index + 1)),
		)


func test_catabase_intro_duration_is_exactly_72_seconds() -> void:
	assert_eq(CATABASE_SEQUENCE.duration_seconds, 72.0)
	assert_eq(CATABASE_SEQUENCE.music_fade_out_start_seconds, 70.5)
	assert_eq(CATABASE_SEQUENCE.music_fade_out_seconds, 1.5)


func test_catabase_frame_boundaries_match_timeline() -> void:
	for index in range(EXPECTED_FRAME_BOUNDS.size()):
		var frame := CATABASE_SEQUENCE.frames[index]
		assert_eq(frame.start_time_seconds, EXPECTED_FRAME_BOUNDS[index][0])
		assert_eq(frame.end_time_seconds, EXPECTED_FRAME_BOUNDS[index][1])
	assert_true(CATABASE_SEQUENCE.validation_errors().is_empty())


func test_catabase_text_cues_match_ass_reference() -> void:
	var reference := _parse_ass_reference()
	assert_eq(reference.size(), 24)
	for index in range(reference.size()):
		var expected: Dictionary = reference[index]
		var cue := CATABASE_SEQUENCE.text_cues[index]
		assert_almost_eq(cue.start_time_seconds, expected.start, 0.001)
		assert_almost_eq(cue.end_time_seconds, expected.end, 0.001)
		assert_eq(cue.fallback_text, expected.text)
		assert_eq(cue.style_id, STYLE_IDS[expected.style])
		assert_eq(cue.layer, expected.layer)
		assert_almost_eq(cue.fade_in_seconds, expected.fade_in, 0.001)
		assert_almost_eq(cue.fade_out_seconds, expected.fade_out, 0.001)
		if expected.has("position"):
			assert_true(
				cue.normalized_position.is_equal_approx(expected.position),
				"position ASS de la cue %d" % (index + 1),
			)


func test_catabase_hub_start_is_forced_to_room_zero() -> void:
	assert_false(CATABASE_RUN.hub_room_selection_enabled)
	assert_eq(CATABASE_RUN.hub_forced_start_room_index, 0)
	assert_true(GameManager.configure_next_run(CATABASE_RUN, 2))
	assert_eq(GameManager._next_run_start_room_index, 0)


func test_catabase_room_selector_is_hidden_or_disabled() -> void:
	var panel := ARCHIVIST_PANEL.instantiate() as ArchivistPanel
	add_child_autofree(panel)
	await wait_process_frames(2)
	panel.open_panel(ARCHIVIST_DATA)
	panel.get_node("%RunButton").pressed.emit()
	var run_selector: OptionButton = panel.get_node("%RunSelector")
	run_selector.select(2)
	run_selector.item_selected.emit(2)
	var room_selector: OptionButton = panel.get_node("%RoomSelector")
	assert_false(room_selector.visible)
	assert_false(panel.get_node("%RoomSelectionLabel").visible)
	assert_eq(room_selector.item_count, 1)
	assert_eq(room_selector.get_selected_id(), 0)


func test_other_runs_do_not_use_catabase_intro() -> void:
	var runs := ARCHIVIST_DATA.get_available_runs()
	assert_eq(runs.size(), 3)
	assert_eq(runs[0].intro_sequence, LEGACY_SEQUENCE)
	assert_eq(runs[1].intro_sequence, LEGACY_SEQUENCE)
	assert_eq(runs[2].intro_sequence, CATABASE_SEQUENCE)
	for run_index in [0, 1]:
		assert_ne(runs[run_index].intro_sequence.sequence_id, &"catabase_intro_v4")


func test_legacy_intro_still_plays_for_expected_runs() -> void:
	for path in [
		"res://data/runs/first_run.tres",
		"res://data/runs/fixed_trio_prototype_run.tres",
	]:
		var run := load(path) as RunData
		assert_not_null(run.intro_sequence)
		assert_eq(run.intro_sequence.sequence_id, &"legacy_intro")
		assert_eq(run.intro_sequence.frames.size(), 9)
		assert_not_null(run.intro_sequence.narration_stream)


func test_retry_room_does_not_replay_intro() -> void:
	var spy := RunManagerSpyScript.new()
	spy.next_run_data = CATABASE_RUN
	add_child_autofree(spy)
	assert_true(spy.start_configured_run())
	assert_null(spy.peek_next_run_data())
	assert_eq(spy.start_call_count, 1)
	assert_false(spy.start_configured_run())
	assert_eq(spy.start_call_count, 1)


func test_new_catabase_launch_replays_intro() -> void:
	var spy := RunManagerSpyScript.new()
	add_child_autofree(spy)
	for expected_count in [1, 2]:
		spy.next_run_data = CATABASE_RUN
		assert_eq(spy.peek_next_run_data().intro_sequence, CATABASE_SEQUENCE)
		assert_true(spy.start_configured_run())
		assert_eq(spy.start_call_count, expected_count)


func test_catabase_room_one_contains_only_shadow_paris() -> void:
	var room := CATABASE_RUN.rooms[0]
	assert_eq(room.room_name, "Catabase I — L’Ombre de Paris")
	assert_eq(room.enemies.size(), 1)
	assert_eq(room.enemies[0].unit_id, &"catabase_shadow_paris")
	assert_eq(room.encounter_definition.get_initial_enemy_count(), 1)
	assert_eq(room.encounter_definition.living_enemy_cap, 1)
	assert_eq(room.encounter_definition.roster_units[0], room.enemies[0])


func test_shadow_paris_uses_dedicated_unit_and_spell_ids() -> void:
	var paris: UnitData = CATABASE_RUN.rooms[0].enemies[0]
	assert_eq(paris.unit_id, &"catabase_shadow_paris")
	assert_eq(paris.unit_name, "L’Ombre de Paris")
	assert_true(paris.description.contains("PLACEHOLDER_VISUAL"))
	assert_true(paris.description.contains("PLACEHOLDER_BALANCE"))
	assert_eq(paris.ai_behavior, EnemyAI.BEHAVIOR_RANGED)
	assert_true(paris.keep_distance)
	assert_eq(paris.spells.size(), 1)
	assert_eq(paris.spells[0].spell_id, &"catabase_shadow_paris_arrow")
	assert_false(String(paris.spells[0].spell_id).contains("skeleton"))
	assert_true(paris.spells[0].needs_line_of_sight)


func test_shadow_paris_has_a_counterable_telegraphed_intent_contract() -> void:
	var spell: Spell = CATABASE_RUN.rooms[0].enemies[0].spells[0]
	assert_eq(spell.delayed_resolution, Spell.DelayedResolution.RANGED_STRIKE)
	assert_true(spell.is_delayed())
	assert_true(spell.consumes_activation_on_resolution)
	assert_eq(spell.damage, 18)
	assert_true(spell.telegraph_label.contains("ligne de vue"))
	assert_null(spell.summon_unit_data)


func test_shadow_paris_trait_can_hit_or_be_broken_by_distance() -> void:
	var paris_data := load(
		"res://data/units/enemies/catabase_shadow_paris.tres"
	) as UnitData
	var spell := paris_data.spells[0]

	var hit_field := Factory.make_battlefield(10, 1)
	var paris := Unit.from_data(paris_data)
	var achilles := Unit.new("Achille", 0, 110)
	hit_field.grid.place_unit(paris, Vector2i(0, 0))
	hit_field.grid.place_unit(achilles, Vector2i(5, 0))
	paris.start_turn()
	var prepared := hit_field.caster.cast(paris, spell, achilles.grid_pos)
	assert_true(prepared.telegraphed)
	assert_eq(achilles.current_hp, 110)
	paris.start_turn()
	var resolved := hit_field.caster.resolve_pending_activation(paris)
	assert_true(resolved.resolved)
	assert_true(resolved.consume_activation)
	assert_eq(achilles.current_hp, 92)

	var escape_field := Factory.make_battlefield(10, 1)
	var second_paris := Unit.from_data(paris_data)
	var escaping_achilles := Unit.new("Achille", 0, 110)
	escape_field.grid.place_unit(second_paris, Vector2i(0, 0))
	escape_field.grid.place_unit(escaping_achilles, Vector2i(5, 0))
	second_paris.start_turn()
	var second_prepare := escape_field.caster.cast(
		second_paris,
		spell,
		escaping_achilles.grid_pos,
	)
	assert_true(second_prepare.telegraphed)
	assert_true(escape_field.grid.relocate_unit(escaping_achilles, Vector2i(8, 0)))
	second_paris.start_turn()
	var escaped := escape_field.caster.resolve_pending_activation(second_paris)
	assert_true(escaped.blocked)
	assert_eq(escaped.reason, &"target_escaped_telegraph")
	assert_eq(escaping_achilles.current_hp, 110)

	var cover_field := Factory.make_battlefield(10, 1)
	var third_paris := Unit.from_data(paris_data)
	var covered_achilles := Unit.new("Achille", 0, 110)
	cover_field.grid.place_unit(third_paris, Vector2i(0, 0))
	cover_field.grid.place_unit(covered_achilles, Vector2i(5, 0))
	third_paris.start_turn()
	var third_prepare := cover_field.caster.cast(
		third_paris,
		spell,
		covered_achilles.grid_pos,
	)
	assert_true(third_prepare.telegraphed)
	cover_field.grid.set_type(Vector2i(3, 0), GridData.CellType.WALL)
	third_paris.start_turn()
	var covered := cover_field.caster.resolve_pending_activation(third_paris)
	assert_true(covered.blocked)
	assert_true(covered.consume_activation)
	assert_eq(covered.reason, &"target_escaped_telegraph")
	assert_eq(covered_achilles.current_hp, 110)


func test_shadow_paris_warning_does_not_play_its_impact_vfx() -> void:
	var paris_data := load(
		"res://data/units/enemies/catabase_shadow_paris.tres"
	) as UnitData
	var paris := Unit.from_data(paris_data)
	paris.grid_pos = Vector2i(1, 1)
	var spell := paris_data.spells[0]
	var battle_root := Node2D.new()
	add_child_autofree(battle_root)
	var battle_view := FakeBattleView.new()
	battle_root.add_child(battle_view)
	var vfx_layer := Node2D.new()
	vfx_layer.name = "VFXLayer"
	battle_root.add_child(vfx_layer)
	VFXManager.register_battle_view(battle_view)
	VFXManager._on_spell_cast(paris, spell, {"cell": Vector2i(5, 1)})
	assert_eq(vfx_layer.get_child_count(), 0)
	assert_not_null(VFXManager.play_spell_vfx(paris, spell, Vector2i(5, 1)))
	assert_eq(vfx_layer.get_child_count(), 1)
	VFXManager.unregister_battle_view(battle_view)


func test_source_dimensions_are_preserved_and_known_mismatches_are_explicit() -> void:
	for index in range(CATABASE_SEQUENCE.frames.size()):
		var size := CATABASE_SEQUENCE.frames[index].texture.get_size()
		if index in [1, 3]:
			assert_eq(size, Vector2(1672.0, 941.0))
		else:
			assert_eq(size, Vector2(1920.0, 1080.0))


func _parse_ass_reference() -> Array[Dictionary]:
	var file := FileAccess.open(
		"res://cinematics/catabase/source/catabase_v4.ass",
		FileAccess.READ,
	)
	assert_not_null(file)
	var result: Array[Dictionary] = []
	while file != null and not file.eof_reached():
		var line := file.get_line()
		if not line.begins_with("Dialogue: "):
			continue
		var fields := line.trim_prefix("Dialogue: ").split(",", true, 9)
		assert_eq(fields.size(), 10)
		var tagged_text := fields[9]
		var close_tag := tagged_text.find("}")
		var clean_text := tagged_text.substr(close_tag + 1) if close_tag >= 0 else tagged_text
		var entry := {
			"layer": int(fields[0]),
			"start": _ass_time_to_seconds(fields[1]),
			"end": _ass_time_to_seconds(fields[2]),
			"style": fields[3],
			"text": clean_text.replace("\\N", "\n"),
			"fade_in": _tag_number(tagged_text, "fad", 0) / 1000.0,
			"fade_out": _tag_number(tagged_text, "fad", 1) / 1000.0,
		}
		var x := _tag_number(tagged_text, "pos", 0)
		var y := _tag_number(tagged_text, "pos", 1)
		if x >= 0.0 and y >= 0.0:
			entry.position = Vector2(x / 1920.0, y / 1080.0)
		result.append(entry)
	return result


func _ass_time_to_seconds(value: String) -> float:
	var parts := value.split(":")
	return float(parts[0]) * 3600.0 + float(parts[1]) * 60.0 + float(parts[2])


func _tag_number(tagged_text: String, tag: String, value_index: int) -> float:
	var expression := RegEx.new()
	assert_eq(expression.compile("\\\\%s\\((\\d+),(\\d+)\\)" % tag), OK)
	var matched := expression.search(tagged_text)
	if matched == null:
		return -1.0
	return float(matched.get_string(value_index + 1))
