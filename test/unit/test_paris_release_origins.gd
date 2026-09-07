extends GutTest

const Factory := preload("res://test/support/factory.gd")
const MANAGER := preload("res://core/vfx_manager.gd")
const UNIT_PATH := "res://data/units/enemies/catabase_shadow_paris.tres"
const SPECTRAL_ACTIONS := [
	["spectral_arrow", Vector2(381, 190), Vector2(367, 157), 7, 6],
	["fire_arrow", Vector2(381, 190), Vector2(367, 157), 7, 6],
	["ice_arrow", Vector2(381, 190), Vector2(367, 157), 7, 6],
	["vortex_arrow", Vector2(242, 181), Vector2(334, 246), 9, 10],
	["vortex_step", Vector2(242, 181), Vector2(334, 246), 9, 10],
]
const INFERNAL_ACTIONS := [
	["infernal_whip", Vector2(388, 153), Vector2(390, 161), 7, 7],
	["infernal_sweep", Vector2(356, 170), Vector2(355, 117), 9, 10],
	["infernal_pull", Vector2(173, 201), Vector2(176, 219), 9, 10],
	["vortex_step", Vector2(356, 170), Vector2(355, 117), 9, 10],
]


class GridView extends Node2D:
	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 64, (cell.x + cell.y) * 32)


func test_every_spell_release_uses_measured_hand_and_matching_native_or_mirrored_pose() -> void:
	var fixture := _fixture()
	var body: ParisIsoUnitView = fixture.body
	for form: StringName in [&"spectral", &"infernal"]:
		if form == &"infernal":
			(fixture.unit as Unit).take_damage(97)
			body.advance_simulation(0.9)
		var cases: Array = SPECTRAL_ACTIONS if form == &"spectral" else INFERNAL_ACTIONS
		for direction: String in ["E", "N", "S", "W"]:
			body.set_facing_label(direction)
			var front := direction in ["E", "S"]
			for item: Array in cases:
				var spell := _spell(item[0])
				assert_true(body.play_spell_action(spell))
				body.advance_simulation(body.sprite_profile.duration_for(body.get_spell_animation_stem(spell)) * 0.5)
				var point: Vector2 = item[1] if front else item[2]
				var expected := (point - Vector2(256, 320)) * 0.35
				if direction in ["S", "W"]:
					expected.x = -expected.x
				assert_true(body.get_visual_runtime_state().release_emitted)
				assert_almost_eq(body.get_default_cast_effect_origin(), expected, Vector2(0.001, 0.001))
				assert_almost_eq(fixture.wrapper.get_cast_effect_origin_global(), body.to_global(expected), Vector2(0.001, 0.001))
				var atlas := body.animated_sprite.sprite_frames.get_frame_texture(body.animated_sprite.animation, body.animated_sprite.frame) as AtlasTexture
				var index: int = item[3] if front else item[4]
				assert_eq(atlas.region, Rect2((index % 4) * 512, (index / 4) * 384, 512, 384))
				assert_true(atlas.atlas.resource_path.ends_with("atlas_%s_%s.png" % [form, "E" if front else "N"]))
				assert_eq(body.animated_sprite.flip_h, direction in ["S", "W"])
				body.cancel_pending_visual_actions()


func test_slow_frame_arrow_starts_at_captured_release_before_queued_facing_and_keeps_origin_at_impact() -> void:
	var fixture := _fixture()
	var body: ParisIsoUnitView = fixture.body
	var spell := _spell("vortex_arrow")
	body.set_facing_label("E")
	var expected := body.to_global(Vector2(-4.9, -48.65))
	var context: CastContext = fixture.field.caster.begin_cast(fixture.unit, spell, fixture.target.grid_pos)
	assert_false(context.failed)
	assert_true(body.play_spell_action(spell))
	body.set_facing_label("N")
	body.advance_simulation(2.0)
	assert_eq(body.get_visual_runtime_state().stem, "idle")
	assert_eq(body.get_visual_runtime_state().facing, "N")
	var effect: Node = fixture.manager.play_spell_vfx(fixture.unit, spell, fixture.target.grid_pos)
	assert_not_null(effect)
	assert_almost_eq(effect.get_debug_state().origin, expected, Vector2(0.001, 0.001))
	assert_almost_eq(effect._sprites[0].global_position, expected, Vector2(0.001, 0.001))
	assert_null(body.consume_spell_release_origin(spell), "The launch consumed its snapshot once")
	var report: Dictionary = fixture.field.caster.resolve_cast(context)
	assert_false(report.get("failed", false))
	assert_eq(effect.get_debug_state().phase, &"impact")
	assert_almost_eq(effect.get_debug_state().origin, expected, Vector2(0.001, 0.001))
	fixture.manager.unregister_battle_view()


func test_infernal_pull_resolving_after_recovery_uses_the_low_whip_hand() -> void:
	var fixture := _fixture()
	var body: ParisIsoUnitView = fixture.body
	(fixture.unit as Unit).take_damage(97)
	body.advance_simulation(0.9)
	body.set_facing_label("E")
	var expected := body.to_global(Vector2(-29.05, -41.65))
	var spell := _spell("infernal_pull")
	var original_cell: Vector2i = fixture.target.grid_pos
	var context: CastContext = fixture.field.caster.begin_cast(fixture.unit, spell, original_cell)
	assert_false(context.failed)
	assert_true(body.play_spell_action(spell))
	body.set_facing_label("W")
	body.advance_simulation(2.0)
	assert_eq(body.get_visual_runtime_state().stem, "idle")
	var report: Dictionary = fixture.field.caster.resolve_cast(context)
	assert_false(report.get("failed", false))
	assert_ne(fixture.target.grid_pos, original_cell)
	var effect: Node = fixture.manager._paris_router.effects[0]
	assert_eq(effect.get_debug_state().animation, &"whip")
	assert_almost_eq(effect.get_debug_state().origin, expected, Vector2(0.001, 0.001))
	assert_almost_eq(effect._sprites[0].global_position, expected.lerp(fixture.manager._impact_cell_position(original_cell), 0.5), Vector2(0.001, 0.001))
	assert_null(body.consume_spell_release_origin(spell))
	fixture.manager.unregister_battle_view()


func test_cancellation_and_a_new_action_discard_the_previous_release_snapshot() -> void:
	var fixture := _fixture()
	var body: ParisIsoUnitView = fixture.body
	var first := _spell("vortex_arrow")
	assert_true(body.play_spell_action(first))
	body.advance_simulation(0.38)
	body.cancel_pending_visual_actions()
	assert_null(body.consume_spell_release_origin(first))
	assert_true(body.play_spell_action(first))
	body.advance_simulation(1.0)
	assert_true(body.play_spell_action(_spell("fire_arrow")))
	assert_null(body.consume_spell_release_origin(first))
	body.cancel_pending_visual_actions()
	fixture.manager.unregister_battle_view()


func _spell(stem: String) -> Spell:
	return load("res://data/spells/enemies/paris/%s.tres" % stem) as Spell


func _fixture() -> Dictionary:
	var field := Factory.make_battlefield(10, 7)
	var unit := Unit.from_data(load(UNIT_PATH) as UnitData)
	var target := Factory.make_unit("Cible", 0)
	field.grid.place_unit(unit, Vector2i(1, 2))
	field.grid.place_unit(target, Vector2i(4, 2))
	var grid_view := GridView.new()
	grid_view.position = Vector2(210, 170)
	grid_view.scale = Vector2.ONE * 0.85
	add_child_autofree(grid_view)
	var wrapper := (load("res://battle/unit_view.gd") as Script).new() as Node2D
	grid_view.add_child(wrapper)
	wrapper.setup(unit, false)
	wrapper.position = grid_view.grid_to_local(unit.grid_pos)
	wrapper.apply_painted_presentation(BattlePresentationProfile.new())
	var body := wrapper.get_optional_visual() as ParisIsoUnitView
	body.set_process(false)
	var manager := MANAGER.new()
	add_child_autofree(manager)
	manager.register_battle_view(grid_view)
	return {"unit": unit, "target": target, "field": field, "body": body, "wrapper": wrapper, "manager": manager}
