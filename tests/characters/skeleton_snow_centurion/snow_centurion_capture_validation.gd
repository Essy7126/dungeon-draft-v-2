extends Node2D

const REPORT_PATH := "C:/Blender_AI_Test/Output/snow_centurion_iso_capture_report.json"
const ARTIFACT_DIR := "res://artifacts/skeleton_snow_centurion"
const SnowScene := preload(
	"res://characters/enemies/skeleton_snow_centurion/SnowCenturionIsoUnitView.tscn"
)
const ChiefScene := preload(
	"res://characters/enemies/skeleton_chief/SkeletonChiefIsoUnitView.tscn"
)
const RangedScene := preload(
	"res://characters/enemies/skeleton/SkeletonRangedIsoUnitView.tscn"
)
const ElfScene := preload("res://characters/elf/ElfIsoUnitView.tscn")
const MageScene := preload("res://characters/mage/MageIsoUnitView.tscn")
const WarriorScene := preload("res://characters/warrior/WarriorIsoUnitView.tscn")

var _errors: Array[String] = []
var _captures := {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	RenderingServer.set_default_clear_color(Color(0.075, 0.085, 0.105, 1.0))
	var snow := SnowScene.instantiate() as SnowCenturionIsoUnitView
	snow.position = Vector2(960, 580)
	add_child(snow)
	await _frames(7)
	var idle_bounds := _capture_subviewport(snow, "snow_centurion_iso_idle.png")

	snow.play_walk(1.190476)
	await get_tree().create_timer(0.34).timeout
	_capture_subviewport(snow, "snow_centurion_iso_walk.png")
	snow.play_basic_attack()
	await get_tree().create_timer(0.37).timeout
	_capture_subviewport(snow, "snow_centurion_iso_attack.png")
	await get_tree().create_timer(1.20).timeout
	snow.play_hit()
	await get_tree().create_timer(0.36).timeout
	_capture_subviewport(snow, "snow_centurion_iso_hit.png")
	await get_tree().create_timer(0.42).timeout
	snow.play_death()
	await get_tree().create_timer(2.05).timeout
	var death_bounds := _capture_subviewport(snow, "snow_centurion_iso_death.png")
	if death_bounds.position.x <= 1 or death_bounds.position.y <= 1 \
			or death_bounds.end.x >= snow.viewport_size.x - 1 \
			or death_bounds.end.y >= snow.viewport_size.y - 1:
		_errors.append("Death touches the SubViewport border: %s" % str(death_bounds))
	snow.queue_free()
	await _frames(4)

	var scale_report := await _capture_scale_comparison()
	await _capture_y_sort()
	var roster_report := await _capture_room_four_roster()

	var report := {
		"passed": _errors.is_empty(),
		"errors": _errors,
		"idle_bounds": _rect_to_dictionary(idle_bounds),
		"death_bounds": _rect_to_dictionary(death_bounds),
		"scale_comparison": scale_report,
		"room_four": roster_report,
		"captures": _captures,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("SNOW_CENTURION_CAPTURE=", JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 3)


func _capture_scale_comparison() -> Dictionary:
	var chief := ChiefScene.instantiate() as SkeletonChiefIsoUnitView
	var snow := SnowScene.instantiate() as SnowCenturionIsoUnitView
	chief.position = Vector2(720, 585)
	snow.position = Vector2(1120, 585)
	add_child(chief)
	add_child(snow)
	await _frames(7)
	var chief_bounds := _opaque_bounds(chief.character_viewport.get_texture().get_image())
	var snow_bounds := _opaque_bounds(snow.character_viewport.get_texture().get_image())
	var ratio := float(snow_bounds.size.y) / float(maxi(chief_bounds.size.y, 1))
	if ratio < 0.92 or ratio > 1.08:
		_errors.append("Snow/normal visible height ratio %.4f is outside 0.92-1.08" % ratio)
	_save_main_viewport("normal_vs_snow_centurion_scale.png")
	chief.queue_free()
	snow.queue_free()
	await _frames(3)
	return {
		"normal_bounds": _rect_to_dictionary(chief_bounds),
		"snow_bounds": _rect_to_dictionary(snow_bounds),
		"height_ratio": ratio,
	}


func _capture_y_sort() -> void:
	var chief := ChiefScene.instantiate() as SkeletonChiefIsoUnitView
	var snow := SnowScene.instantiate() as SnowCenturionIsoUnitView
	chief.position = Vector2(865, 490)
	snow.position = Vector2(1015, 610)
	add_child(chief)
	add_child(snow)
	await _frames(7)
	_save_main_viewport("snow_centurion_y_sort.png")
	chief.queue_free()
	snow.queue_free()
	await _frames(3)


func _capture_room_four_roster() -> Dictionary:
	var scenes := [
		ElfScene, MageScene, WarriorScene,
		ChiefScene, ChiefScene, ChiefScene,
		SnowScene, SnowScene, RangedScene,
	]
	var positions := [
		Vector2(350, 430), Vector2(600, 430), Vector2(850, 430),
		Vector2(430, 795), Vector2(700, 795), Vector2(970, 795),
		Vector2(1240, 795), Vector2(1510, 795), Vector2(1710, 690),
	]
	var nodes: Array[CharacterIsoUnitView] = []
	for index in scenes.size():
		var character := scenes[index].instantiate() as CharacterIsoUnitView
		character.position = positions[index]
		add_child(character)
		nodes.append(character)
	await _frames(8)
	var subviewports := find_children("*", "SubViewport", true, false)
	if nodes.size() != 9 or subviewports.size() != 9:
		_errors.append("Expected nine characters/subviewports, got %d/%d" % [
			nodes.size(), subviewports.size(),
		])
	_save_main_viewport("room4_six_enemies.png")
	_save_main_viewport("room4_three_normal_two_snow_one_ranged.png")
	_save_main_viewport("trio_vs_room4_roster.png")
	_save_main_viewport("room4_no_placeholder.png")
	var report := {
		"character_count": nodes.size(),
		"enemy_count": 6,
		"subviewport_count": subviewports.size(),
		"snow_visual_classes": nodes.filter(
			func(node): return node is SnowCenturionIsoUnitView
		).size(),
	}
	for node in nodes:
		node.queue_free()
	await _frames(4)
	return report


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
