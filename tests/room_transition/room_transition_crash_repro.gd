extends Node

const RUN_DATA := preload("res://data/runs/fixed_trio_prototype_run.tres")
const HERO_PATHS := [
	GameManager.ELF_DATA_PATH,
	GameManager.MAGE_DATA_PATH,
	GameManager.WARRIOR_DATA_PATH,
]

@onready var battle = $Battle


func _enter_tree() -> void:
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(RUN_DATA, HERO_PATHS):
		push_error("REPRO_SETUP_FAILED")
		get_tree().quit(70)
		return
	GameManager.current_room_index = 0


func _ready() -> void:
	GameManager.scene_change_requested.connect(_on_scene_change_requested)
	await get_tree().process_frame
	for cell in [Vector2i(9, 7), Vector2i(8, 7), Vector2i(7, 7)]:
		battle._deployment.on_cell_clicked(cell)
		await get_tree().process_frame
	await get_tree().process_frame
	var enemies: Array = battle.units.filter(
		func(unit): return unit != null and unit.team == 1
	)
	print("REPRO_ROOM=", GameManager.current_room_index + 1)
	print("REPRO_CURRENT_SCENE=", get_tree().current_scene.scene_file_path)
	print("REPRO_ENEMIES=", enemies.map(func(unit): return unit.unit_id))
	print("REPRO_BATTLE_OVER_BEFORE=", battle._battle_over)
	print("REPRO_RUNNER_INSIDE_TREE=", battle._enemy_turn.is_inside_tree())
	print("REPRO_UNIT_VIEW_COUNT=", battle._unit_views.size())
	for index in enemies.size():
		var enemy: Unit = enemies[index]
		if index == enemies.size() - 1:
			var view = battle._unit_views.get(enemy)
			var visual = view.get_optional_visual() if is_instance_valid(view) else null
			print("REPRO_LAST_ENEMY=", enemy.unit_id)
			print("REPRO_LAST_VIEW_INSIDE_TREE=", is_instance_valid(view) and view.is_inside_tree())
			print("REPRO_LAST_VISUAL_ANIMATION_BEFORE=", (
				visual.get_character_visual().get_current_animation()
				if is_instance_valid(visual) and visual.has_method("get_character_visual")
				else &""
			))
		enemy.take_damage(
			enemy.current_hp + 1000,
			GameManager.heroes[0],
			Spell.DamageType.PHYSICAL,
			Spell.Element.NONE
		)
		await get_tree().process_frame
	print("REPRO_BATTLE_OVER_AFTER=", battle._battle_over)
	print("REPRO_VFX_CHILDREN=", battle.get_node("VFXLayer").get_child_count())


func _on_scene_change_requested(path: String) -> void:
	print("REPRO_SCENE_CHANGE_REQUESTED=", path)
	print("REPRO_BATTLE_INSIDE_TREE_AT_REQUEST=", battle.is_inside_tree())
	print("REPRO_RUNNER_INSIDE_TREE_AT_REQUEST=", battle._enemy_turn.is_inside_tree())
