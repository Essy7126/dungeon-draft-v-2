extends Node2D

const REPORT_PATH := "C:/Blender_AI_Test/Output/skeleton_chief_iso_capture_report.json"
const ARTIFACT_DIR := "res://artifacts/skeleton_chief"
const ChiefScene := preload(
	"res://characters/enemies/skeleton_chief/SkeletonChiefIsoUnitView.tscn"
)
const SkeletonScene := preload(
	"res://characters/enemies/skeleton/SkeletonMeleeIsoUnitView.tscn"
)
const ElfScene := preload("res://characters/elf/ElfIsoUnitView.tscn")
const MageScene := preload("res://characters/mage/MageIsoUnitView.tscn")
const WarriorScene := preload("res://characters/warrior/WarriorIsoUnitView.tscn")

var _errors: Array[String] = []
var _captures := {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	RenderingServer.set_default_clear_color(Color(0.075, 0.085, 0.105, 1.0))
	var chief := ChiefScene.instantiate() as SkeletonChiefIsoUnitView
	chief.position = Vector2(640, 510)
	add_child(chief)
	var standard := SkeletonScene.instantiate() as SkeletonIsoUnitView
	standard.position = Vector2(360, 510)
	add_child(standard)
	await _frames(6)

	var chief_idle_bounds := _capture_subviewport(chief, "skeleton_chief_iso_idle.png")
	var standard_bounds := _opaque_bounds(standard.character_viewport.get_texture().get_image())
	var height_ratio := (
		float(chief_idle_bounds.size.y) / float(maxi(standard_bounds.size.y, 1))
	)
	if height_ratio < 1.08 or height_ratio > 1.17:
		_errors.append("Chief/standard visible height ratio %.4f is outside the calibrated 1.08-1.17 tolerance" % height_ratio)

	chief.play_walk(1.190476)
	await get_tree().create_timer(0.34).timeout
	_capture_subviewport(chief, "skeleton_chief_iso_walk.png")
	chief.play_basic_attack()
	await get_tree().create_timer(0.76).timeout
	_capture_subviewport(chief, "skeleton_chief_iso_attack.png")
	chief.play_hit()
	await get_tree().create_timer(0.34).timeout
	_capture_subviewport(chief, "skeleton_chief_iso_hit.png")
	chief.play_death()
	await get_tree().create_timer(2.05).timeout
	var death_bounds := _capture_subviewport(chief, "skeleton_chief_iso_death.png")
	if death_bounds.position.x <= 1 or death_bounds.position.y <= 1 \
			or death_bounds.end.x >= chief.viewport_size.x - 1 \
			or death_bounds.end.y >= chief.viewport_size.y - 1:
		_errors.append("Death touches the SubViewport border: %s" % str(death_bounds))

	chief.queue_free()
	standard.queue_free()
	await _frames(4)
	await _capture_composites()

	var report := {
		"passed": _errors.is_empty(),
		"errors": _errors,
		"chief_idle_bounds": _rect_to_dictionary(chief_idle_bounds),
		"standard_idle_bounds": _rect_to_dictionary(standard_bounds),
		"chief_to_standard_height_ratio": height_ratio,
		"chief_viewport_fill_ratio": float(chief_idle_bounds.size.y) / 512.0,
		"death_bounds": _rect_to_dictionary(death_bounds),
		"captures": _captures,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("SKELETON_CHIEF_CAPTURE=", JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 3)


func _capture_composites() -> void:
	var y_standard := SkeletonScene.instantiate() as SkeletonIsoUnitView
	var y_chief := ChiefScene.instantiate() as SkeletonChiefIsoUnitView
	y_standard.position = Vector2(565, 410)
	y_chief.position = Vector2(690, 495)
	add_child(y_standard)
	add_child(y_chief)
	await _frames(6)
	_save_main_viewport("skeleton_chief_y_sort.png")
	y_standard.queue_free()
	y_chief.queue_free()
	await _frames(3)

	var elf = ElfScene.instantiate()
	var mage = MageScene.instantiate()
	var warrior = WarriorScene.instantiate()
	var chief = ChiefScene.instantiate()
	var nodes := [elf, mage, warrior, chief]
	var positions := [Vector2(350, 500), Vector2(550, 500), Vector2(750, 500), Vector2(980, 500)]
	for index in nodes.size():
		nodes[index].position = positions[index]
		add_child(nodes[index])
	await _frames(7)
	_save_main_viewport("trio_vs_skeleton_chief.png")
	for node in nodes:
		node.queue_free()
	await _frames(3)


func _capture_subviewport(iso: CharacterIsoUnitView, filename: String) -> Rect2i:
	var image := iso.character_viewport.get_texture().get_image()
	var path := ARTIFACT_DIR.path_join(filename)
	var error := image.save_png(path)
	if error != OK:
		_errors.append("Unable to save %s: %s" % [path, error_string(error)])
	_captures[filename] = {"path": path, "size": [image.get_width(), image.get_height()]}
	return _opaque_bounds(image)


func _save_main_viewport(filename: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := ARTIFACT_DIR.path_join(filename)
	var error := image.save_png(path)
	if error != OK:
		_errors.append("Unable to save %s: %s" % [path, error_string(error)])
	_captures[filename] = {"path": path, "size": [image.get_width(), image.get_height()]}


func _opaque_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.02:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _rect_to_dictionary(rect: Rect2i) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
