extends Node

const SCREEN_SCENE := preload(
	"res://ui/progression/screens/skill_tree_screen.tscn"
)
const OUTPUT_DIR := "res://artifacts/skill_trees/captures"
const HEROES := [
	{
		"path": "res://data/units/alliés/elfe.tres",
		"slug": "elf",
	},
	{
		"path": "res://data/units/alliés/mage.tres",
		"slug": "mage",
	},
	{
		"path": "res://data/units/alliés/Guerrier.tres",
		"slug": "warrior",
	},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	for hero in HEROES:
		var data := load(hero["path"]) as UnitData
		for discipline in data.disciplines:
			var state := _make_state(data)
			_complete_discipline(state, discipline)
			await _capture_state(
				state,
				discipline.discipline_id,
				"tree_%s_%s" % [hero["slug"], discipline.discipline_id]
			)
	var mage := load(HEROES[1]["path"]) as UnitData
	var fire := mage.disciplines[0] as DisciplineData
	await _capture_state(_make_state(mage), fire.discipline_id, "state_fully_locked")
	var partial := _make_state(mage)
	partial.add_discipline_xp(fire.discipline_id, 7)
	partial.select_upgrade(fire.discipline_id, 2, fire.ranks[1].choices[0].upgrade_id)
	await _capture_state(partial, fire.discipline_id, "state_partially_progressed")
	var excluded := _make_state(mage)
	excluded.add_discipline_xp(fire.discipline_id, 3)
	excluded.select_upgrade(fire.discipline_id, 2, fire.ranks[1].choices[0].upgrade_id)
	await _capture_state(excluded, fire.discipline_id, "state_excluded_branch")
	var maximum := _make_state(mage)
	_complete_discipline(maximum, fire)
	await _capture_state(maximum, fire.discipline_id, "state_rank_5")
	await _capture_state(
		maximum,
		fire.discipline_id,
		"state_capstone_detail",
		fire.ranks[4].choices[0].upgrade_id
	)
	var elf := load(HEROES[0]["path"]) as UnitData
	var archer := elf.disciplines[0] as DisciplineData
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		get_window().size = viewport_size
		await get_tree().process_frame
		var responsive := _make_state(elf)
		_complete_discipline(responsive, archer)
		await _capture_state(
			responsive,
			archer.discipline_id,
			"resolution_%dx%d" % [viewport_size.x, viewport_size.y]
		)
	get_tree().quit()


func _make_state(data: UnitData) -> CharacterRunState:
	var state := CharacterRunState.new()
	state.initialize(Unit.from_data(data), data)
	return state


func _complete_discipline(
		state: CharacterRunState,
		discipline: DisciplineData
	) -> void:
	state.add_discipline_xp(discipline.discipline_id, 18)
	var selected := discipline.ranks[1].choices[0] as SkillTreeNodeData
	state.select_upgrade(discipline.discipline_id, 2, selected.upgrade_id)
	for rank_number in [3, 4]:
		for candidate in discipline.ranks[rank_number - 1].choices:
			var node := candidate as SkillTreeNodeData
			if node.prerequisite_node_ids.has(selected.upgrade_id):
				state.select_upgrade(discipline.discipline_id, rank_number, node.upgrade_id)
				selected = node
				break
	var r2_id := discipline.ranks[1].choices[0].upgrade_id
	for candidate in discipline.ranks[4].choices:
		var capstone := candidate as SkillTreeNodeData
		if capstone.prerequisite_node_ids.has(r2_id):
			state.select_upgrade(discipline.discipline_id, 5, capstone.upgrade_id)
			break


func _capture_state(
		state: CharacterRunState,
		discipline_id: StringName,
		file_stem: String,
		inspect_id: StringName = &""
	) -> void:
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child(screen)
	screen.open_for_state(state, discipline_id)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if inspect_id != &"":
		screen.get_graph().inspect_node_by_id(inspect_id)
		await get_tree().process_frame
	var path := "%s/%s.png" % [OUTPUT_DIR, file_stem]
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Capture impossible %s: %s" % [path, error_string(error)])
	else:
		print("CAPTURED %s" % path)
	screen.queue_free()
	await get_tree().process_frame
