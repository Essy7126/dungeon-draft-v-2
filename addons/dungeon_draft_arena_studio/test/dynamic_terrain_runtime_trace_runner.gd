extends Node

const RUN: RunData = preload("res://data/runs/first_run.tres")
const OUTPUT_PATH := "user://dungeon_draft_studio/dynamic_terrain/current_trace.json"
const TEST_OPTIONS := {
	"spawn_enemies": true,
	"spawn_heroes": true,
	"deployment_enabled": false,
	"hud_enabled": false,
	"combat_enabled": false,
	"draw_base_cells": false,
	"draw_grid_lines": true,
	"draw_cell_centers": false,
	"draw_map_bounds": false,
	"draw_logic_types": false,
	"draw_void_cells": false,
	"draw_coordinates": false,
	"draw_spawns": false,
	"draw_calibration": false,
}

var _battle: Node = null
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(
			RUN, GameManager.PRODUCTION_HERO_DATA_PATHS
		):
		_finish({"error": "run_prepare_failed"})
		return
	GameManager.current_room_index = 0
	get_tree().set_meta(&"arena_studio_test_options", TEST_OPTIONS.duplicate(true))
	var room := GameManager.get_current_room()
	if room == null or room.battle_scene == null:
		_finish({"error": "integrated_room_missing"})
		return
	var fingerprint_before := RoomDataSnapshotService.room_fingerprint(room)
	_battle = room.battle_scene.instantiate()
	add_child(_battle)
	for _frame in 12:
		await get_tree().process_frame
	var grid := _battle.get("grid") as GridData
	var caster := _battle.get("spell_caster") as SpellCaster
	var terrain := _battle.get("terrain_effects") as TerrainEffects
	if grid == null or caster == null or terrain == null:
		_finish({"error": "battle_logic_missing"})
		return
	var mage := _find_mage(grid) as Unit
	var fireball := _find_spell(mage, &"mage_fireball")
	if mage == null or fireball == null:
		_finish({"error": "mage_or_fireball_missing"})
		return
	var target := _find_full_stone_cross(caster, mage, fireball, grid)
	if target == Vector2i(-1, -1):
		_finish({"error": "full_stone_cross_missing"})
		return
	var affected: Array = caster.get_aoe_cells(fireball, target, mage.grid_pos)
	var types_before := _types_by_cell(grid, affected)
	var visuals_before := _visuals_by_cell(_battle, affected)
	mage.current_ap = mage.max_ap.get_int()
	var report: Dictionary = caster.cast(mage, fireball, target)
	for _frame in 3:
		await get_tree().process_frame
	var durations_after := _durations_by_cell(grid, affected)
	var types_after := _types_by_cell(grid, affected)
	var visuals_after := _visuals_by_cell(_battle, affected)
	var ticks: Array[Dictionary] = []
	for tick_index in range(1, 4):
		terrain.tick_all_effects()
		await get_tree().process_frame
		ticks.append({
			"tick": tick_index,
			"durations": _durations_by_cell(grid, affected),
			"types": _types_by_cell(grid, affected),
			"visuals": _visuals_by_cell(_battle, affected),
		})
	var fingerprint_after := RoomDataSnapshotService.room_fingerprint(room)
	var trace := {
		"run_path": RUN.resource_path,
		"run_name": RUN.run_name,
		"room_index": 0,
		"room_path": room.resource_path,
		"battle_scene": room.battle_scene.resource_path,
		"room_fingerprint_before": fingerprint_before,
		"room_fingerprint_after": fingerprint_after,
		"room_unchanged": fingerprint_before == fingerprint_after,
		"spell_id": str(fireball.get_effective_spell_id()),
		"spell_path": fireball.resource_path,
		"spell_cost": fireball.ap_cost,
		"spell_range": fireball.spell_range,
		"spell_aoe_shape": fireball.aoe_shape,
		"spell_aoe_size": fireball.aoe_size,
		"terrain_effect_path": fireball.terrain_effect.resource_path,
		"terrain_effect_name": fireball.terrain_effect.effect_name,
		"terrain_duration": fireball.terrain_effect.duration,
		"terrain_damage": fireball.terrain_effect.damage,
		"terrain_trigger": fireball.terrain_effect.trigger,
		"target": _key(target),
		"affected_cells": _keys(affected),
		"terrain_changed": _keys(report.get("terrain_changed", [])),
		"cast_failed": bool(report.get("failed", false)),
		"types_before": types_before,
		"types_after": types_after,
		"durations_after": durations_after,
		"visuals_before": visuals_before,
		"visuals_after": visuals_after,
		"dynamic_layer_present": _battle.find_child(
			"ArenaDynamicSurfaceLayer", true, false
		) != null,
		"ticks": ticks,
	}
	_finish(trace)


func _find_mage(grid: GridData) -> Unit:
	for value in grid.get_units():
		var unit := value as Unit
		if unit != null and unit.team == 0 and StringName(unit.unit_id) == &"mage":
			return unit
	return null


func _find_spell(unit, spell_id: StringName) -> Spell:
	if unit == null:
		return null
	for value in unit.spells:
		var spell := value as Spell
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null


func _find_full_stone_cross(
		caster: SpellCaster,
		mage,
		spell: Spell,
		grid: GridData
	) -> Vector2i:
	for value in caster.get_targetable_cells(mage, spell):
		var cell := value as Vector2i
		var affected: Array = caster.get_aoe_cells(spell, cell, mage.grid_pos)
		if affected.size() != 9:
			continue
		var valid := true
		for affected_value in affected:
			var affected_cell := affected_value as Vector2i
			if not grid.is_terrain_interactable(affected_cell) \
					or grid.get_type(affected_cell) != GridData.CellType.NORMAL:
				valid = false
				break
		if valid:
			return cell
	return Vector2i(-1, -1)


func _types_by_cell(grid: GridData, cells: Array) -> Dictionary:
	var result := {}
	for value in cells:
		var cell := value as Vector2i
		result[_key(cell)] = grid.get_type(cell)
	return result


func _durations_by_cell(grid: GridData, cells: Array) -> Dictionary:
	var result := {}
	for value in cells:
		var cell := value as Vector2i
		var stored = grid.get_effect(cell)
		result[_key(cell)] = (
			int(stored["data"].get("duration", -999)) if stored != null else null
		)
	return result


func _visuals_by_cell(scene: Node, cells: Array) -> Dictionary:
	var wanted := {}
	for value in cells:
		wanted[value as Vector2i] = true
	var result := {}
	for cell in wanted:
		result[_key(cell)] = []
	_collect_visuals(scene, wanted, result)
	return result


func _collect_visuals(node: Node, wanted: Dictionary, result: Dictionary) -> void:
	if node.has_meta("arena_cell"):
		var cell = node.get_meta("arena_cell")
		if cell is Vector2i and wanted.has(cell):
			(result[_key(cell)] as Array).append({
				"name": str(node.name),
				"class": node.get_class(),
				"visible": node.visible if node is CanvasItem else true,
				"renderer_role": str(node.get_meta("renderer_role", &"")),
				"visual_layer": str(node.get_meta("visual_layer", &"")),
				"terrain_id": str(node.get_meta("terrain_id", &"")),
			})
	for child in node.get_children():
		_collect_visuals(child, wanted, result)


func _keys(cells: Array) -> Array[String]:
	var result: Array[String] = []
	for value in cells:
		result.append(_key(value as Vector2i))
	result.sort()
	return result


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _finish(trace: Dictionary) -> void:
	trace["failures"] = _failures.duplicate()
	var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_error("DYNAMIC_TERRAIN_TRACE_WRITE_FAILED")
	else:
		file.store_string(JSON.stringify(trace, "  "))
		file.close()
	print("DYNAMIC_TERRAIN_CURRENT_TRACE=", JSON.stringify(trace))
	if get_tree().has_meta(&"arena_studio_test_options"):
		get_tree().remove_meta(&"arena_studio_test_options")
	if is_instance_valid(_battle):
		_battle.queue_free()
		await get_tree().process_frame
	GameManager.cleanup_run_state()
	get_tree().quit(0 if not trace.has("error") and _failures.is_empty() else 1)
