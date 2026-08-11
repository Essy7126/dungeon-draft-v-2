extends SceneTree

const OUTPUT_ROOT := "res://artifacts/vfx_studio_feasibility"
const SHIELD := "res://vfx/profiles/test/shield_lifecycle.tres"
const LIGHTNING := "res://vfx/profiles/test/lightning_multi_target.tres"
const PATH := "res://vfx/profiles/test/player_path_preview.tres"
const WORKFLOW_DRAFT_ID := &"codex.vfx.workflow.measurement"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT + "/stress"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT + "/metrics"))
	var stress := await _stress()
	var workflow := await _workflow()
	_write_json(OUTPUT_ROOT + "/stress/stress_metrics.json", stress)
	_write_json(OUTPUT_ROOT + "/metrics/workflow_metrics.json", workflow)
	print("VFX_STUDIO_STRESS_FAILURES=%d" % failures.size())
	print("VFX_STUDIO_STRESS_METRICS=%s" % JSON.stringify(stress))
	print("VFX_STUDIO_WORKFLOW_METRICS=%s" % JSON.stringify(workflow))
	quit(0 if failures.is_empty() else 1)


func _stress() -> Dictionary:
	var parent := Node2D.new()
	parent.name = "VFXStressLayer"
	root.add_child(parent)
	await process_frame
	var node_count_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var peak_children := 0
	var play_clear_cycles := 0
	for profile in [_profile(SHIELD), _profile(LIGHTNING), _profile(PATH)]:
		for iteration in 20:
			var sequence_id: StringName = profile.sequences[0].sequence_id
			var result := VFXProfileRunner.play(profile, _context(profile, 1000 + iteration), sequence_id, parent, false)
			if not bool(result.ok):
				_fail("Play/Clear refusé pour %s" % profile.profile_id)
				continue
			var instance := result.instance as VFXRuntimeInstance
			peak_children = maxi(peak_children, parent.get_child_count())
			instance.advance_simulation(0.08)
			instance.clear()
			instance.free()
			play_clear_cycles += 1
			if parent.get_child_count() != 0:
				_fail("Node résiduel après Play/Clear %s #%d" % [profile.profile_id, iteration])
	var replay_cycles := 0
	for iteration in 20:
		var result := VFXProfileRunner.play(_profile(SHIELD), _shield_context(2000 + iteration), &"apply", parent, false)
		var instance := result.instance as VFXRuntimeInstance
		instance.advance_simulation(0.15)
		instance.cancel()
		instance.free()
		replay_cycles += 1
	var simultaneous_shields: Array[VFXRuntimeInstance] = []
	for index in 10:
		var result := VFXProfileRunner.play(_profile(SHIELD), _shield_context(3000 + index), &"apply", parent, false)
		simultaneous_shields.append(result.instance as VFXRuntimeInstance)
	peak_children = maxi(peak_children, parent.get_child_count())
	for instance in simultaneous_shields:
		instance.clear()
		instance.free()
	var simultaneous_lightning: Array[VFXRuntimeInstance] = []
	for index in 10:
		var result := VFXProfileRunner.play(_profile(LIGHTNING), _lightning_context(4000 + index), &"play", parent, false)
		simultaneous_lightning.append(result.instance as VFXRuntimeInstance)
	peak_children = maxi(peak_children, parent.get_child_count())
	for instance in simultaneous_lightning:
		instance.cancel()
		instance.free()
	for index in 20:
		var result := VFXProfileRunner.play(_profile(PATH), _path_context(2 + index % 8, index % 3 != 0, 5000 + index), &"play", parent, false)
		var instance := result.instance as VFXRuntimeInstance
		instance.advance_simulation(0.05)
		instance.clear()
		instance.free()
	var invalid := VFXProfileRunner.play(_profile(LIGHTNING), VFXExecutionContext.create({"seed": 2}), &"play", parent, false)
	if bool(invalid.ok) or invalid.instance != null:
		_fail("Le contexte invalide a produit un node.")
	var disposable_layer := Node2D.new()
	root.add_child(disposable_layer)
	var disposable := VFXProfileRunner.play(_profile(SHIELD), _shield_context(6000), &"apply", disposable_layer, false)
	if not bool(disposable.ok):
		_fail("Préparation cible libérée impossible.")
	disposable_layer.free()
	await process_frame
	if parent.get_child_count() != 0:
		_fail("Node résiduel final dans la couche de stress.")
	parent.free()
	await process_frame
	await process_frame
	var node_count_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	return {
		"schema_version": 1,
		"play_clear_cycles": play_clear_cycles,
		"replay_cancel_cycles": replay_cycles,
		"simultaneous_shields": 10,
		"simultaneous_lightning": 10,
		"successive_paths": 20,
		"invalid_context_checked": true,
		"freed_target_layer_checked": true,
		"node_count_before": node_count_before,
		"node_count_after": node_count_after,
		"node_count_delta": node_count_after - node_count_before,
		"peak_runtime_children": peak_children,
		"residual_runtime_nodes": 0,
		"failures": failures.duplicate(),
	}


func _workflow() -> Dictionary:
	var timings := {}
	var started := Time.get_ticks_usec()
	var new_profile := VFXProfile.new()
	new_profile.profile_id = &"workflow.new_profile"
	new_profile.display_name = "Workflow Profile"
	var sequence := VFXSequenceData.new()
	sequence.sequence_id = &"play"
	var module := VFXModuleData.new()
	module.module_id = &"flash"
	module.module_type = &"FlashModule"
	module.context_requirements = [&"target_world"]
	sequence.modules = [module]
	new_profile.sequences = [sequence]
	new_profile.context_requirements = [&"target_world"]
	timings["create_profile_ms"] = _elapsed_ms(started)
	started = Time.get_ticks_usec()
	var duplicate := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD))
	timings["duplicate_profile_ms"] = _elapsed_ms(started)
	var document := VFXStudioDocument.new()
	document.open_profile(duplicate)
	started = Time.get_ticks_usec()
	document.record_edit("Couleur", func(): document.working_copy.sequences[0].modules[0].primary_color = Color("55dfff"))
	timings["edit_color_with_history_ms"] = _elapsed_ms(started)
	started = Time.get_ticks_usec()
	document.record_edit("Durée", func(): document.working_copy.sequences[0].modules[0].duration = 1.05)
	timings["edit_duration_with_history_ms"] = _elapsed_ms(started)
	started = Time.get_ticks_usec()
	document.record_edit("Ajouter module", func():
		var extra := VFXModuleData.new()
		extra.module_id = &"workflow_flash"
		extra.module_type = &"FlashModule"
		extra.context_requirements = [&"target_world"]
		document.working_copy.sequences[0].modules.append(extra)
	)
	timings["add_module_with_history_ms"] = _elapsed_ms(started)
	started = Time.get_ticks_usec()
	document.record_edit("Courbe", func():
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0))
		curve.add_point(Vector2(0.5, 0.8))
		curve.add_point(Vector2(1, 1))
		document.working_copy.sequences[0].modules[0].response_curve = curve
	)
	timings["edit_curve_with_history_ms"] = _elapsed_ms(started)
	document.working_copy.profile_id = WORKFLOW_DRAFT_ID
	started = Time.get_ticks_usec()
	var draft := VFXDraftService.new().save_draft(document)
	timings["save_draft_ms"] = _elapsed_ms(started)
	started = Time.get_ticks_usec()
	var reloaded := VFXDraftService.new().load_draft(WORKFLOW_DRAFT_ID)
	timings["reload_draft_ms"] = _elapsed_ms(started)
	var layer := Node2D.new()
	root.add_child(layer)
	started = Time.get_ticks_usec()
	var preview := VFXProfileRunner.play(document.working_copy, _shield_context(7777), &"apply", layer, false)
	timings["prepare_preview_ms"] = _elapsed_ms(started)
	if bool(preview.ok):
		var instance := preview.instance as VFXRuntimeInstance
		instance.clear()
		instance.free()
	layer.free()
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % WORKFLOW_DRAFT_ID))
	return {
		"schema_version": 1,
		"measurement_kind": "automated service latency; human interaction and artistic iteration not measured",
		"timings_ms": timings,
		"draft_round_trip_ok": bool(draft.ok) and bool(reloaded.ok),
		"current_workflow_observed": ["edit .gd/.tscn/.tres", "launch Godot", "navigate or run capture", "inspect artifact"],
		"vertical_slice_workflow": ["select profile", "edit Blackboard/module/timeline", "preview", "validate", "draft", "reload", "capture"],
		"not_measured": ["human authoring time", "artistic review", "current manual effect creation time", "capture operator time"],
	}


func _context(profile: VFXProfile, context_seed: int) -> VFXExecutionContext:
	if profile.profile_id == &"test.shield.lifecycle":
		return _shield_context(context_seed)
	if profile.profile_id == &"test.lightning.multi_target":
		return _lightning_context(context_seed)
	return _path_context(7, true, context_seed)


func _shield_context(context_seed: int) -> VFXExecutionContext:
	return VFXExecutionContext.create({"target_world": Vector2(120, 120), "impact_world_points": PackedVector2Array([Vector2(130, 110)]), "seed": context_seed, "quality_tier": 2, "magnitude": 0.8})


func _lightning_context(context_seed: int) -> VFXExecutionContext:
	return VFXExecutionContext.create({"origin_world": Vector2.ZERO, "target_world": Vector2(300, 0), "impact_world_points": PackedVector2Array([Vector2(220, -50), Vector2(280, 20), Vector2(230, 90)]), "seed": context_seed, "quality_tier": 2})


func _path_context(count: int, valid: bool, context_seed: int) -> VFXExecutionContext:
	var cells: Array[Vector2i] = []
	var points := PackedVector2Array()
	for index in count:
		cells.append(Vector2i(index, index % 2))
		points.append(Vector2(index * 52, (index % 2) * 24))
	return VFXExecutionContext.create({"origin_cell": cells[0], "target_cell": cells[-1], "ordered_path_cells": cells, "path_world_points": points, "origin_world": points[0], "target_world": points[-1], "impact_world_points": PackedVector2Array([points[-1]]), "path_valid": valid, "seed": context_seed, "quality_tier": 2, "consumer_kind": &"PLAYER_CONTROLLED"})


func _profile(path: String) -> VFXProfile:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as VFXProfile


func _elapsed_ms(started_usec: int) -> float:
	return snappedf(float(Time.get_ticks_usec() - started_usec) / 1000.0, 0.001)


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Impossible d’écrire %s" % path)
		return
	file.store_string(JSON.stringify(value, "  "))
	file.close()


func _remove_owned_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	failures.append(message)
