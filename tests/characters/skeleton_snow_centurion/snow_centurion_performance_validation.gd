extends Node2D

const REPORT_PATH := "C:/Blender_AI_Test/Output/snow_centurion_performance_report.json"
const ElfScene := preload("res://characters/elf/ElfIsoUnitView.tscn")
const MageScene := preload("res://characters/mage/MageIsoUnitView.tscn")
const WarriorScene := preload("res://characters/warrior/WarriorIsoUnitView.tscn")
const ChiefScene := preload("res://characters/enemies/skeleton_chief/SkeletonChiefIsoUnitView.tscn")
const SnowScene := preload(
	"res://characters/enemies/skeleton_snow_centurion/SnowCenturionIsoUnitView.tscn"
)
const RangedScene := preload("res://characters/enemies/skeleton/SkeletonRangedIsoUnitView.tscn")
const HeavySpell := preload("res://data/spells/enemies/skeleton_chief_heavy_strike.tres")
const RangedSpell := preload("res://data/spells/enemies/skeleton_ranged_shot.tres")

var _elapsed := 0.0
var _samples: Array[float] = []
var _events := {}
var _characters: Array[CharacterIsoUnitView] = []
var _chiefs: Array[SkeletonChiefIsoUnitView] = []
var _snow: Array[SnowCenturionIsoUnitView] = []
var _ranged: SkeletonIsoUnitView
var _triangle_count := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.075, 0.085, 0.105, 1.0))
	var scenes := [
		ElfScene, MageScene, WarriorScene,
		ChiefScene, ChiefScene, ChiefScene,
		SnowScene, SnowScene, RangedScene,
	]
	var positions := [
		Vector2(300, 350), Vector2(600, 350), Vector2(900, 350),
		Vector2(400, 760), Vector2(700, 760), Vector2(1000, 760),
		Vector2(1300, 760), Vector2(1580, 760), Vector2(1740, 520),
	]
	for index in scenes.size():
		var character := scenes[index].instantiate() as CharacterIsoUnitView
		character.position = positions[index]
		add_child(character)
		_characters.append(character)
		if character is SkeletonChiefIsoUnitView:
			_chiefs.append(character)
		elif character is SnowCenturionIsoUnitView:
			_snow.append(character)
	_ranged = _characters[-1] as SkeletonIsoUnitView
	await get_tree().process_frame
	await get_tree().process_frame
	_triangle_count = _count_rendered_triangles()
	_events["idle"] = true


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.0:
		_samples.append(1.0 / maxf(delta, 0.000001))
	_trigger_once("movement", 1.25, func():
		for character in _characters:
			character.play_walk()
	)
	_trigger_once("three_normal_attacks", 2.25, func():
		for chief in _chiefs:
			chief.play_basic_attack()
	)
	_trigger_once("ranged_attack", 2.35, func(): _ranged.play_spell_action(RangedSpell))
	_trigger_once("heavy_attacks", 3.95, func():
		_chiefs[0].play_spell_action(HeavySpell)
		_snow[0].play_spell_action(HeavySpell)
	)
	_trigger_once("snow_attack", 4.15, func(): _snow[1].play_basic_attack())
	_trigger_once("hits", 5.85, func():
		_chiefs[1].play_hit()
		_snow[0].play_hit()
		_ranged.play_hit()
	)
	_trigger_once("deaths", 6.85, func():
		_chiefs[2].play_death()
		_snow[1].play_death()
		_ranged.play_death()
	)
	_trigger_once("end_of_combat", 9.10, func(): pass)
	if _elapsed >= 9.50:
		_finish()


func _trigger_once(key: String, at_seconds: float, callback: Callable) -> void:
	if _elapsed < at_seconds or _events.has(key):
		return
	_events[key] = true
	callback.call()


func _finish() -> void:
	set_process(false)
	var total := 0.0
	var minimum := INF
	for sample in _samples:
		total += sample
		minimum = minf(minimum, sample)
	var subviewports := find_children("*", "SubViewport", true, false)
	var average := total / maxf(float(_samples.size()), 1.0)
	var minimum_value := minimum if not _samples.is_empty() else 0.0
	var report := {
		"passed": average > 90.0 and minimum_value > 60.0,
		"targets": {"average_fps_above": 90.0, "minimum_fps_above": 60.0},
		"resolution": [get_viewport_rect().size.x, get_viewport_rect().size.y],
		"average_fps": average,
		"minimum_fps": minimum_value,
		"duration_seconds": _elapsed,
		"samples": _samples.size(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"subviewport_count": subviewports.size(),
		"subviewport_sizes": subviewports.map(
			func(viewport): return [viewport.size.x, viewport.size.y]
		),
		"approximate_rendered_triangles": _triangle_count,
		"static_memory_bytes": OS.get_static_memory_usage(),
		"phases": _events.keys(),
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("SNOW_CENTURION_PERFORMANCE=", JSON.stringify(report))
	get_tree().quit(0 if report.passed else 4)


func _count_rendered_triangles() -> int:
	var total := 0
	for character in _characters:
		var visual := character.get_character_visual()
		var mesh_instance := visual.get_mesh_instance() if visual != null else null
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			total += indices.size() / 3
	return total
