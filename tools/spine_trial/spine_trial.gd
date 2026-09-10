extends Node2D

const SAMPLES := [
	["Spineboy — exemple officiel", "examples/spineboy/spineboy-pro", "run", 0.7],
	["Sentinelle — vue E", "sentinelle/E/sentinelle", "controle_articulations", 1.65],
	["Sentinelle — vue N", "sentinelle/N/sentinelle", "controle_articulations", 1.65],
]
var _sprite: Node2D
var _description: Label
var _report_path := ""


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("192128"))
	var panel := VBoxContainer.new()
	panel.position = Vector2(28, 24)
	add_child(panel)
	_description = Label.new()
	_description.text = "Atelier Spine · essai local"
	_description.add_theme_font_size_override("font_size", 26)
	panel.add_child(_description)
	var selector := OptionButton.new()
	for sample in SAMPLES:
		selector.add_item(sample[0])
	selector.select(1)
	selector.item_selected.connect(_show_sample)
	panel.add_child(selector)
	var pause := CheckButton.new()
	pause.text = "Pause"
	pause.toggled.connect(
		func(value: bool):
			if is_instance_valid(_sprite):
				_sprite.call("set_time_scale", 0.0 if value else 1.0),
	)
	panel.add_child(pause)
	var note := Label.new()
	note.text = "Sentinelle : contrôle des articulations, attaque à construire et à valider."
	panel.add_child(note)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			_report_path = argument.trim_prefix("--report=")
	if not ClassDB.class_exists("SpineSprite"):
		_description.text = "Installer d'abord tools/spine_trial/install.ps1"
		if not _report_path.is_empty():
			_finish({ "passed": false, "error": "SpineSprite unavailable" })
		return
	_show_sample(1)
	if not _report_path.is_empty():
		_verify()


func _show_sample(index: int) -> void:
	if is_instance_valid(_sprite):
		remove_child(_sprite)
		_sprite.queue_free()
	var sample: Array = SAMPLES[index]
	var base: String = ProjectSettings.globalize_path("res://artifacts/spine_trial/" + sample[1])
	# The native runtime identifies JSON by its .spine-json extension.
	if DirAccess.copy_absolute(base + ".json", base + ".spine-json") != OK:
		_description.text = "Impossible de préparer la copie JSON du lecteur Godot."
		return
	var skeleton: Object = ClassDB.instantiate("SpineSkeletonFileResource")
	skeleton.call("load_from_file", base + ".spine-json")
	var atlas: Object = ClassDB.instantiate("SpineAtlasResource")
	var atlas_path := base + ".atlas"
	atlas.call("load_from_atlas_file", atlas_path)
	var data: Object = ClassDB.instantiate("SpineSkeletonDataResource")
	data.call("set_atlas_res", atlas)
	data.call("set_skeleton_file_res", skeleton)
	_sprite = ClassDB.instantiate("SpineSprite")
	_sprite.set("skeleton_data_res", data)
	_sprite.position = Vector2(640, 690)
	_sprite.scale = Vector2.ONE * float(sample[3])
	add_child(_sprite)
	_sprite.call("get_animation_state").set_animation(sample[2], true, 0)
	_description.text = sample[0]


func _verify() -> void:
	var checks: Array = []
	for index in range(SAMPLES.size()):
		_show_sample(index)
		await get_tree().create_timer(0.1).timeout
		var before: Transform2D = _sprite.call("get_global_bone_transform", "head")
		await get_tree().create_timer(0.3).timeout
		var after: Transform2D = _sprite.call("get_global_bone_transform", "head")
		await RenderingServer.frame_post_draw
		var capture := _report_path.get_base_dir().path_join("sample_%d.png" % index)
		var error := get_viewport().get_texture().get_image().save_png(capture)
		checks.append(
			{
				"sample": SAMPLES[index][0],
				"animated": not before.is_equal_approx(after),
				"capture": capture,
				"capture_ok": error == OK,
			}
		)
	var passed := checks.all(
		func(check: Dictionary):
			return check.animated and check.capture_ok,
	)
	_finish({ "passed": passed, "checks": checks })


func _finish(report: Dictionary) -> void:
	var output := FileAccess.open(_report_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	get_tree().quit(0 if report.passed else 1)
