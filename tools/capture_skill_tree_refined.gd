extends Control

const LAB_SCENE := preload(
	"res://ui/progression/lab/skill_tree_graybox_lab.tscn"
)
const CAPTURE_DIRECTORY := "res://artifacts/skill_tree_refined_v2/captures"

const CAPTURE_CASES := [
	{"filename":"elf_rank_1_1920x1080.png", "scenario":0, "size":Vector2i(1920,1080), "node_id":&"__base_rank_1"},
	{"filename":"next_rank_locked_1920x1080.png", "scenario":1, "size":Vector2i(1920,1080), "node_id":&"elf_archer_eagle_eye", "crop":"lock_closeup.png"},
	{"filename":"future_rank_hidden_1920x1080.png", "scenario":2, "size":Vector2i(1920,1080), "node_id":&""},
	{"filename":"elf_rank_2_1920x1080.png", "scenario":3, "size":Vector2i(1920,1080), "node_id":&"elf_archer_eagle_eye"},
	{"filename":"elf_rank_4_1920x1080.png", "scenario":4, "size":Vector2i(1920,1080), "node_id":&"elf_archer_perfect_shot"},
	{"filename":"elf_max_1920x1080.png", "scenario":5, "size":Vector2i(1920,1080), "node_id":&"elf_archer_perfect_shot", "node_sheet":true},
	{"filename":"node_acquired_1920x1080.png", "scenario":6, "size":Vector2i(1920,1080), "node_id":&"elf_archer_eagle_eye"},
	{"filename":"node_available_1920x1080.png", "scenario":7, "size":Vector2i(1920,1080), "node_id":&"elf_archer_long_range", "zones":true},
	{"filename":"prerequisite_locked_1920x1080.png", "scenario":8, "size":Vector2i(1920,1080), "node_id":&"elf_archer_barbed_tip"},
	{"filename":"node_excluded_1920x1080.png", "scenario":9, "size":Vector2i(1920,1080), "node_id":&"elf_archer_barbed_tip"},
	{"filename":"specialization_1920x1080.png", "scenario":10, "size":Vector2i(1920,1080), "node_id":&"elf_archer_eagle_eye"},
	{"filename":"capstone_1920x1080.png", "scenario":11, "size":Vector2i(1920,1080), "node_id":&"elf_archer_perfect_shot"},
	{"filename":"no_progression_guardian_1920x1080.png", "scenario":12, "size":Vector2i(1920,1080), "node_id":&""},
	{"filename":"mage_roots_1920x1080.png", "scenario":13, "size":Vector2i(1920,1080), "node_id":&"__base_rank_1"},
	{"filename":"responsive_1280x720.png", "scenario":14, "size":Vector2i(1280,720), "node_id":&"elf_archer_perfect_shot"},
	{"filename":"refined_after_1920x1080.png", "scenario":15, "size":Vector2i(1920,1080), "node_id":&"elf_archer_perfect_shot"},
	{"filename":"responsive_2560x1440.png", "scenario":16, "size":Vector2i(2560,1440), "node_id":&"elf_archer_perfect_shot"},
]

var _lab: SkillTreeGrayboxLab = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(CAPTURE_DIRECTORY)
	)
	_lab = LAB_SCENE.instantiate()
	add_child(_lab)
	await _wait_for_layout(4)
	_lab.get_node("ScenarioBar").hide()
	_lab.skill_tree_screen.offset_bottom = 0.0
	for capture_case in CAPTURE_CASES:
		await _capture_case(capture_case)
	await _capture_icon_mapping_sheet()
	_lab.queue_free()
	_lab = null
	await _wait_for_layout(3)
	get_tree().quit()


func _capture_case(capture_case: Dictionary) -> void:
	var target_size: Vector2i = capture_case["size"]
	get_window().size = target_size
	_lab.set("_initial_window_size", target_size)
	_lab.show_scenario(int(capture_case["scenario"]))
	_lab.skill_tree_screen.offset_bottom = 0.0
	await _wait_for_layout(5)
	var node_id := StringName(capture_case["node_id"])
	var inspected_view: SkillTreeNodeView = null
	if node_id != &"":
		_lab.skill_tree_screen.get_graph().inspect_node_by_id(node_id)
		inspected_view = _lab.skill_tree_screen.get_graph().get_node_view(node_id)
		await _wait_for_layout(2)
		_lab.skill_tree_screen.center_on_inspected_node()
		await _wait_for_layout(2)
	var image := get_viewport().get_texture().get_image()
	await _save_image(image, str(capture_case["filename"]))
	if capture_case.has("crop") and inspected_view != null:
		_save_control_crop(image, inspected_view, str(capture_case["crop"]), 32)
	if bool(capture_case.get("zones", false)):
		_save_control_crop(image, _lab.skill_tree_screen.get_node("%BranchNavigation"), "branch_navigation.png", 8)
		_save_control_crop(image, _lab.skill_tree_screen.get_detail_panel(), "node_detail_panel.png", 8)
	if bool(capture_case.get("node_sheet", false)):
		_save_node_contact_sheet(image)


func _save_image(image: Image, filename: String) -> void:
	var output_path := CAPTURE_DIRECTORY + "/" + filename
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Capture impossible : %s (%s)" % [output_path, error])
	else:
		print("CAPTURED %s %s" % [filename, image.get_size()])


func _save_control_crop(
		image: Image,
		control: Control,
		filename: String,
		padding: int
	) -> void:
	if control == null:
		return
	var rect := control.get_global_rect().grow(float(padding))
	var bounded := Rect2i(rect).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if bounded.size.x <= 0 or bounded.size.y <= 0:
		return
	var crop := image.get_region(bounded)
	crop.save_png(CAPTURE_DIRECTORY + "/" + filename)
	print("CAPTURED %s %s" % [filename, crop.get_size()])


func _save_node_contact_sheet(image: Image) -> void:
	var ids := [
		&"__base_rank_1",
		&"elf_archer_eagle_eye",
		&"elf_archer_long_range",
		&"elf_archer_perfect_shot",
	]
	var tile_size := Vector2i(280, 220)
	var sheet := Image.create(tile_size.x * ids.size(), tile_size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("090c11"))
	for index in range(ids.size()):
		var view := _lab.skill_tree_screen.get_graph().get_node_view(ids[index])
		if view == null:
			continue
		var rect := Rect2i(view.get_global_rect().grow(22.0)).intersection(
			Rect2i(Vector2i.ZERO, image.get_size())
		)
		var crop := image.get_region(rect)
		crop.resize(tile_size.x, tile_size.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(index * tile_size.x, 0))
	sheet.save_png(CAPTURE_DIRECTORY + "/node_types_contact_sheet.png")
	print("CAPTURED node_types_contact_sheet.png %s" % sheet.get_size())


func _capture_icon_mapping_sheet() -> void:
	get_window().size = Vector2i(1280, 720)
	_lab.hide()
	var surface := PanelContainer.new()
	surface.position = Vector2(30, 24)
	surface.size = Vector2(1220, 672)
	add_child(surface)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	surface.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	margin.add_child(grid)
	var catalog := _lab.skill_tree_screen.skin.icon_catalog
	var categories: Array = catalog.semantic_icons.keys()
	categories.sort()
	for category_value in categories:
		var category := StringName(category_value)
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(170, 116)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.texture = catalog.get_semantic_icon(category)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(icon)
		var label := Label.new()
		label.text = str(category).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		cell.add_child(label)
		grid.add_child(cell)
	await _wait_for_layout(4)
	var image := get_viewport().get_texture().get_image()
	_save_control_crop(image, surface, "icon_mapping_sheet.png", 0)
	surface.queue_free()
	await _wait_for_layout(2)


func _wait_for_layout(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame
