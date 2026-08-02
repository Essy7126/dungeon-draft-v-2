extends GutTest

const MAGE_DATA_PATH := "res://data/units/alliés/mage.tres"
const MAGE_VISUAL_SCENE := preload("res://characters/mage/MageVisual3D.tscn")
const MAGE_ISO_SCENE := preload("res://characters/mage/MageIsoUnitView.tscn")
const ELF_VISUAL_SCENE := preload("res://characters/elf/ElfVisual3D.tscn")
const ELF_ISO_SCENE := preload("res://characters/elf/ElfIsoUnitView.tscn")
const EXPECTED_MAGE_VISUAL_SCALE := Vector3(1.2, 1.2, 1.2)
const EXPECTED_ANIMATIONS := [
	"DD_Mage_Cast",
	"DD_Mage_Death",
	"DD_Mage_Hit",
	"DD_Mage_Idle",
	"DD_Mage_Run",
	"DD_Mage_Walk",
]

var visual: MageVisual3D


func before_each() -> void:
	visual = MAGE_VISUAL_SCENE.instantiate() as MageVisual3D
	add_child_autofree(visual)
	await wait_process_frames(2)


func test_lab_provenance_keeps_only_validated_assets_in_production() -> void:
	var files := Array(DirAccess.get_files_at("res://assets/characters/mage"))
	for expected in [
		"mage_godot_baseline.glb",
		"mage_godot_baseline.glb.import",
		"mage_godot_baseline_texture_0.png",
		"mage_godot_baseline_texture_0.png.import",
	]:
		assert_has(files, expected)
	assert_eq(files.filter(
		func(file_name): return str(file_name).begins_with("mage_godot_baseline")
	).size(), 4)
	assert_false(DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path("res://tests/characters/mage")
	))
	assert_false(FileAccess.file_exists(
		"res://tests/characters/mage/MageAnimationValidation.tscn"
	))
	assert_false(FileAccess.file_exists(
		"res://tests/characters/mage/mage_animation_validation.gd"
	))
	assert_false(FileAccess.file_exists(
		"res://tests/characters/mage/mage_import_audit.gd"
	))


func test_profile_maps_six_exact_animations_and_never_defines_attack() -> void:
	assert_true(visual is CharacterVisual3D)
	var player := visual.get_animation_player()
	assert_not_null(player)
	var names: Array[String] = []
	for animation_name in player.get_animation_list():
		names.append(str(animation_name))
	names.sort()
	assert_eq(names, EXPECTED_ANIMATIONS)
	assert_false(player.has_animation(&"DD_Mage_Attack"))
	assert_false(player.has_animation(&"Attack"))
	assert_false(visual.has_method("play_attack"))
	assert_eq(visual.animation_idle, MageVisual3D.ANIM_IDLE)
	assert_eq(visual.animation_walk, MageVisual3D.ANIM_WALK)
	assert_eq(visual.animation_run, MageVisual3D.ANIM_RUN)
	assert_eq(visual.animation_cast, MageVisual3D.ANIM_CAST)
	assert_eq(visual.animation_hit, MageVisual3D.ANIM_HIT)
	assert_eq(visual.animation_death, MageVisual3D.ANIM_DEATH)


func test_mage_scale_is_uniform_profile_specific_and_keeps_elf_unchanged() -> void:
	assert_eq(visual.scale, EXPECTED_MAGE_VISUAL_SCALE)
	assert_eq(visual.position, Vector3.ZERO)
	var mage_iso := MAGE_ISO_SCENE.instantiate() as MageIsoUnitView
	var elf_iso := ELF_ISO_SCENE.instantiate() as ElfIsoUnitView
	var elf_visual := ELF_VISUAL_SCENE.instantiate() as ElfVisual3D
	add_child_autofree(mage_iso)
	add_child_autofree(elf_iso)
	add_child_autofree(elf_visual)
	await wait_process_frames(2)
	assert_almost_eq(mage_iso.character_scale, 1.10, 0.0001)
	assert_eq(mage_iso.character_pivot.scale, Vector3(1.1, 1.1, 1.1))
	assert_eq(mage_iso.render_offset_adjustment, Vector2.ZERO)
	assert_almost_eq(mage_iso.camera_orthographic_size, 2.75, 0.0001)
	assert_almost_eq(mage_iso.camera_look_at_height, 0.85, 0.0001)
	assert_eq(mage_iso.get_mage_visual().scale, EXPECTED_MAGE_VISUAL_SCALE)
	assert_eq(mage_iso.get_mage_visual().position, Vector3.ZERO)
	assert_almost_eq(elf_iso.character_scale, 1.10, 0.0001)
	assert_eq(elf_iso.character_pivot.scale, Vector3(1.1, 1.1, 1.1))
	assert_eq(elf_iso.render_offset_adjustment, Vector2.ZERO)
	assert_almost_eq(elf_iso.camera_orthographic_size, 2.220395, 0.0001)
	assert_eq(elf_visual.scale, Vector3.ONE)


func test_cast_release_is_absolute_exact_and_emitted_once() -> void:
	var release := {"count": 0}
	visual.cast_release_reached.connect(func(): release["count"] += 1)
	var player := visual.get_animation_player()
	assert_true(visual.play_cast_full())
	player.advance(0.0)
	player.seek(0.90, true)
	visual._process(0.0)
	assert_eq(release["count"], 0)
	player.seek(MageVisual3D.CAST_RELEASE_TIME, true)
	visual._process(0.0)
	assert_eq(release["count"], 1)
	player.seek(1.6, true)
	visual._process(0.0)
	assert_eq(release["count"], 1)


func test_interrupted_or_dead_cast_cannot_release_late() -> void:
	var release := {"count": 0}
	visual.cast_release_reached.connect(func(): release["count"] += 1)
	var player := visual.get_animation_player()
	assert_true(visual.play_cast_full())
	player.advance(0.0)
	player.seek(0.4, true)
	visual._process(0.0)
	assert_true(visual.play_death())
	player.advance(0.0)
	player.seek(1.2, true)
	visual._process(0.0)
	assert_eq(release["count"], 0)
	visual._on_player_animation_finished(MageVisual3D.ANIM_DEATH)
	assert_eq(visual.get_current_animation(), MageVisual3D.ANIM_DEATH)


func test_projectile_mount_is_bound_to_the_runtime_right_hand() -> void:
	var mount := visual.get_projectile_mount()
	assert_not_null(mount)
	assert_eq(mount.name, &"ProjectileMount")
	assert_true(mount.get_parent() is BoneAttachment3D)
	assert_eq((mount.get_parent() as BoneAttachment3D).bone_name, "RightHand")
	assert_same(visual.get_default_cast_mount(), mount)
	assert_not_null(visual.get_cast_support_mount())
	assert_eq(
		(visual.get_cast_support_mount().get_parent() as BoneAttachment3D).bone_name,
		"LeftHand",
	)


func test_mage_iso_view_uses_an_isolated_transparent_world_and_real_profile() -> void:
	var iso := MAGE_ISO_SCENE.instantiate() as MageIsoUnitView
	add_child_autofree(iso)
	await wait_process_frames(2)
	assert_true(iso is CharacterIsoUnitView)
	assert_true(iso.character_viewport.own_world_3d)
	assert_true(iso.character_viewport.transparent_bg)
	assert_true(iso.character_viewport.gui_disable_input)
	assert_eq(iso.character_viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	assert_true(iso.get_mage_visual() is MageVisual3D)
	assert_eq(iso.character_pivot.get_child_count(), 1)
	assert_same(
		iso.get_mage_visual().get_default_cast_mount(),
		iso.get_mage_visual().get_projectile_mount(),
	)


func test_unit_view_projects_the_runtime_projectile_mount_as_cast_origin() -> void:
	var unit := Unit.from_data(load(MAGE_DATA_PATH) as UnitData)
	var unit_view = load("res://battle/unit_view.tscn").instantiate()
	add_child_autofree(unit_view)
	unit_view.setup(unit)
	await wait_process_frames(2)
	var iso := unit_view.get_optional_visual() as MageIsoUnitView
	assert_not_null(iso)
	var mount := iso.get_mage_visual().get_projectile_mount()
	var viewport_pixel := iso.camera.unproject_position(mount.global_position)
	var expected_local := iso.to_local(iso.render_sprite.to_global(viewport_pixel))
	assert_eq(
		unit_view.get_cast_effect_origin_global(),
		iso.to_global(expected_local),
	)


func test_mage_unit_data_uses_profile_and_disables_basic_attack() -> void:
	var data := load(MAGE_DATA_PATH) as UnitData
	assert_eq(data.unit_id, &"mage")
	assert_false(data.basic_attack_enabled)
	assert_eq(
		data.disciplines.map(func(discipline): return discipline.discipline_id),
		[&"mage_pyromancy", &"mage_cryomancy", &"mage_fulguromancy", &"mage_geomancy"],
	)
	assert_eq(data.visual_scene.resource_path, "res://characters/mage/MageIsoUnitView.tscn")
	assert_eq(data.preview_visual_scene.resource_path, "res://characters/mage/MageVisual3D.tscn")
	assert_eq(data.spells.size(), 4)
	assert_true(data.spells.any(func(spell): return spell.damage > 0))
	assert_eq(
		data.spells.map(func(spell): return spell.discipline_id),
		[&"mage_pyromancy", &"mage_cryomancy", &"mage_fulguromancy", &"mage_geomancy"],
	)
	assert_true(data.spells.all(func(spell): return spell.get_effective_spell_id() != &""))
	assert_false(data.spells.any(
		func(spell): return spell.get_effective_spell_id() == &"elf_fireball"
	))
