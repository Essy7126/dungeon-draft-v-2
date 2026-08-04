extends Node

const RUN := preload("res://data/runs/first_run.tres")
const OUTPUT_PATH := "res://artifacts/first_run_v2/room_six_performance.json"
const SAMPLE_SECONDS := 7.0

var _battle: Node = null
var _elapsed := 0.0
var _samples: Array[float] = []
var _memory_samples: Array[int] = []
var _summons_resolved := 0
var _animations_triggered := 0
var _baseline_nodes := 0
var _baseline_memory := 0
var _peak_nodes := 0
var _peak_telegraphs := 0
var _finished := false


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(
		RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	):
		_fail("initialisation de la run impossible")
		return
	GameManager.current_room_index = 5
	_battle = (RUN.rooms[5] as RoomData).battle_scene.instantiate()
	add_child(_battle)
	for _frame in 6:
		await get_tree().process_frame
	if _enemy_count() != 8:
		_fail("la salle 6 ne contient pas huit ennemis initiaux")
		return
	_install_telegraph_layer()
	for summon_index in 2:
		if not _resolve_normal_summon(summon_index):
			_fail("invocation de stress %d non resolue" % (summon_index + 1))
			return
	_emit_stress_telegraph()
	_trigger_animation_wave(&"walk")
	await get_tree().create_timer(1.0).timeout
	_baseline_nodes = _tree_node_count()
	_baseline_memory = OS.get_static_memory_usage()
	_peak_nodes = _baseline_nodes
	set_process(true)


func _process(delta: float) -> void:
	if _finished or _baseline_nodes == 0:
		return
	_elapsed += delta
	_samples.append(1.0 / maxf(delta, 0.000001))
	_memory_samples.append(OS.get_static_memory_usage())
	_peak_nodes = maxi(_peak_nodes, _tree_node_count())
	var layer := _battle.get("_tactical_telegraphs") as TacticalTelegraphLayer
	if layer != null:
		_peak_telegraphs = maxi(_peak_telegraphs, layer.get_telegraph_count())
	if _elapsed >= 1.5 and _elapsed - delta < 1.5:
		_trigger_animation_wave(&"attack")
	if _elapsed >= 3.0 and _elapsed - delta < 3.0:
		_trigger_animation_wave(&"hit")
	if _elapsed >= 4.5 and _elapsed - delta < 4.5:
		_trigger_animation_wave(&"spell")
	if _elapsed >= SAMPLE_SECONDS:
		_finish()


func _resolve_normal_summon(centurion_index: int) -> bool:
	var centurions: Array = _battle.units.filter(func(value):
		return value != null \
			and (value as Unit).tactical_role_id == &"skeleton_centurion"
	)
	if centurion_index >= centurions.size():
		return false
	var centurion := centurions[centurion_index] as Unit
	var spell := _find_spell(centurion, &"call_bones")
	if spell == null:
		return false
	centurion.start_turn()
	var target := Vector2i(-1, -1)
	for cell_value in _battle.spell_caster.get_targetable_cells(centurion, spell):
		var cell := cell_value as Vector2i
		if _battle.grid.is_walkable(cell) and not _battle.grid.has_unit(cell):
			target = cell
			break
	if target == Vector2i(-1, -1):
		return false
	var cast_report: Dictionary = _battle.spell_caster.cast(centurion, spell, target)
	if cast_report.get("failed", false) or not cast_report.get("telegraphed", false):
		return false
	centurion.start_turn()
	var resolved: Dictionary = _battle.spell_caster.resolve_pending_activation(
		centurion,
		_battle.units,
		null,
		_battle._on_summoned_unit_spawned,
	)
	if resolved.get("resolved", false):
		_summons_resolved += 1
	return resolved.get("resolved", false)


func _install_telegraph_layer() -> void:
	var layer := TacticalTelegraphLayer.new()
	_battle.grid_view.add_child(layer)
	layer.setup(_battle.grid_view)
	_battle.set("_tactical_telegraphs", layer)


func _emit_stress_telegraph() -> void:
	var chief := _battle.units.filter(func(value):
		return value != null and (value as Unit).tactical_role_id == &"skeleton_chief"
	)[0] as Unit
	var spell := _find_spell(chief, &"scarlet_sentence")
	EventBus.ability_telegraphed.emit(chief, spell, {
		"cell": chief.grid_pos + Vector2i.RIGHT,
		"label": spell.telegraph_label,
		"color": spell.telegraph_color,
	})


func _trigger_animation_wave(kind: StringName) -> void:
	var views := (_battle.get("_unit_views") as Dictionary).values()
	for view_value in views:
		var view := view_value as Node
		if view == null:
			continue
		var visual := view.get("_optional_visual") as Node
		if visual == null:
			continue
		match kind:
			&"walk":
				if visual.has_method("play_walk"):
					visual.play_walk()
					_animations_triggered += 1
			&"attack":
				if visual.has_method("play_basic_attack"):
					visual.play_basic_attack()
					_animations_triggered += 1
			&"hit":
				if visual.has_method("play_hit"):
					visual.play_hit()
					_animations_triggered += 1
			&"spell":
				var unit := _unit_for_view(view)
				if unit != null and not unit.spells.is_empty() \
						and visual.has_method("play_spell_action"):
					visual.play_spell_action(unit.spells[0])
					_animations_triggered += 1


func _unit_for_view(searched: Node) -> Unit:
	for unit_value in (_battle.get("_unit_views") as Dictionary):
		if (_battle.get("_unit_views") as Dictionary)[unit_value] == searched:
			return unit_value as Unit
	return null


func _find_spell(unit: Unit, spell_id: StringName) -> Spell:
	for spell_value in unit.spells:
		var spell := spell_value as Spell
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null


func _enemy_count() -> int:
	return _battle.units.filter(func(value):
		return value != null and (value as Unit).team == 1 and (value as Unit).is_alive
	).size()


func _tree_node_count() -> int:
	return _count_nodes(get_tree().root)


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _finish() -> void:
	_finished = true
	set_process(false)
	var average := 0.0
	var minimum := INF
	for sample in _samples:
		average += sample
		minimum = minf(minimum, sample)
	average /= float(maxi(1, _samples.size()))
	var final_nodes := _tree_node_count()
	var final_memory := OS.get_static_memory_usage()
	var memory_peak := _baseline_memory
	for value in _memory_samples:
		memory_peak = maxi(memory_peak, value)
	var report := {
		"resolution": [1920, 1080],
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"duration_seconds": _elapsed,
		"samples": _samples.size(),
		"average_fps": average,
		"minimum_fps": minimum if not _samples.is_empty() else 0.0,
		"initial_enemies": 8,
		"summons_resolved": _summons_resolved,
		"peak_enemies": _enemy_count(),
		"peak_active_telegraphs": _peak_telegraphs,
		"animations_triggered": _animations_triggered,
		"baseline_nodes": _baseline_nodes,
		"peak_nodes": _peak_nodes,
		"final_nodes": final_nodes,
		"node_growth": final_nodes - _baseline_nodes,
		"baseline_memory_bytes": _baseline_memory,
		"peak_memory_bytes": memory_peak,
		"final_memory_bytes": final_memory,
		"memory_growth_bytes": final_memory - _baseline_memory,
	}
	report.passed = average >= 60.0 \
		and float(report.minimum_fps) >= 30.0 \
		and _summons_resolved == 2 \
		and int(report.peak_enemies) == 10 \
		and _peak_telegraphs >= 1 \
		and _animations_triggered >= 10 \
		and int(report.node_growth) <= 4 \
		and int(report.memory_growth_bytes) <= 8 * 1024 * 1024
	var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	print("ROOM_SIX_PERFORMANCE=" + JSON.stringify(report))
	get_tree().quit(0 if report.passed and output != null else 1)


func _fail(message: String) -> void:
	push_error("PERFORMANCE SALLE 6: %s" % message)
	get_tree().quit(1)
