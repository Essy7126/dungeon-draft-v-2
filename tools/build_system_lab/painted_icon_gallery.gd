extends Node
## Render all production atlas cells at actual UI sizes for manual art review.
const Art := preload("res://core/expedition/class_icon_catalog.gd")
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const P := preload("res://ui/expedition/class_card_presentation.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var root := get_tree().root
	root.size = Vector2i(1280, 1080)
	var bg := ColorRect.new()
	bg.color = Color("101e1b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	bg.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	P.label(content, "CATABASE · Inventaire des illustrations intégrées", 27)
	P.label(
		content,
		"Techniques 64 px · emblèmes de classes · équipements 50 px · runes distinctes",
		17,
	)
	for profession in Cards.CLASSES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		content.add_child(row)
		var badge := VBoxContainer.new()
		badge.custom_minimum_size.x = 102
		row.add_child(badge)
		P.icon(badge, Art.icon(profession), 64)
		P.label(badge, Cards.CLASSES[profession][0], 14)
		for id in Cards.pool(profession):
			var column := VBoxContainer.new()
			row.add_child(column)
			P.icon(column, Art.icon(id), 64)
			P.label(column, id, 12)
	P.label(content, "ÉQUIPEMENTS · six emplacements, quatre affinités", 21)
	var equipment := HBoxContainer.new()
	equipment.add_theme_constant_override("separation", 20)
	content.add_child(equipment)
	for affinity in 4:
		var group := VBoxContainer.new()
		equipment.add_child(group)
		P.label(group, Cards.CLASSES.values()[affinity][0], 16)
		var grid := GridContainer.new()
		grid.columns = 3
		group.add_child(grid)
		for slot in 6:
			P.icon(grid, Art.icon("gear_%d_%d" % [slot, affinity]), 66)
	P.label(
		content,
		"RUNES · tranchant / pierre / voile / vigueur     •     EMPLACEMENTS VIDES",
		21,
	)
	var runes := HBoxContainer.new()
	content.add_child(runes)
	for id in Art.RUNES:
		P.icon(runes, Art.icon(id), 64)
	for index in 6:
		P.icon(runes, Art.empty_slot(index), 64)
	var relics := HBoxContainer.new()
	content.add_child(relics)
	for id in Art.PREPARATION:
		P.icon(relics, Art.icon(id), 64)
	var armors := HBoxContainer.new()
	content.add_child(armors)
	for id in Art.ARMORS:
		P.icon(armors, Art.icon(id), 64)
	await get_tree().create_timer(.8).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/dev/painted-interface/icon_gallery.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error := root.get_texture().get_image().save_png(path)
	print("ICON_GALLERY ", error)
	get_tree().quit(0 if error == OK else 1)
