extends GutTest

const Factory = preload("res://test/support/factory.gd")
const UnitViewScript = preload("res://battle/unit_view.gd")
const ProjectileScene = preload(
	"res://battle/vfx/skeleton_ranged_projectile_vfx.tscn"
)
const MELEE_PATH := "res://data/units/ennemie/skeleton_melee.tres"
const RANGED_PATH := "res://data/units/ennemie/skeleton_ranged.tres"


class ControlledVisual extends Node2D:
	signal cast_release_reached
	signal animation_finished(animation_name: StringName)
	signal death_animation_finished

	var basic_started := 0
	var spell_started := 0
	var spell_cancelled := 0
	var facing := Vector2i.ZERO

	func set_facing(direction: Vector2i) -> void:
		facing = direction

	func play_basic_attack() -> bool:
		basic_started += 1
		return true

	func play_spell_action(_spell: Spell = null) -> bool:
		spell_started += 1
		return true

	func cancel_spell_action() -> void:
		spell_cancelled += 1

	func release() -> void:
		cast_release_reached.emit()

	func finish_action() -> void:
		animation_finished.emit(&"Attack")

	func finish_death() -> void:
		death_animation_finished.emit()


class RunnerBattleSpy extends Node:
	var spell_caster: SpellCaster
	var grid: GridData
	var grid_view := Node2D.new()
	var _unit_views := {}
	var _battle_over := false

	func _init() -> void:
		add_child(grid_view)

	func _animate_attack(_unit: Unit, _target: Unit) -> void:
		var tree := get_tree()
		if tree != null:
			await tree.process_frame

	func _animate_move(_unit: Unit, _path: Array) -> void:
		var tree := get_tree()
		if tree != null:
			await tree.process_frame


func _make_controlled_view(unit: Unit, parent: Node = self) -> Dictionary:
	var view = UnitViewScript.new()
	parent.add_child(view)
	view.setup(unit)
	var visual := ControlledVisual.new()
	view.add_child(visual)
	view._optional_visual = visual
	visual.animation_finished.connect(view._on_optional_visual_action_finished)
	return {"view": view, "visual": visual}


func _make_runner_fixture(ranged := false) -> Dictionary:
	var field := Factory.make_battlefield(8, 1)
	var data_path := RANGED_PATH if ranged else MELEE_PATH
	var attacker := Unit.from_data(load(data_path) as UnitData)
	var target := Factory.make_unit("Cible stable", 0)
	var target_cell := Vector2i(6, 0) if ranged else Vector2i(1, 0)
	field.grid.place_unit(attacker, Vector2i(0, 0))
	field.grid.place_unit(target, target_cell)
	var battle := RunnerBattleSpy.new()
	add_child(battle)
	battle.grid = field.grid
	battle.spell_caster = field.caster
	var controlled := _make_controlled_view(attacker, battle)
	var runner := EnemyTurnRunner.new()
	battle.add_child(runner)
	runner.setup(battle)
	battle._unit_views[attacker] = controlled.view
	return {
		"field": field,
		"attacker": attacker,
		"target": target,
		"target_cell": target_cell,
		"battle": battle,
		"view": controlled.view,
		"visual": controlled.visual,
		"runner": runner,
	}


func _capture_basic_prepare(view, state: Dictionary) -> void:
	state.result = await view.prepare_basic_attack_visual(Vector2i.RIGHT)
	state.done = true


func _capture_spell_prepare(view, state: Dictionary) -> void:
	state.result = await view.prepare_spell_visual(Vector2i.RIGHT, null)
	state.done = true


func _capture_recovery(view, state: Dictionary) -> void:
	state.released = await view.prepare_basic_attack_visual(Vector2i.RIGHT)
	if state.released:
		state.recovery_started = true
		await view.wait_for_action_visual_finished()
	state.done = true


func _capture_attack(runner: EnemyTurnRunner, attacker: Unit, target: Unit, state: Dictionary) -> void:
	await runner._execute_attack(attacker, target)
	state.done = true


func _capture_cast(runner: EnemyTurnRunner, attacker: Unit, spell: Spell, cell: Vector2i, state: Dictionary) -> void:
	await runner._execute_cast(attacker, spell, cell)
	state.done = true


func _detach_and_free_after_resume(node: Node) -> void:
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	await wait_process_frames(2)
	if is_instance_valid(node):
		node.free()


func _cleanup_fixture(fixture: Dictionary) -> void:
	var battle: Node = fixture.battle
	if is_instance_valid(battle):
		if battle.is_inside_tree():
			battle.queue_free()
		else:
			battle.free()
	fixture.attacker.clear_traits()
	fixture.target.clear_traits()


# 1. La fin de salle pendant la recuperation melee ne doit pas reprendre une
# coroutine attachee a l'ancienne SceneTree.
func test_room_finish_during_melee_recovery_is_cancelled() -> void:
	var fixture := _make_runner_fixture(false)
	var state := {"done": false}
	_capture_attack(fixture.runner, fixture.attacker, fixture.target, state)
	await wait_process_frames(1)
	fixture.visual.release()
	await wait_process_frames(2)
	var hp_after_impact: int = fixture.target.current_hp
	assert_lt(hp_after_impact, 100)
	fixture.battle._battle_over = true
	fixture.runner.cancel_pending_actions()
	fixture.view.cancel_pending_visual_actions()
	await wait_process_frames(2)
	assert_true(state.done)
	assert_eq(fixture.target.current_hp, hp_after_impact)
	_cleanup_fixture(fixture)


# 2. Meme garantie pendant la recuperation d'un tir a distance.
func test_room_finish_during_ranged_recovery_is_cancelled() -> void:
	var fixture := _make_runner_fixture(true)
	var state := {"done": false}
	_capture_cast(
		fixture.runner,
		fixture.attacker,
		fixture.attacker.spells[0],
		fixture.target_cell,
		state
	)
	await wait_process_frames(1)
	fixture.visual.release()
	await get_tree().create_timer(0.27).timeout
	var hp_after_impact: int = fixture.target.current_hp
	assert_lt(hp_after_impact, 100)
	fixture.battle._battle_over = true
	fixture.runner.cancel_pending_actions()
	fixture.view.cancel_pending_visual_actions()
	await wait_process_frames(2)
	assert_true(state.done)
	assert_eq(fixture.target.current_hp, hp_after_impact)
	_cleanup_fixture(fixture)


# 3. Un projectile visuel en vol est detruit avec son ancienne scene, sans
# callback tardif ni dependance a son ancien SceneTree.
func test_projectile_travel_is_cancelled_with_its_scene_parent() -> void:
	var old_scene := Node2D.new()
	add_child(old_scene)
	var projectile = ProjectileScene.instantiate()
	old_scene.add_child(projectile)
	projectile.initialiser(Vector2.ZERO, Vector2(400.0, 0.0))
	await wait_process_frames(1)
	remove_child(old_scene)
	await get_tree().create_timer(0.30).timeout
	assert_true(is_instance_valid(projectile))
	assert_true(projectile._finished)
	assert_eq(get_tree().get_nodes_in_group("skeleton_ranged_projectiles").size(), 0)
	old_scene.free()


# 4. La derniere unite peut mourir pendant Death puis quitter la scene avant le
# signal de fin sans appeler get_tree() sur une instance detachee.
func test_last_enemy_dies_during_death_animation_then_scene_closes() -> void:
	var enemy := Factory.make_unit("Dernier ennemi", 1)
	var controlled := _make_controlled_view(enemy)
	enemy.take_damage(999)
	await wait_process_frames(1)
	remove_child(controlled.view)
	await wait_process_frames(2)
	assert_true(is_instance_valid(controlled.view))
	assert_false(controlled.view.is_inside_tree())
	controlled.view.free()
	enemy.clear_traits()


# 5. Si la mort ferme la salle avant le marqueur d'impact, aucun degat melee
# ne doit etre applique apres coup.
func test_last_enemy_dies_before_melee_impact_signal() -> void:
	var fixture := _make_runner_fixture(false)
	var state := {"done": false}
	_capture_attack(fixture.runner, fixture.attacker, fixture.target, state)
	await wait_process_frames(1)
	fixture.battle._battle_over = true
	fixture.runner.cancel_pending_actions()
	fixture.view.cancel_pending_visual_actions()
	fixture.visual.release()
	await wait_process_frames(3)
	assert_true(state.done)
	assert_eq(fixture.target.current_hp, 100)
	_cleanup_fixture(fixture)


# 6. Retirer un UnitView pendant prepare_basic_attack_visual doit retourner
# false proprement, sans acces a un SceneTree null.
func test_unit_view_removed_during_prepare_basic_attack() -> void:
	var unit := Factory.make_unit("Attaquant detache", 1)
	unit.grid_pos = Vector2i.ZERO
	var controlled := _make_controlled_view(unit)
	var state := {"done": false, "result": true}
	_capture_basic_prepare(controlled.view, state)
	await wait_process_frames(1)
	remove_child(controlled.view)
	await wait_process_frames(2)
	assert_true(state.done)
	assert_false(state.result)
	controlled.view.free()
	unit.clear_traits()


# 7. Retirer un UnitView pendant l'attente de recuperation doit annuler la
# recuperation et rendre la main sans erreur.
func test_unit_view_removed_during_recovery_wait() -> void:
	var unit := Factory.make_unit("Attaquant en recuperation", 1)
	unit.grid_pos = Vector2i.ZERO
	var controlled := _make_controlled_view(unit)
	var state := {
		"done": false,
		"released": false,
		"recovery_started": false,
	}
	_capture_recovery(controlled.view, state)
	await wait_process_frames(1)
	controlled.visual.release()
	await wait_process_frames(2)
	assert_true(state.recovery_started)
	remove_child(controlled.view)
	await wait_process_frames(2)
	assert_true(state.done)
	controlled.view.free()
	unit.clear_traits()


# 8. Detacher toute la Battle pendant un tour ennemi annule a la fois le runner
# et le UnitView qui attend son marqueur artistique.
func test_battle_removed_during_enemy_turn_cancels_all_waiters() -> void:
	var fixture := _make_runner_fixture(false)
	var state := {"done": false}
	_capture_attack(fixture.runner, fixture.attacker, fixture.target, state)
	await wait_process_frames(1)
	remove_child(fixture.battle)
	await wait_process_frames(3)
	assert_true(state.done)
	assert_true(fixture.runner.is_closing())
	assert_eq(fixture.target.current_hp, 100)
	_cleanup_fixture(fixture)


# 9. Les chemins corriges ne recuperent jamais SceneTree directement apres un
# await appartenant a une scene ephemere.
func test_async_sources_use_guarded_scene_tree_waits() -> void:
	var unit_view_source := FileAccess.get_file_as_string("res://battle/unit_view.gd")
	var runner_source := FileAccess.get_file_as_string("res://battle/enemy_turn_runner.gd")
	var battle_source := FileAccess.get_file_as_string("res://battle/battle.gd")
	assert_false("await get_tree().process_frame" in unit_view_source)
	assert_false("await get_tree().create_timer" in runner_source)
	assert_true("GameManager.schedule_battle_outcome" in battle_source)
	var end_section := battle_source.substr(battle_source.find("func _end_battle"))
	end_section = end_section.substr(0, end_section.find("func _show_end_screen"))
	assert_false("await " in end_section)


# 10. Une Action engagee dans l'ancienne salle ne peut ni toucher son ancienne
# cible apres fermeture, ni une unite nouvellement creee dans la salle suivante.
func test_old_room_ranged_action_cannot_affect_next_room() -> void:
	var fixture := _make_runner_fixture(true)
	var next_room_target := Factory.make_unit("Cible salle suivante", 0)
	var state := {"done": false}
	_capture_cast(
		fixture.runner,
		fixture.attacker,
		fixture.attacker.spells[0],
		fixture.target_cell,
		state
	)
	await wait_process_frames(1)
	fixture.visual.release()
	await wait_process_frames(2)
	assert_eq(fixture.target.current_hp, 100)
	fixture.battle._battle_over = true
	fixture.runner.cancel_pending_actions()
	fixture.view.cancel_pending_visual_actions()
	await get_tree().create_timer(0.27).timeout
	assert_true(state.done)
	assert_eq(fixture.target.current_hp, 100)
	assert_eq(next_room_target.current_hp, 100)
	_cleanup_fixture(fixture)
	next_room_target.clear_traits()
