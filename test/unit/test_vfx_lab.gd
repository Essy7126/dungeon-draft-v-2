extends GutTest

const LAB_SCENE := preload("res://tools/labs/vfx_lab/VFXLab.tscn")
const EFFECT_SCENES := [
	preload("res://tools/labs/vfx_lab/effects/FireballLabVFX.tscn"),
	preload("res://tools/labs/vfx_lab/effects/IceWallLabVFX.tscn"),
	preload("res://tools/labs/vfx_lab/effects/SeismicWaveLabVFX.tscn"),
	preload("res://tools/labs/vfx_lab/effects/ChargeLabVFX.tscn"),
	preload("res://tools/labs/vfx_lab/effects/GuardLabVFX.tscn"),
	preload("res://tools/labs/vfx_lab/effects/LightningStormLabVFX.tscn"),
]


func test_lab_loads_directly_and_exposes_six_replayable_effects() -> void:
	var lab: Node = LAB_SCENE.instantiate()
	add_child_autofree(lab)
	await get_tree().process_frame
	assert_eq(lab.get_effect_count(), 6)
	assert_not_null(lab.current_effect)
	var first: Node = lab.current_effect
	var replay: Node = lab.replay_effect()
	assert_not_null(replay)
	assert_ne(replay, first)
	lab.clear_effect()
	assert_null(lab.current_effect)
	assert_eq(lab.world.get_child_count(), 4, "Le stage ne garde que les quatre mannequins.")


func test_all_six_prototypes_instantiate_play_and_cleanup() -> void:
	for index in EFFECT_SCENES.size():
		var effect: Node = EFFECT_SCENES[index].instantiate()
		add_child(effect)
		var actor: Node2D = Node2D.new()
		add_child(actor)
		effect.play(_config_for(index, actor, 1337))
		assert_true(effect.active, "Prototype %d actif" % index)
		assert_gt(effect.get_visual_node_count(), 0, "Prototype %d compose plusieurs nodes" % index)
		effect.advance_simulation(0.16)
		effect.stop_and_clear()
		assert_false(effect.active)
		assert_eq(effect.get_visual_node_count(), 0, "Prototype %d nettoye ses composants" % index)
		effect.free()
		actor.free()


func test_twenty_successive_triggers_per_effect_do_not_accumulate_nodes() -> void:
	var lab: Node = LAB_SCENE.instantiate()
	add_child_autofree(lab)
	await get_tree().process_frame
	lab.clear_effect()
	for effect_index in lab.get_effect_count():
		for iteration in 20:
			var effect: Node = lab.play_effect(effect_index, 2000 + iteration)
			assert_not_null(effect)
			lab.clear_effect()
			assert_eq(lab.world.get_child_count(), 4)
	assert_null(lab.current_effect)


func test_seismic_wave_accepts_ordered_lists_of_multiple_lengths() -> void:
	for count in [1, 3, 7]:
		var effect: Node = EFFECT_SCENES[2].instantiate()
		add_child(effect)
		var positions: Array[Vector2] = []
		for index in count:
			positions.append(Vector2(index * 64.0, index * 18.0))
		effect.play({"seed": 77, "positions": positions, "propagation_speed": 0.1})
		assert_eq(effect._positions.size(), count)
		assert_true(effect.get_procedural_signature().contains(":%d:" % count))
		effect.stop_and_clear()
		effect.free()


func test_lightning_accepts_multiple_positions_and_individual_strike_control() -> void:
	var effect: Node = EFFECT_SCENES[5].instantiate()
	add_child(effect)
	effect.play({
		"seed": 912,
		"positions": [Vector2(-80.0, 0.0), Vector2.ZERO, Vector2(80.0, 0.0)],
		"strike_offsets": [4.0, 5.0, 6.0],
	})
	assert_eq(effect._positions.size(), 3)
	effect.strike_now(1)
	assert_false(effect._struck[0])
	assert_true(effect._struck[1])
	assert_false(effect._struck[2])
	assert_not_null(effect._bolts[1])
	effect.stop_and_clear()
	assert_eq(effect.get_visual_node_count(), 0)
	effect.free()


func test_guard_supports_visual_intensity_impact_and_cleanup() -> void:
	var effect: Node = EFFECT_SCENES[4].instantiate()
	add_child(effect)
	effect.play({"seed": 31, "target": Vector2.ZERO, "intensity": 1.4, "shield_opacity": 0.62})
	effect.trigger_impact(Vector2(18.0, -12.0))
	effect.advance_simulation(0.12)
	assert_gte(effect._impact_age, 0.0)
	assert_almost_eq(effect.intensity, 1.4, 0.001)
	effect.stop_and_clear()
	assert_eq(effect.get_visual_node_count(), 0)
	effect.free()


func test_same_seed_reproduces_structural_parameters() -> void:
	for effect_index in [1, 2]:
		var effect: Node = EFFECT_SCENES[effect_index].instantiate()
		add_child(effect)
		var config: Dictionary = _config_for(effect_index, null, 424242)
		effect.play(config)
		var first_signature: String = str(effect.get_procedural_signature())
		effect.play(config)
		var second_signature: String = str(effect.get_procedural_signature())
		assert_eq(second_signature, first_signature, "Seed stable pour effet %d" % effect_index)
		effect.stop_and_clear()
		effect.free()


func test_fireball_variants_are_seeded_distinct_and_replayable() -> void:
	var signatures: Array[String] = []
	for variant in [&"A", &"B", &"C"]:
		var effect: Node = EFFECT_SCENES[0].instantiate()
		add_child(effect)
		var config := {
			"seed": 424242,
			"variant": variant,
			"start": Vector2(-120.0, -20.0),
			"target": Vector2(140.0, 10.0),
		}
		effect.play(config)
		var first_signature: String = effect.get_procedural_signature()
		assert_eq(effect.variant_id, variant)
		assert_eq(effect.get_phase(), &"cast")
		effect.play(config)
		var replay_signature: String = effect.get_procedural_signature()
		assert_eq(replay_signature, first_signature, "Replay deterministe pour variante %s" % variant)
		effect.advance_simulation(0.40)
		assert_eq(effect.get_phase(), &"projectile")
		signatures.append(first_signature)
		effect.stop_and_clear()
		assert_eq(effect.get_visual_node_count(), 0)
		effect.free()
	assert_ne(signatures[0], signatures[1])
	assert_ne(signatures[1], signatures[2])
	assert_ne(signatures[0], signatures[2])


func test_twenty_play_clear_cycles_per_fireball_variant_leave_no_nodes() -> void:
	for variant in [&"A", &"B", &"C"]:
		var effect: Node = EFFECT_SCENES[0].instantiate()
		add_child(effect)
		for iteration in 20:
			effect.play({
				"seed": 8000 + iteration,
				"variant": variant,
				"start": Vector2(-120.0, -20.0),
				"target": Vector2(140.0, 10.0),
			})
			assert_true(effect.active)
			effect.advance_simulation(1.0 / 60.0)
			effect.stop_and_clear()
			assert_false(effect.active)
			assert_eq(effect.get_visual_node_count(), 0, "Residus %s iteration %d" % [variant, iteration])
		effect.free()


func test_effects_have_no_external_visual_asset_dependency_or_gameplay_authority() -> void:
	var effect_dir: DirAccess = DirAccess.open("res://tools/labs/vfx_lab/effects")
	assert_not_null(effect_dir)
	for file_name in effect_dir.get_files():
		if not file_name.ends_with(".tscn") and not file_name.ends_with(".gd"):
			continue
		var source: String = FileAccess.get_file_as_string(
			"res://tools/labs/vfx_lab/effects/" + file_name
		).to_lower()
		for extension in [".png", ".jpg", ".jpeg", ".webp", ".glb", ".fbx"]:
			assert_false(source.contains(extension), "%s ne reference pas %s" % [file_name, extension])
		if file_name.ends_with(".gd"):
			for forbidden in ["take_damage", "apply_damage", "spellcaster", "eventbus", "current_ap", "current_mp"]:
				assert_false(source.contains(forbidden), "%s sans autorite %s" % [file_name, forbidden])
	var fireball_dir: DirAccess = DirAccess.open("res://tools/labs/vfx_lab/effects/fireball")
	assert_not_null(fireball_dir)
	for file_name in fireball_dir.get_files():
		if not file_name.ends_with(".gd") and not file_name.ends_with(".gdshader"):
			continue
		var source := FileAccess.get_file_as_string(
			"res://tools/labs/vfx_lab/effects/fireball/" + file_name
		).to_lower()
		for extension in [".png", ".jpg", ".jpeg", ".webp", ".glb", ".fbx"]:
			assert_false(source.contains(extension), "%s ne reference pas %s" % [file_name, extension])


func test_natural_completion_releases_all_composed_visuals() -> void:
	for variant in [&"A", &"B", &"C"]:
		var effect: Node = EFFECT_SCENES[0].instantiate()
		add_child(effect)
		var config := _config_for(0, null, 14)
		config["variant"] = variant
		effect.play(config)
		effect.set_process(false)
		for _step in 240:
			effect.advance_simulation(1.0 / 60.0)
			if not effect.active:
				break
		assert_false(effect.active)
		assert_eq(effect.get_visual_node_count(), 0)
		effect.free()


func _config_for(index: int, actor: Node2D, seed: int) -> Dictionary:
	match index:
		0:
			return {"seed": seed, "start": Vector2(-120.0, -20.0), "target": Vector2(140.0, 10.0)}
		1:
			return {"seed": seed, "positions": [Vector2(-64.0, 0.0), Vector2.ZERO, Vector2(64.0, 0.0)]}
		2:
			return {"seed": seed, "positions": [Vector2(-96.0, 0.0), Vector2(-32.0, 16.0), Vector2(32.0, 32.0), Vector2(96.0, 48.0)]}
		3:
			return {"seed": seed, "actor": actor, "start": Vector2(-120.0, 0.0), "target": Vector2(140.0, 20.0)}
		4:
			return {"seed": seed, "target": Vector2.ZERO}
		5:
			return {"seed": seed, "positions": [Vector2(-70.0, 0.0), Vector2.ZERO, Vector2(70.0, 0.0)]}
	return {"seed": seed}
