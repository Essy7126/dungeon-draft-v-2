class_name VFXStudioSliceLab
extends Control

const PROFILE_PATHS := [
	"res://vfx/profiles/test/shield_lifecycle.tres",
	"res://vfx/profiles/test/lightning_multi_target.tres",
	"res://vfx/profiles/test/player_path_preview.tres",
]

var stages: Array[VFXComposerPreviewStage] = []
var instances: Array[VFXRuntimeInstance] = []
var profile_fingerprints := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var title := Label.new()
	title.text = "VFX LAB — VFXProfile / Context / Runner partagés — TECHNICAL_PLACEHOLDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("79dcff"))
	root.add_child(title)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 8)
	root.add_child(columns)
	for label_text in ["SHIELD LIFECYCLE", "LIGHTNING MULTI-TARGET", "PLAYER PATH — CASES FOURNIES"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var label := Label.new()
		label.text = label_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		var stage := VFXComposerPreviewStage.new()
		stage.custom_minimum_size = Vector2(500, 700)
		stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(stage)
		stages.append(stage)
	call_deferred("play_all")


func play_all() -> void:
	clear_all()
	if stages.size() != 3:
		return
	var contexts := [
		VFXExecutionContext.create({
			"target_world": Vector2(250, 320),
			"impact_world_points": PackedVector2Array([Vector2(285, 305)]),
			"seed": 424242, "quality_tier": 2, "magnitude": 0.82,
		}),
		VFXExecutionContext.create({
			"origin_world": Vector2(80, 345), "target_world": Vector2(405, 345),
			"impact_world_points": PackedVector2Array([
				Vector2(350, 175), Vector2(420, 340), Vector2(345, 515),
			]),
			"seed": 424242, "quality_tier": 2,
		}),
		_path_context(),
	]
	var sequences := [&"apply", &"play", &"play"]
	for index in PROFILE_PATHS.size():
		var profile := ResourceLoader.load(PROFILE_PATHS[index], "", ResourceLoader.CACHE_MODE_IGNORE) as VFXProfile
		profile_fingerprints[profile.profile_id] = VFXProfileSnapshotService.fingerprint(profile)
		var result := VFXProfileRunner.play(profile, contexts[index], sequences[index], stages[index], false)
		if bool(result.ok):
			var instance := result.instance as VFXRuntimeInstance
			instances.append(instance)
			instance.advance_simulation(0.32)


func clear_all() -> void:
	for instance in instances:
		if is_instance_valid(instance):
			instance.clear()
			instance.free()
	instances.clear()


func _path_context() -> VFXExecutionContext:
	var cells: Array[Vector2i] = []
	var points := PackedVector2Array()
	for index in 7:
		cells.append(Vector2i(index, index % 2))
		points.append(Vector2(65 + index * 62, 280 + (index % 2) * 38))
	return VFXExecutionContext.create({
		"origin_cell": cells[0], "target_cell": cells[-1],
		"ordered_path_cells": cells, "path_world_points": points,
		"origin_world": points[0], "target_world": points[-1],
		"impact_world_points": PackedVector2Array([points[-1]]),
		"path_valid": true, "seed": 424242, "quality_tier": 2,
		"consumer_kind": &"PLAYER_CONTROLLED",
	})


func _exit_tree() -> void:
	clear_all()
