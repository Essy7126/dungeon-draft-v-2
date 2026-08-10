extends Node

const OUTPUT_DIR := "res://artifacts/fireball_variants"
const LAB_SCENE := preload("res://tools/labs/vfx_lab/VFXLab.tscn")
const FIREBALL_SCENE := preload("res://tools/labs/vfx_lab/effects/FireballLabVFX.tscn")
const VIEWPORT_SIZE := Vector2i(1200, 896)
const REFERENCE_SEED := 424242
const VARIANTS := [&"A", &"B", &"C"]
const VARIANT_DIRS := {
	&"A": "A_compact_nervous",
	&"B": "B_organic_turbulent",
	&"C": "C_magical_stylized",
}
const FRAME_NAMES := [
	"01_cast_t014.png",
	"02_projectile_mid_t062.png",
	"03_contact_t103.png",
	"04_impact_expansion_t118.png",
	"05_dissipation_t174.png",
]
const CAPTURE_TIMES := [0.14, 0.62, 1.03, 1.18, 1.74]

var _lab: Node2D = null
var _failures := 0
var _captures: Array[String] = []
var _signatures: Dictionary = {}


func _ready() -> void:
	call_deferred("_capture_variants")


func _capture_variants() -> void:
	get_window().size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_lab = LAB_SCENE.instantiate() as Node2D
	add_child(_lab)
	await _settle(8)
	_lab.clear_effect()
	for variant in VARIANTS:
		await _capture_variant(variant)
	_validate_outputs()
	_save_metrics()
	print("FIREBALL_VARIANT_CAPTURE_COUNT=%d" % _captures.size())
	print("FIREBALL_VARIANT_CAPTURE_FAILURES=%d" % _failures)
	if _failures == 0:
		print("FIREBALL_VARIANTS_CAPTURED")
	get_tree().quit(1 if _failures > 0 else 0)


func _capture_variant(variant: StringName) -> void:
	var directory: String = str(VARIANT_DIRS[variant])
	var output_path := OUTPUT_DIR.path_join(directory)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path))
	var effect: Node2D = FIREBALL_SCENE.instantiate() as Node2D
	_lab.world.add_child(effect)
	effect.play({
		"seed": REFERENCE_SEED,
		"variant": variant,
		"start": _lab.grid_to_world(Vector2i(1, 3)) + Vector2(0.0, -42.0),
		"target": _lab.grid_to_world(Vector2i(7, 3)),
	})
	effect.set_process(false)
	_lab.fireball_variant_selector.select(VARIANTS.find(variant))
	_lab.effect_title.text = "FIREBALL %s  —  %s" % [variant, effect._spec["label"]]
	_lab.status_label.text = "REFERENCE  •  seed %d  •  timestamps fixes" % REFERENCE_SEED
	_signatures[String(variant)] = effect.get_procedural_signature()
	var previous_time := 0.0
	for frame_index in CAPTURE_TIMES.size():
		var target_time: float = CAPTURE_TIMES[frame_index]
		await _advance(effect, target_time - previous_time)
		previous_time = target_time
		var phase: StringName = effect.get_phase()
		var expected_phase: StringName = [&"cast", &"projectile", &"impact", &"impact", &"aftermath"][frame_index]
		if phase != expected_phase:
			_fail("phase %s inattendue pour %s frame %d (attendu %s)" % [phase, variant, frame_index, expected_phase])
		await _capture(output_path.path_join(FRAME_NAMES[frame_index]))
	effect.stop_and_clear()
	if effect.get_visual_node_count() != 0:
		_fail("cleanup incomplet pour variante %s" % variant)
	effect.free()
	if _lab.world.get_child_count() != 4:
		_fail("node residuel apres variante %s" % variant)
	await _settle(3)


func _advance(effect: Node, seconds: float) -> void:
	var frames := maxi(1, ceili(seconds * 60.0))
	var step := seconds / float(frames)
	for _frame in frames:
		effect.advance_simulation(step)
		await get_tree().process_frame
	await _settle(2)


func _capture(relative_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("framebuffer vide pour %s" % relative_path)
		return
	var absolute := ProjectSettings.globalize_path(relative_path)
	var error := image.save_png(absolute)
	if error != OK:
		_fail("capture impossible %s: %s" % [relative_path, error_string(error)])
		return
	_captures.append(relative_path)
	print("FIREBALL_CAPTURE=%s" % absolute)


func _validate_outputs() -> void:
	for variant in VARIANTS:
		var directory: String = str(VARIANT_DIRS[variant])
		for frame_name in FRAME_NAMES:
			var path := OUTPUT_DIR.path_join(directory).path_join(frame_name)
			if not FileAccess.file_exists(path):
				_fail("capture absente: %s" % path)


func _save_metrics() -> void:
	var metrics := {
		"godot": Engine.get_version_info().get("string", "unknown"),
		"renderer_available": RenderingServer.get_rendering_device() != null,
		"resolution": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"seed": REFERENCE_SEED,
		"capture_times_seconds": CAPTURE_TIMES,
		"frame_names": FRAME_NAMES,
		"variants": VARIANT_DIRS,
		"signatures": _signatures,
		"captures": _captures,
		"external_vfx_assets": 0,
		"remaining_stage_children": _lab.world.get_child_count(),
	}
	var path := OUTPUT_DIR.path_join("comparison_metrics.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("metrics impossibles a ecrire")
		return
	file.store_string(JSON.stringify(metrics, "  "))
	print("FIREBALL_CAPTURE_METRICS=%s" % ProjectSettings.globalize_path(path))


func _settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().process_frame


func _fail(message: String) -> void:
	_failures += 1
	push_error("FIREBALL_VARIANT_CAPTURE: %s" % message)
