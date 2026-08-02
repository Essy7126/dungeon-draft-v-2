class_name SkeletonCaptureValidation
extends Node2D

const ElfScene := preload("res://characters/elf/ElfIsoUnitView.tscn")
const MageScene := preload("res://characters/mage/MageIsoUnitView.tscn")
const WarriorScene := preload("res://characters/warrior/WarriorIsoUnitView.tscn")
const MeleeScene := preload(
	"res://characters/enemies/skeleton/SkeletonMeleeIsoUnitView.tscn"
)
const RangedScene := preload(
	"res://characters/enemies/skeleton/SkeletonRangedIsoUnitView.tscn"
)
const ProjectileScene := preload(
	"res://battle/vfx/skeleton_ranged_projectile_vfx.tscn"
)
const MovementTiming = preload("res://characters/character_movement_timing.gd")

const OUTPUT_DIR := "res://artifacts/skeleton_first_enemy"

var _elf: CharacterIsoUnitView
var _mage: CharacterIsoUnitView
var _warrior: CharacterIsoUnitView
var _melee_a: SkeletonIsoUnitView
var _melee_b: SkeletonIsoUnitView
var _ranged: SkeletonIsoUnitView
var _views: Array[Node2D] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_spawn_views()
	queue_redraw()
	await _wait_frames(12)
	await _capture_sequence()
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1200, 896)), Color(0.105, 0.12, 0.14))
	for y in range(250, 751, 80):
		for x in range(120, 1081, 128):
			var p := Vector2(x, y)
			draw_polyline(PackedVector2Array([
				p + Vector2(0, -24), p + Vector2(48, 0),
				p + Vector2(0, 24), p + Vector2(-48, 0),
				p + Vector2(0, -24),
			]), Color(0.20, 0.23, 0.25), 1.0)


func _spawn_views() -> void:
	_elf = _spawn(ElfScene, Vector2(170, 380)) as CharacterIsoUnitView
	_mage = _spawn(MageScene, Vector2(380, 380)) as CharacterIsoUnitView
	_warrior = _spawn(WarriorScene, Vector2(590, 380)) as CharacterIsoUnitView
	_melee_a = _spawn(MeleeScene, Vector2(800, 380)) as SkeletonIsoUnitView
	_melee_b = _spawn(MeleeScene, Vector2(900, 570)) as SkeletonIsoUnitView
	_ranged = _spawn(RangedScene, Vector2(1030, 570)) as SkeletonIsoUnitView


func _spawn(scene: PackedScene, at: Vector2) -> Node2D:
	var view := scene.instantiate() as Node2D
	add_child(view)
	view.position = at
	_views.append(view)
	return view


func _capture_sequence() -> void:
	_show_only([_melee_a])
	_center(_melee_a)
	await _wait_frames(4)
	_save("skeleton_melee_idle_iso.png")

	_show_only([_ranged])
	_center(_ranged)
	await _wait_frames(4)
	_save("skeleton_ranged_idle_iso.png")

	_show_only([_melee_a])
	_center(_melee_a)
	_melee_a.play_basic_attack()
	await get_tree().create_timer(0.31).timeout
	_save("skeleton_melee_attack_iso.png")
	await get_tree().create_timer(1.05).timeout

	_show_only([_ranged])
	_center(_ranged)
	_ranged.play_spell_action(Spell.new())
	await get_tree().create_timer(1.22).timeout
	_save("skeleton_ranged_release_iso.png")
	await get_tree().create_timer(0.35).timeout

	_show_only([])
	var projectile := ProjectileScene.instantiate() as SkeletonRangedProjectileVFX
	add_child(projectile)
	projectile.travel_duration = 0.50
	projectile.initialiser(Vector2(390, 448), Vector2(810, 420))
	await get_tree().create_timer(0.24).timeout
	_save("skeleton_ranged_projectile.png")
	await get_tree().create_timer(0.30).timeout

	_show_only([_melee_a])
	_center(_melee_a)
	_melee_a.play_hit()
	await get_tree().create_timer(0.28).timeout
	_save("skeleton_hit.png")
	await get_tree().create_timer(0.45).timeout

	_melee_a.play_death()
	await get_tree().create_timer(1.55).timeout
	_save("skeleton_death.png")

	_show_only([_melee_a, _ranged])
	_melee_a.position = Vector2(520, 370)
	_ranged.position = Vector2(680, 520)
	_save("skeleton_y_sort_front.png")
	_melee_a.position = Vector2(680, 520)
	_ranged.position = Vector2(520, 370)
	_save("skeleton_y_sort_back.png")

	_show_only(_views)
	_elf.position = Vector2(160, 360)
	_mage.position = Vector2(360, 360)
	_warrior.position = Vector2(560, 360)
	_melee_a.position = Vector2(720, 560)
	_melee_b.position = Vector2(880, 560)
	_ranged.position = Vector2(1040, 560)
	await _wait_frames(6)
	_save("trio_vs_three_skeletons.png")
	_save("run_room_three_skeletons.png")
	_save("no_goblin_no_dummy.png")

	_show_only([_elf, _mage, _warrior])
	_elf.position = Vector2(270, 500)
	_mage.position = Vector2(600, 500)
	_warrior.position = Vector2(930, 500)
	_play_shared_walk(_elf)
	_play_shared_walk(_mage)
	_play_shared_walk(_warrior)
	await get_tree().create_timer(0.35).timeout
	_save("movement_pacing_comparison.png")


func _play_shared_walk(view: CharacterIsoUnitView) -> void:
	var visual := view.get_character_visual()
	var source_duration := visual.get_animation_length_for_action(CharacterVisual3D.ACTION_WALK)
	view.play_walk(MovementTiming.playback_speed_for_loop(source_duration, false))


func _show_only(visible_views: Array) -> void:
	for view in _views:
		view.visible = view in visible_views


func _center(view: Node2D) -> void:
	view.position = Vector2(600, 560)


func _save(file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image == null:
		push_warning("Capture indisponible avec le renderer headless/dummy: %s" % path)
		return
	var error := image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURE ", path, " error=", error, " size=", image.get_size())


func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
