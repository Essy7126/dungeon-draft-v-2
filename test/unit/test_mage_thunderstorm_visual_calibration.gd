extends GutTest

const Factory = preload("res://test/support/factory.gd")

const THUNDERSTORM_PATH := "res://data/spells/Mage/tempete_orageuse.tres"
const VFX_SCENE := preload(
	"res://asset/sorts/tempete_orageuse/tempete_orageuse_vfx.tscn"
)
const EXPECTED_VISUAL_SCALE := Vector2(0.72, 0.72)


func test_vfx_composition_is_centered_reduced_and_keeps_relative_art_direction() -> void:
	var vfx := VFX_SCENE.instantiate() as TempeteOrageuseVFX
	var visual_root := vfx.get_node("VisualRoot") as Node2D
	var ground := visual_root.get_node("GroundImpact") as Sprite2D
	var lightning := visual_root.get_node("LightningCluster") as Sprite2D
	var cloud := visual_root.get_node("StormCloud") as Sprite2D
	assert_eq(vfx.position, Vector2.ZERO)
	assert_eq(visual_root.position, Vector2.ZERO)
	assert_eq(visual_root.scale, EXPECTED_VISUAL_SCALE)
	assert_eq(ground.position, Vector2.ZERO)
	assert_eq(ground.scale, Vector2(0.12, 0.12))
	assert_eq(lightning.position, Vector2(0.0, -120.0))
	assert_eq(lightning.scale, Vector2(0.25, 0.25))
	assert_eq(cloud.position, Vector2(0.0, -260.0))
	assert_eq(cloud.scale, Vector2(0.18, 0.18))
	assert_eq([ground.z_index, lightning.z_index, cloud.z_index], [0, 1, 2])
	assert_true(ground.material is CanvasItemMaterial)
	assert_true(lightning.material is CanvasItemMaterial)
	assert_eq(
		(ground.material as CanvasItemMaterial).blend_mode,
		CanvasItemMaterial.BLEND_MODE_ADD,
	)
	assert_eq(
		(lightning.material as CanvasItemMaterial).blend_mode,
		CanvasItemMaterial.BLEND_MODE_ADD,
	)
	assert_null(cloud.material)
	vfx.free()


func test_cast_duration_tracks_and_watchdog_match_the_calibration_contract() -> void:
	var vfx := VFX_SCENE.instantiate() as TempeteOrageuseVFX
	var player := vfx.get_node("AnimationPlayer") as AnimationPlayer
	var animation := player.get_animation(&"cast")
	assert_not_null(animation)
	assert_almost_eq(animation.length, 1.15, 0.0001)
	assert_true(animation.length >= 1.149)
	assert_true(animation.length <= 1.201)
	assert_eq(animation.loop_mode, Animation.LOOP_NONE)
	for track_index in animation.get_track_count():
		assert_true(
			str(animation.track_get_path(track_index)).begins_with("VisualRoot/")
		)
	var lightning_track := animation.find_track(
		NodePath("VisualRoot/LightningCluster:modulate"),
		Animation.TYPE_VALUE,
	)
	assert_true(lightning_track >= 0)
	assert_eq(
		animation.value_track_get_update_mode(lightning_track),
		Animation.UPDATE_DISCRETE,
	)
	var constants: Dictionary = vfx.get_script().get_script_constant_map()
	assert_almost_eq(float(constants["IMPACT_TIME"]), 0.31, 0.0001)
	assert_almost_eq(float(constants["WATCHDOG_SECONDS"]), 1.8, 0.0001)
	assert_gt(float(constants["WATCHDOG_SECONDS"]), animation.length)
	vfx.free()


func test_visual_impact_stays_near_point_three_one_and_emits_exactly_once() -> void:
	var vfx := VFX_SCENE.instantiate() as TempeteOrageuseVFX
	var observed := {"count": 0, "elapsed": -1.0}
	var started_msec := Time.get_ticks_msec()
	vfx.impact_reached.connect(
		func():
			observed["count"] += 1
			observed["elapsed"] = (
				float(Time.get_ticks_msec() - started_msec) / 1000.0
			)
	)
	add_child(vfx)
	await vfx.impact_reached
	assert_eq(observed["count"], 1)
	assert_true(observed["elapsed"] >= 0.27)
	assert_true(observed["elapsed"] <= 0.42)
	await get_tree().create_timer(0.3).timeout
	assert_eq(observed["count"], 1)
	await vfx.tree_exited
	await get_tree().process_frame
	assert_false(is_instance_valid(vfx))


func test_two_successive_extended_casts_leave_no_active_instance() -> void:
	for _cast_index in 2:
		var vfx := VFX_SCENE.instantiate() as TempeteOrageuseVFX
		add_child(vfx)
		await vfx.tree_exited
		await get_tree().process_frame
		assert_true(
			get_tree().get_nodes_in_group(&"tempete_orageuse_vfx").is_empty()
		)


func test_gameplay_contract_remains_three_by_three_and_completely_unchanged() -> void:
	var spell := load(THUNDERSTORM_PATH) as Spell
	assert_eq([spell.ap_cost, spell.spell_range, spell.damage], [3, 5, 7])
	assert_almost_eq(spell.impact_delay_seconds, 0.31, 0.0001)
	assert_eq(spell.aoe_shape, Spell.AoeShape.SQUARE)
	assert_eq(spell.aoe_size, 1)
	var battlefield := Factory.make_battlefield(7, 7)
	var cells := battlefield.caster.get_aoe_cells(spell, Vector2i(3, 3))
	assert_eq(cells.size(), 9)
	assert_has(cells, Vector2i(2, 2))
	assert_has(cells, Vector2i(4, 4))
