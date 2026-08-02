extends Node2D

const REPORT_PATH := "C:/Blender_AI_Test/Output/skeleton_chief_performance_report.json"
const ElfScene := preload("res://characters/elf/ElfIsoUnitView.tscn")
const MageScene := preload("res://characters/mage/MageIsoUnitView.tscn")
const WarriorScene := preload("res://characters/warrior/WarriorIsoUnitView.tscn")
const ChiefScene := preload("res://characters/enemies/skeleton_chief/SkeletonChiefIsoUnitView.tscn")
const MeleeScene := preload("res://characters/enemies/skeleton/SkeletonMeleeIsoUnitView.tscn")
const RangedScene := preload("res://characters/enemies/skeleton/SkeletonRangedIsoUnitView.tscn")
const HeavySpell := preload("res://data/spells/enemies/skeleton_chief_heavy_strike.tres")
const RangedSpell := preload("res://data/spells/enemies/skeleton_ranged_shot.tres")

var _elapsed := 0.0
var _samples: Array[float] = []
var _events := {}
var _characters: Array[CharacterIsoUnitView] = []
var _chief: SkeletonChiefIsoUnitView
var _melee: SkeletonIsoUnitView
var _ranged: SkeletonIsoUnitView


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.075, 0.085, 0.105, 1.0))
	var scenes := [ElfScene, MageScene, WarriorScene, ChiefScene, MeleeScene, RangedScene]
	var positions := [
		Vector2(410, 390), Vector2(720, 390), Vector2(1030, 390),
		Vector2(600, 780), Vector2(920, 780), Vector2(1240, 780),
	]
	for index in scenes.size():
		var character := scenes[index].instantiate() as CharacterIsoUnitView
		character.position = positions[index]
		add_child(character)
		_characters.append(character)
	_chief = _characters[3] as SkeletonChiefIsoUnitView
	_melee = _characters[4] as SkeletonIsoUnitView
	_ranged = _characters[5] as SkeletonIsoUnitView


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.0:
		_samples.append(1.0 / maxf(delta, 0.000001))
	_trigger_once("movement", 1.25, func():
		for character in _characters:
			character.play_walk()
	)
	_trigger_once("chief_attack", 2.25, func(): _chief.play_basic_attack())
	_trigger_once("ranged_attack", 2.35, func(): _ranged.play_spell_action(RangedSpell))
	_trigger_once("chief_heavy", 3.95, func(): _chief.play_spell_action(HeavySpell))
	_trigger_once("hits", 5.75, func():
		_chief.play_hit()
		_melee.play_hit()
		_ranged.play_hit()
	)
	_trigger_once("deaths", 6.65, func():
		_chief.play_death()
		_melee.play_death()
		_ranged.play_death()
	)
	if _elapsed >= 9.25:
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
	var report := {
		"resolution": [get_viewport_rect().size.x, get_viewport_rect().size.y],
		"average_fps": total / maxf(float(_samples.size()), 1.0),
		"minimum_fps": minimum if not _samples.is_empty() else 0.0,
		"duration_seconds": _elapsed,
		"samples": _samples.size(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"subviewport_count": subviewports.size(),
		"subviewport_sizes": subviewports.map(func(viewport): return [viewport.size.x, viewport.size.y]),
		"phases": _events.keys(),
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("SKELETON_CHIEF_PERFORMANCE=", JSON.stringify(report))
	get_tree().quit()
