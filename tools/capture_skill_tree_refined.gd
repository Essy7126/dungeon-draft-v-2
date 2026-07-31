extends Control

const LAB_SCENE := preload(
	"res://ui/progression/lab/skill_tree_graybox_lab.tscn"
)
const CAPTURE_DIRECTORY := "res://artifacts/skill_tree_refined/captures"

const CAPTURE_CASES := [
	{
		"filename": "skill_tree_after_elf_archer_available_1920x1080.png",
		"scenario": 2,
		"size": Vector2i(1920, 1080),
		"node_id": &"elf_archer_long_range",
	},
	{
		"filename": "skill_tree_after_elf_archer_acquired_1920x1080.png",
		"scenario": 2,
		"size": Vector2i(1920, 1080),
		"node_id": &"elf_archer_eagle_eye",
	},
	{
		"filename": "skill_tree_after_elf_archer_locked_1920x1080.png",
		"scenario": 0,
		"size": Vector2i(1920, 1080),
		"node_id": &"elf_archer_eagle_eye",
	},
	{
		"filename": "skill_tree_after_elf_archer_exclusive_1920x1080.png",
		"scenario": 2,
		"size": Vector2i(1920, 1080),
		"node_id": &"elf_archer_repel_arrow",
	},
	{
		"filename": "skill_tree_after_elf_archer_specialization_1920x1080.png",
		"scenario": 5,
		"size": Vector2i(1920, 1080),
		"node_id": &"elf_archer_perfect_shot",
	},
	{
		"filename": "skill_tree_after_elf_archer_max_1920x1080.png",
		"scenario": 6,
		"size": Vector2i(1920, 1080),
		"node_id": &"elf_archer_perfect_shot",
	},
	{
		"filename": "skill_tree_after_elf_assassin_1920x1080.png",
		"scenario": 8,
		"size": Vector2i(1920, 1080),
		"node_id": &"",
	},
	{
		"filename": "skill_tree_after_elf_mage_1920x1080.png",
		"scenario": 9,
		"size": Vector2i(1920, 1080),
		"node_id": &"",
	},
	{
		"filename": "skill_tree_after_elf_healer_1920x1080.png",
		"scenario": 10,
		"size": Vector2i(1920, 1080),
		"node_id": &"",
	},
	{
		"filename": "skill_tree_after_mage_branches_1920x1080.png",
		"scenario": 11,
		"size": Vector2i(1920, 1080),
		"node_id": &"",
	},
	{
		"filename": "skill_tree_after_guardian_undefined_1920x1080.png",
		"scenario": 12,
		"size": Vector2i(1920, 1080),
		"node_id": &"",
	},
	{
		"filename": "skill_tree_after_elf_archer_1280x720.png",
		"scenario": 7,
		"size": Vector2i(1280, 720),
		"node_id": &"elf_archer_barbed_tip",
	},
	{
		"filename": "skill_tree_after_elf_archer_2560x1440.png",
		"scenario": 2,
		"size": Vector2i(2560, 1440),
		"node_id": &"elf_archer_long_range",
	},
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
	get_tree().quit()


func _capture_case(capture_case: Dictionary) -> void:
	var target_size: Vector2i = capture_case["size"]
	get_window().size = target_size
	_lab.set("_initial_window_size", target_size)
	_lab.show_scenario(int(capture_case["scenario"]))
	_lab.skill_tree_screen.offset_bottom = 0.0
	await _wait_for_layout(5)
	var node_id := StringName(capture_case["node_id"])
	if node_id != &"":
		_lab.skill_tree_screen.get_graph().inspect_node_by_id(node_id)
		await _wait_for_layout(2)
		_lab.skill_tree_screen.center_on_inspected_node()
		await _wait_for_layout(2)
	if not _lab.skill_tree_screen.visible:
		_lab.skill_tree_screen.open_for_state(
			_lab.preview_state,
			_lab.skill_tree_screen.current_discipline_id
		)
		await _wait_for_layout(3)
		if node_id != &"":
			_lab.skill_tree_screen.get_graph().inspect_node_by_id(node_id)
			_lab.skill_tree_screen.center_on_inspected_node()
			await _wait_for_layout(2)
	var image := get_viewport().get_texture().get_image()
	var output_path := CAPTURE_DIRECTORY + "/" + str(capture_case["filename"])
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Capture impossible : %s (%s)" % [output_path, error])
	else:
		print("CAPTURED %s %s" % [capture_case["filename"], image.get_size()])


func _wait_for_layout(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame
