extends GutTest

const WarriorVisualScene := preload("res://characters/warrior/WarriorVisual3D.tscn")
const WarriorIsoScene := preload("res://characters/warrior/WarriorIsoUnitView.tscn")
const ImportValidationScene := preload("res://tests/characters/warrior/WarriorImportValidation.tscn")
const UnitViewScript := preload("res://battle/unit_view.gd")
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const GUARDIAN_PATH := "res://data/units/alliés/Gardien.tres"


class BasicAttackSpy extends Node2D:
	var call_count := 0

	func play_basic_attack() -> bool:
		call_count += 1
		return true


func test_import_has_expected_skin_skeleton_mesh_and_animations() -> void:
	var validation := ImportValidationScene.instantiate() as WarriorImportValidation
	add_child_autofree(validation)
	await wait_process_frames(3)
	var report := validation.run_validation()
	assert_true(report.passed, str(report.errors))
	assert_eq(report.bone_count, 24)
	assert_eq(report.mesh_triangles, 92780)
	assert_true(report.has_skin)
	assert_eq(report.animations.size(), 9)


func test_warrior_resource_is_data_driven_and_preserves_gameplay() -> void:
	var warrior := load(WARRIOR_PATH) as UnitData
	assert_not_null(warrior)
	assert_eq(warrior.unit_id, &"warrior")
	assert_eq(warrior.unit_name, "Guerrier")
	assert_eq(warrior.attack_power, 18)
	assert_eq(warrior.force, 20.0)
	assert_eq(warrior.max_ap, 6)
	assert_eq(warrior.max_mp, 3)
	assert_null(warrior.energy_type)
	assert_null(warrior.chassis_trait)
	assert_eq(warrior.active_spell_slots, 8)
	assert_eq(warrior.spells.size(), 8)
	assert_eq(warrior.disciplines.size(), 3)
	assert_not_null(warrior.visual_scene)
	assert_not_null(warrior.preview_visual_scene)
	assert_not_null(load(GUARDIAN_PATH) as UnitData)


func test_visual_reuses_shared_class_and_builds_real_hand_sockets() -> void:
	var visual := WarriorVisualScene.instantiate() as WarriorVisual3D
	add_child_autofree(visual)
	await wait_process_frames(3)
	assert_true(visual is CharacterVisual3D)
	assert_not_null(visual.get_animation_player())
	for animation_name in WarriorVisual3D.IMPORTED_ANIMATIONS:
		assert_true(visual.get_animation_player().has_animation(animation_name), str(animation_name))
	assert_eq(visual.get_skeleton().get_bone_count(), 24)
	assert_true(visual.get_skeleton().find_bone("LeftHand") >= 0)
	assert_true(visual.get_skeleton().find_bone("RightHand") >= 0)
	assert_not_null(visual.get_left_weapon_mount())
	assert_not_null(visual.get_right_weapon_mount())
	assert_not_null(visual.get_default_effect_mount())


func test_iso_reuses_shared_class_has_sharp_viewport_and_four_root_stable_facings() -> void:
	var iso := WarriorIsoScene.instantiate() as WarriorIsoUnitView
	add_child_autofree(iso)
	await wait_process_frames(3)
	assert_true(iso is CharacterIsoUnitView)
	assert_eq(iso.viewport_size, Vector2i(768, 512))
	assert_eq(iso.character_viewport.msaa_3d, Viewport.MSAA_4X)
	assert_false(iso.character_viewport.use_taa)
	assert_eq(iso.character_viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_eq(iso.character_scale, 1.2)
	assert_eq(iso.get_logical_foot_position(), Vector2.ZERO)
	var root_position := iso.position
	var pivot_position := iso.character_pivot.position
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		iso.set_facing(direction)
		assert_eq(iso.get_facing_direction(), direction)
		assert_eq(iso.position, root_position)
		assert_eq(iso.character_pivot.position, pivot_position)


func test_spell_profile_uses_stable_ids_and_emits_one_release() -> void:
	var visual := WarriorVisualScene.instantiate() as WarriorVisual3D
	add_child_autofree(visual)
	await wait_process_frames(3)
	var parry_spell := load("res://data/spells/Guerrier/crochet.tres") as Spell
	assert_eq(parry_spell.spell_id, &"warrior_hook")
	assert_eq(visual.get_animation_for_spell(parry_spell), WarriorVisual3D.ANIM_PARRY)
	var releases := {"count": 0}
	visual.cast_release_reached.connect(func(): releases.count += 1)
	assert_true(visual.play_spell_action(parry_spell))
	await get_tree().create_timer(0.45).timeout
	assert_eq(releases.count, 1)


func test_unit_view_basic_attack_calls_optional_visual_once_and_keeps_sprite_path() -> void:
	var view := UnitViewScript.new()
	add_child_autofree(view)
	var frames := SpriteFrames.new()
	frames.add_animation(&"attack")
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	frames.add_frame(&"attack", ImageTexture.create_from_image(image))
	var data := UnitData.new()
	data.unit_name = "Basic attack test"
	data.sprite_frames = frames
	var unit := Unit.from_data(data)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	view.add_child(sprite)
	var spy := BasicAttackSpy.new()
	view.add_child(spy)
	view.set("unit", unit)
	view.set("_sprite", sprite)
	view.set("_optional_visual", spy)
	view.call("_on_attack_performed", unit, null)
	assert_eq(spy.call_count, 1)
	assert_eq(sprite.animation, &"attack")
	unit.clear_traits()


func test_death_is_locked_emits_once_and_never_returns_to_idle() -> void:
	var visual := WarriorVisualScene.instantiate() as WarriorVisual3D
	add_child_autofree(visual)
	await wait_process_frames(3)
	var finished := {"count": 0}
	visual.death_animation_finished.connect(func(): finished.count += 1)
	assert_true(visual.play_death())
	assert_false(visual.play_death())
	await get_tree().create_timer(1.65).timeout
	assert_eq(finished.count, 1)
	assert_true(visual.is_death_locked())
	assert_ne(visual.get_current_animation(), WarriorVisual3D.ANIM_IDLE)
