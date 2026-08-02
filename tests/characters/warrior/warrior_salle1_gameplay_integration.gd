extends Node

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_PATH := "res://data/units/alliés/mage.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const ROOM_PATH := "res://data/rooms/first_run_room_01.tres"
const PARTY_SCENE := preload("res://ui/party/PartyPresentationScreen.tscn")
const SCREENSHOT_DIR := "res://tests/characters/warrior/screenshots"
const REPORT_PATH := "C:/Blender_AI_Test/Output/godot_warrior_first_playable_integration.json"
const CENTER := Vector2i(5, 4)

@onready var battle = $Battle

var elf: Unit
var mage: Unit
var warrior: Unit
var warrior_view: Node2D
var warrior_iso: WarriorIsoUnitView
var reference_enemy: Unit
var reference_enemy_view: Node2D
var _screenshots: Array[String] = []
var _errors: Array[String] = []
var _warnings: Array[String] = []
var _damage_events := 0
var _spell_cast_events := 0
var _release_events := 0


func _enter_tree() -> void:
	GameManager.cleanup_run_state()
	elf = Unit.from_data(load(ELF_PATH) as UnitData)
	mage = Unit.from_data(load(MAGE_PATH) as UnitData)
	warrior = Unit.from_data(load(WARRIOR_PATH) as UnitData)
	GameManager.heroes = [elf, mage, warrior]
	GameManager.rooms = [load(ROOM_PATH) as RoomData]
	GameManager.current_room_index = 0
	GameManager.run_active = true


func _ready() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.spell_cast.connect(_on_spell_cast)
	await get_tree().process_frame
	if not await _deploy_party():
		push_error("Warrior salle 1: deployment failed")
		return
	if "--warrior-auto-review" in OS.get_cmdline_user_args():
		await _run_review()
		get_tree().quit(0 if _errors.is_empty() else 21)
		return
	_select_warrior_idle()


func _exit_tree() -> void:
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	if EventBus.spell_cast.is_connected(_on_spell_cast):
		EventBus.spell_cast.disconnect(_on_spell_cast)


func _deploy_party() -> bool:
	for cell in [Vector2i(9, 7), Vector2i(8, 7), Vector2i(7, 7)]:
		if battle._deployment == null or not battle._deployment.is_active():
			return false
		battle._deployment.on_cell_clicked(cell)
		await get_tree().process_frame
	warrior_view = battle._unit_views.get(warrior) as Node2D
	if warrior_view == null or not warrior_view.has_method("get_optional_visual"):
		return false
	warrior_iso = warrior_view.get_optional_visual() as WarriorIsoUnitView
	if warrior_iso == null:
		return false
	warrior_iso.cast_release_reached.connect(func(): _release_events += 1)
	var enemies: Array = battle.units.filter(func(unit): return unit != null and unit.team == 1)
	if enemies.is_empty():
		return false
	reference_enemy = enemies[0] as Unit
	reference_enemy_view = battle._unit_views.get(reference_enemy) as Node2D
	return is_instance_valid(reference_enemy_view)


func _run_review() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))
	_validate_structure()
	await _capture_party_presentation()
	_select_warrior_idle()
	await _capture("first_run_elf_mage_warrior.png")
	await _capture("warrior_idle_iso.png")
	var idle_quality := await _measure_idle_quality()
	var movement := await _review_movement()
	var y_sort := await _review_y_sort()
	var basic_attack := await _review_basic_attack()
	var spells := await _review_all_spells()
	var hit := await _review_hit()
	var performance := await _review_performance()
	var death := await _review_death()
	var report := {
		"verdict": "WARRIOR_FIRST_PLAYABLE_INTEGRATION_COMPLETE" if _errors.is_empty() and _warnings.is_empty() else (
			"WARRIOR_FIRST_PLAYABLE_INTEGRATION_COMPLETE_WITH_WARNINGS" if _errors.is_empty() else "WARRIOR_FIRST_PLAYABLE_INTEGRATION_BLOCKED"
		),
		"party_order": [elf.unit_id, mage.unit_id, warrior.unit_id],
		"party_names": [elf.unit_name, mage.unit_name, warrior.unit_name],
		"warrior_selected": bool(warrior_view.get("_is_active")) if is_instance_valid(warrior_view) else false,
		"structure": _structure_snapshot(),
		"idle_quality": idle_quality,
		"movement": movement,
		"y_sort": y_sort,
		"basic_attack": basic_attack,
		"spells": spells,
		"hit": hit,
		"death": death,
		"performance": performance,
		"screenshots": _screenshots,
		"errors": _errors,
		"warnings": _warnings,
	}
	_write_json(REPORT_PATH, report)
	print("WARRIOR_SALLE1_RESULT=", JSON.stringify(report))


func _select_warrior_idle() -> void:
	if not is_instance_valid(warrior_view) or not is_instance_valid(warrior_iso):
		return
	battle._on_cell_clicked(warrior.grid_pos)
	warrior_view.set_active(true)
	warrior_iso.cancel_spell_action()
	warrior_iso.play_idle()


func _validate_structure() -> void:
	if battle._unit_view_parent == null or battle._unit_view_parent.name != "YSortedWorld":
		_errors.append("UnitView parent is not YSortedWorld")
	elif not battle._unit_view_parent.y_sort_enabled:
		_errors.append("YSortedWorld does not have y_sort_enabled")
	if warrior_view.get_parent() != battle._unit_view_parent:
		_errors.append("Warrior UnitView is not a direct child of YSortedWorld")
	if warrior_iso.get_parent() != warrior_view or warrior_iso.position != Vector2.ZERO:
		_errors.append("WarriorIsoUnitView is not local at Vector2.ZERO")
	if warrior_view.z_index != 0 or warrior_iso.render_sprite.z_index != 0:
		_errors.append("Fixed z_index found on Warrior")
	if warrior_iso.get_logical_foot_position() != Vector2.ZERO:
		_errors.append("Warrior logical foot pivot is not Vector2.ZERO")
	if warrior_iso.character_viewport.size != Vector2i(768, 512):
		_errors.append("Warrior SubViewport is not 768x512")
	if warrior_iso.character_viewport.msaa_3d != Viewport.MSAA_4X:
		_errors.append("Warrior MSAA is not 4X")
	if warrior_iso.character_viewport.use_taa:
		_errors.append("Warrior TAA is enabled")
	if warrior_iso.character_viewport.screen_space_aa != Viewport.SCREEN_SPACE_AA_DISABLED:
		_errors.append("Warrior FXAA is enabled")
	var placeholder := warrior_view.get_node_or_null("IsoTemporaryPlaceholder") as CanvasItem
	if placeholder == null or placeholder.visible:
		_errors.append("Historical placeholder is missing or still visible")


func _structure_snapshot() -> Dictionary:
	return {
		"unit_view_parent": battle._unit_view_parent.name if battle._unit_view_parent else "",
		"y_sort_enabled": battle._unit_view_parent.y_sort_enabled if battle._unit_view_parent else false,
		"warrior_view_parent": warrior_view.get_parent().name if is_instance_valid(warrior_view) else "freed_after_death",
		"iso_local_position": _vec2(warrior_iso.position) if is_instance_valid(warrior_iso) else [0, 0],
		"unit_view_z_index": warrior_view.z_index if is_instance_valid(warrior_view) else 0,
		"iso_z_index": warrior_iso.z_index if is_instance_valid(warrior_iso) else 0,
		"viewport": [768, 512],
	}


func _capture_party_presentation() -> void:
	var screen := PARTY_SCENE.instantiate()
	add_child(screen)
	await _wait_frames(5)
	var cards: Array = screen.get_cards()
	if cards.size() != 3 or cards[2].character_data.unit_id != &"warrior":
		_errors.append("Party presentation third slot is not warrior")
	await _capture("warrior_draft_third_slot.png")
	remove_child(screen)
	screen.free()
	await _wait_frames(2)


func _measure_idle_quality() -> Dictionary:
	await _wait_frames(5)
	await RenderingServer.frame_post_draw
	var image := warrior_iso.character_viewport.get_texture().get_image()
	var bounds := _alpha_bounds(image)
	var ratio := float(bounds.size.y) / float(maxi(1, image.get_height()))
	if ratio < 0.70 or ratio > 0.80:
		_errors.append("Idle occupancy %.3f is outside 70-80%%" % ratio)
	return {
		"bounds": _rect(bounds),
		"height_ratio": ratio,
		"camera_size": warrior_iso.camera_orthographic_size,
		"character_scale": warrior_iso.character_scale,
		"filter": warrior_iso.render_sprite.texture_filter,
		"display_scale": _vec2(warrior_iso.render_sprite.scale),
	}


func _review_movement() -> Dictionary:
	var results := []
	var capture_names := {
		Vector2i.RIGHT: "warrior_walk_pos_x.png",
		Vector2i.LEFT: "warrior_walk_neg_x.png",
		Vector2i.DOWN: "warrior_walk_pos_y.png",
		Vector2i.UP: "warrior_walk_neg_y.png",
	}
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		_force_relocate(warrior, CENTER, warrior_view)
		warrior_iso.cancel_movement_feedback()
		warrior_iso.play_idle()
		var from := warrior.grid_pos
		var to: Vector2i = from + direction
		var before_iso := warrior_iso.position
		if not battle.grid.relocate_unit(warrior, to):
			_errors.append("Cannot relocate Warrior for %s" % direction)
			continue
		battle._animate_move(warrior, [from, to])
		await get_tree().create_timer(0.075).timeout
		var active_animation := warrior_iso.get_warrior_visual().get_current_animation()
		await _capture(capture_names[direction])
		await get_tree().create_timer(0.30).timeout
		var expected: Vector2 = battle.grid_cell_to_parent_local(to, warrior_view.get_parent())
		var final_error := warrior_view.position.distance_to(expected)
		if final_error > 0.01:
			_errors.append("Movement did not end on cell %s" % to)
		if warrior_iso.position != before_iso:
			_errors.append("WarriorIsoUnitView moved its local root during movement")
		results.append({
			"direction": [direction.x, direction.y],
			"animation": active_animation,
			"final_position_error": final_error,
			"iso_local_root_stable": warrior_iso.position == before_iso,
		})
	_force_relocate(warrior, CENTER, warrior_view)
	warrior_iso.cancel_movement_feedback()
	warrior_iso.play_idle()
	return {"directions": results}


func _review_y_sort() -> Dictionary:
	var candidates: Array[Vector2i] = []
	for y in battle.grid.rows:
		for x in battle.grid.cols:
			var cell := Vector2i(x, y)
			if battle.grid.is_walkable(cell):
				candidates.append(cell)
	candidates.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return battle.grid_cell_to_parent_local(a, warrior_view.get_parent()).y \
				< battle.grid_cell_to_parent_local(b, warrior_view.get_parent()).y
	)
	var behind_cell: Vector2i = candidates.front()
	var front_cell: Vector2i = candidates.back()
	var reference_cell: Vector2i = candidates[candidates.size() / 2]
	_force_relocate(reference_enemy, reference_cell, reference_enemy_view)
	_force_relocate(warrior, behind_cell, warrior_view)
	await _wait_frames(3)
	var behind_y := warrior_view.position.y
	var reference_y := reference_enemy_view.position.y
	var behind := warrior_view.position.y < reference_enemy_view.position.y
	await _capture("warrior_y_sort_behind.png")
	_force_relocate(warrior, front_cell, warrior_view)
	await _wait_frames(3)
	var front_y := warrior_view.position.y
	var front := warrior_view.position.y > reference_enemy_view.position.y
	await _capture("warrior_y_sort_front.png")
	if not behind or not front:
		_errors.append("Y-sort front/behind ordering is inconsistent")
	return {
		"behind": behind,
		"front": front,
		"behind_cell": [behind_cell.x, behind_cell.y],
		"front_cell": [front_cell.x, front_cell.y],
		"reference_cell": [reference_cell.x, reference_cell.y],
		"behind_y": behind_y,
		"reference_y": reference_y,
		"front_y": front_y,
		"y_sort_enabled": battle._unit_view_parent.y_sort_enabled,
	}


func _review_basic_attack() -> Dictionary:
	_prepare_warrior_and_enemy(false)
	_activate_warrior_turn()
	warrior.current_ap = 100
	var unit_root := warrior_view.global_position
	var iso_root := warrior_iso.global_position
	var damage_before := _damage_events
	await battle._on_request_attack(reference_enemy.grid_pos)
	await _capture("warrior_basic_attack.png")
	var damage_delta := _damage_events - damage_before
	var unit_stable := warrior_view.global_position.distance_to(unit_root) <= 0.01
	var iso_stable := warrior_iso.global_position.distance_to(iso_root) <= 0.01
	if damage_delta != 1:
		_errors.append("Basic Attack damage event count is %d, expected 1" % damage_delta)
	if not unit_stable or not iso_stable:
		_errors.append("Basic Attack left a visual root displaced")
	var result := {
		"damage_events": damage_delta,
		"animation": warrior_iso.get_warrior_visual().get_current_animation(),
		"unit_root_stable_after_bump": unit_stable,
		"iso_root_stable_after_bump": iso_stable,
	}
	warrior_iso.cancel_spell_action()
	return result


func _review_all_spells() -> Array:
	var results := []
	for spell_value in (load(WARRIOR_PATH) as UnitData).spells:
		var spell := spell_value as Spell
		_prepare_warrior_and_enemy(spell.is_self_only())
		_activate_warrior_turn()
		warrior.current_ap = 100
		battle._spell_resolution_pending = false
		warrior_iso.cancel_spell_action()
		var target_cell := warrior.grid_pos if spell.is_self_only() else reference_enemy.grid_pos
		var expected_animation := warrior_iso.get_warrior_visual().get_animation_for_spell(spell)
		var damage_before := _damage_events
		var cast_before := _spell_cast_events
		var release_before := _release_events
		var unit_root := warrior_view.global_position
		var iso_root := warrior_iso.global_position
		var started := Time.get_ticks_msec()
		await battle._on_request_cast_spell(spell, target_cell, false)
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		var item := {
			"resource": spell.resource_path,
			"name": spell.spell_name,
			"expected_animation": expected_animation,
			"active_animation_at_impact": warrior_iso.get_warrior_visual().get_current_animation(),
			"release_events": _release_events - release_before,
			"spell_cast_events": _spell_cast_events - cast_before,
			"reference_target_damage_events": _damage_events - damage_before,
			"elapsed_seconds": elapsed,
			"unit_root_stable": warrior_view.global_position.distance_to(unit_root) <= 0.01,
			"iso_root_stable": warrior_iso.global_position.distance_to(iso_root) <= 0.01,
			"pending_after": battle._spell_resolution_pending,
		}
		if item.release_events != 1:
			_errors.append("%s emitted %d cast releases" % [spell.spell_name, item.release_events])
		if item.spell_cast_events != 1:
			_errors.append("%s resolved %d gameplay casts" % [spell.spell_name, item.spell_cast_events])
		var expected_target_damage_events := 1
		if spell.collision_damage > 0 and spell.push_distance > 0:
			expected_target_damage_events += 1
		if spell.damage > 0 and item.reference_target_damage_events != expected_target_damage_events:
			_errors.append("%s produced %d target damage events; expected %d including intended collision damage" % [
				spell.spell_name,
				item.reference_target_damage_events,
				expected_target_damage_events,
			])
		if item.elapsed_seconds > 5.0:
			_errors.append("%s blocked for %.3f seconds" % [spell.spell_name, item.elapsed_seconds])
		if not item.unit_root_stable or not item.iso_root_stable:
			_errors.append("%s displaced a Warrior visual root" % spell.spell_name)
		var legitimate_hit_interrupt: bool = (
			item.active_animation_at_impact == WarriorVisual3D.ANIM_HIT
			and item.release_events == 1
			and spell.aoe_shape != Spell.AoeShape.SINGLE
		)
		item["legitimate_hit_interrupt"] = legitimate_hit_interrupt
		if item.active_animation_at_impact != expected_animation and not legitimate_hit_interrupt:
			_errors.append("%s did not use its profiled animation" % spell.spell_name)
		results.append(item)
		if results.size() == 4:
			await _capture("warrior_spell_action.png")
		warrior_iso.cancel_spell_action()
		await get_tree().create_timer(0.08).timeout
	var vfx_layer := battle.get_node_or_null("VFXLayer")
	if vfx_layer != null and vfx_layer.get_child_count() != 0:
		_errors.append("Residual VFX remain after Warrior spell review")
	if (load(WARRIOR_PATH) as UnitData).spells.all(func(spell): return spell.vfx_scene == null):
		_warnings.append("The eight Warrior spells currently have no dedicated vfx_scene; gameplay and cleanup were validated with an empty VFX layer.")
	return results


func _review_hit() -> Dictionary:
	_prepare_warrior_and_enemy(false)
	warrior_iso.cancel_spell_action()
	var hp_before := warrior.current_hp
	warrior.take_damage(1, reference_enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE)
	await get_tree().create_timer(0.25).timeout
	var animation := warrior_iso.get_warrior_visual().get_current_animation()
	await _capture("warrior_hit.png")
	if animation != WarriorVisual3D.ANIM_HIT:
		_errors.append("Real damage did not trigger Warrior Hit")
	await get_tree().create_timer(1.1).timeout
	var returned_idle := warrior_iso.get_warrior_visual().get_current_animation() == WarriorVisual3D.ANIM_IDLE
	if not returned_idle:
		_errors.append("Warrior Hit did not return to Idle while alive")
	return {"hp_delta": hp_before - warrior.current_hp, "animation": animation, "returned_idle": returned_idle}


func _review_performance() -> Dictionary:
	_force_relocate(warrior, CENTER, warrior_view)
	var elf_view = battle._unit_views.get(elf)
	var mage_view = battle._unit_views.get(mage)
	for view in [elf_view, mage_view, warrior_view]:
		if is_instance_valid(view) and view.has_method("get_optional_visual"):
			var optional = view.get_optional_visual()
			if is_instance_valid(optional) and optional.has_method("play_idle"):
				optional.play_idle()
	var idle := await _sample_fps(0.6)
	for view in [elf_view, mage_view, warrior_view]:
		if is_instance_valid(view) and view.has_method("get_optional_visual"):
			var optional = view.get_optional_visual()
			if is_instance_valid(optional) and optional.has_method("play_walk"):
				optional.play_walk()
	var movement := await _sample_fps(0.6)
	warrior_iso.play_basic_attack()
	var attack := await _sample_fps(0.6)
	warrior_iso.cancel_spell_action()
	var multiple_enemies := await _sample_fps(0.6)
	return {
		"idle_trio": idle,
		"three_visuals_movement": movement,
		"warrior_attack": attack,
		"multiple_enemies_present": multiple_enemies,
		"subviewport_count": get_tree().current_scene.find_children("*", "SubViewport", true, false).size(),
		"approximate_visible_triangles": _count_visible_triangles(),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
	}


func _review_death() -> Dictionary:
	_prepare_warrior_and_enemy(false)
	warrior_iso.cancel_spell_action()
	warrior_iso.play_idle()
	await _wait_frames(3)
	var old_cell := warrior.grid_pos
	var unit_root := warrior_view.global_position
	var iso_root := warrior_iso.global_position
	var finished := {"value": false}
	warrior_iso.death_animation_finished.connect(func(): finished.value = true, CONNECT_ONE_SHOT)
	warrior.take_damage(warrior.current_hp + 1000, reference_enemy, Spell.DamageType.PHYSICAL, Spell.Element.NONE)
	var unit_max_delta := 0.0
	var iso_max_delta := 0.0
	var visual_present_until_finished := true
	var started := Time.get_ticks_msec()
	var captured := false
	var death_fps_samples: Array[float] = []
	while not finished.value and Time.get_ticks_msec() - started < 5000:
		if not is_instance_valid(warrior_view) or not is_instance_valid(warrior_iso):
			visual_present_until_finished = false
			break
		unit_max_delta = maxf(unit_max_delta, warrior_view.global_position.distance_to(unit_root))
		iso_max_delta = maxf(iso_max_delta, warrior_iso.global_position.distance_to(iso_root))
		var fps := Engine.get_frames_per_second()
		if fps > 0:
			death_fps_samples.append(fps)
		if not captured and Time.get_ticks_msec() - started >= 2500:
			await _capture("warrior_death.png")
			captured = true
		await get_tree().process_frame
	var old_cell_released: bool = battle.grid.get_unit(old_cell) != warrior
	var logical_cell_invalid: bool = warrior.grid_pos == Vector2i(-1, -1) or not battle.grid.is_valid(warrior.grid_pos)
	if not old_cell_released:
		_errors.append("Warrior death did not release the old grid cell")
	if not logical_cell_invalid:
		_errors.append("Warrior logical cell is not invalid after death")
	if unit_max_delta > 0.01 or iso_max_delta > 0.01:
		_errors.append("A Warrior visual root moved during Death")
	if not visual_present_until_finished or not finished.value:
		_errors.append("Warrior visual disappeared or Death did not finish")
	_warnings.append("Death retains a vertical Hips fall of about 0.638 m; the production Action removes the original 0.693 m horizontal drift.")
	return {
		"old_cell": [old_cell.x, old_cell.y],
		"logical_cell_after": [warrior.grid_pos.x, warrior.grid_pos.y],
		"old_cell_released": old_cell_released,
		"logical_cell_invalid": logical_cell_invalid,
		"unit_view_max_root_delta": unit_max_delta,
		"warrior_iso_max_root_delta": iso_max_delta,
		"visual_present_until_finished": visual_present_until_finished,
		"death_animation_finished": finished.value,
		"duration_seconds": float(Time.get_ticks_msec() - started) / 1000.0,
		"fps": _summarize_fps(death_fps_samples),
	}


func _prepare_warrior_and_enemy(self_target: bool) -> void:
	_force_relocate(warrior, CENTER, warrior_view)
	_force_relocate(reference_enemy, CENTER + Vector2i.RIGHT, reference_enemy_view)
	reference_enemy.current_hp = 10000
	warrior_iso.set_facing(Vector2i.RIGHT)
	if self_target:
		warrior_iso.set_facing(Vector2i.RIGHT)
	await get_tree().process_frame


func _activate_warrior_turn() -> void:
	var order: Array = battle.turn_queue.get_full_order()
	var index := order.find(warrior)
	if index < 0:
		_errors.append("Warrior absent from TurnQueue")
		return
	battle.turn_queue._current_index = index
	warrior.start_turn()
	battle._on_turn_started(warrior)


func _force_relocate(unit: Unit, cell: Vector2i, view: Node2D) -> bool:
	var occupant = battle.grid.get_unit(cell)
	if occupant != null and occupant != unit:
		var spare := _find_spare_cell([cell, unit.grid_pos])
		if spare == Vector2i(-1, -1):
			return false
		var occupant_view = battle._unit_views.get(occupant) as Node2D
		if not battle.grid.relocate_unit(occupant, spare):
			return false
		if is_instance_valid(occupant_view):
			occupant_view.position = battle.grid_cell_to_parent_local(spare, occupant_view.get_parent())
	if not battle.grid.relocate_unit(unit, cell):
		return false
	view.position = battle.grid_cell_to_parent_local(cell, view.get_parent())
	return true


func _find_spare_cell(excluded: Array) -> Vector2i:
	for y in battle.grid.rows:
		for x in battle.grid.cols:
			var cell := Vector2i(x, y)
			if cell in excluded or not battle.grid.is_walkable(cell) or battle.grid.has_unit(cell):
				continue
			return cell
	return Vector2i(-1, -1)


func _sample_fps(duration_seconds: float) -> Dictionary:
	var samples: Array[float] = []
	var deadline := Time.get_ticks_msec() + int(duration_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var fps := Engine.get_frames_per_second()
		if fps > 0:
			samples.append(fps)
		await get_tree().process_frame
	return _summarize_fps(samples)


func _summarize_fps(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {"average": 0.0, "minimum": 0.0, "samples": 0}
	var total := 0.0
	var minimum := INF
	for sample in samples:
		total += sample
		minimum = minf(minimum, sample)
	return {"average": total / samples.size(), "minimum": minimum, "samples": samples.size()}


func _count_visible_triangles() -> int:
	var total := 0
	for node in get_tree().current_scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.visible or mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			total += arrays[Mesh.ARRAY_INDEX].size() / 3
	return total


func _on_damage_dealt(target, attacker, _amount: int, _category: int, _element: int, _is_crit: bool) -> void:
	if target == reference_enemy and attacker == warrior:
		_damage_events += 1


func _on_spell_cast(caster, _spell, _report: Dictionary) -> void:
	if caster == warrior:
		_spell_cast_events += 1


func _capture(filename: String) -> String:
	await RenderingServer.frame_post_draw
	var resource_path := "%s/%s" % [SCREENSHOT_DIR, filename]
	var result := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(resource_path))
	if result != OK:
		_errors.append("Screenshot failed: %s (%d)" % [filename, result])
		return ""
	_screenshots.append(resource_path)
	return resource_path


func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _alpha_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("Cannot write %s" % path)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()


func _vec2(value: Vector2) -> Array:
	return [value.x, value.y]


func _rect(value: Rect2i) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
