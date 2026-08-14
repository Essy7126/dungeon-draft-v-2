class_name VFXFlipbookFoundationLab
extends Node2D

const PROFILE_PATH := "res://vfx/profiles/test/synthetic_flipbook_profile.tres"
const LAB_STAGE_SCRIPT := preload("res://tools/labs/vfx_flipbook_foundation/vfx_flipbook_lab_stage.gd")
const CONTRACT_SCENARIOS := [
	"target_empty_cell", "target_in_front_of_silhouette", "target_behind_silhouette",
	"origin_anchor", "first_impact_anchor", "one_instance", "four_instances",
	"ten_instances", "cancel_at_half", "parent_freed", "quality_change",
	"variant_change_by_seed", "loop_explicitly_stopped", "incomplete_context_refused",
]

var stage: Node2D
var vfx_layer: Node2D
var light_silhouette: Node2D
var dark_silhouette: Node2D
var overlay_label: Label
var scrub_slider: HSlider
var current_instances: Array[VFXRuntimeInstance] = []
var current_quality := 2
var current_blend: StringName = &"ADD"
var current_speed := 1.0
var current_light_background := false
var current_seed := 200
var current_count := 1
var current_anchor: StringName = &"TARGET_WORLD"
var _stage_center := Vector2(600, 470)
var _last_scenario := "interactive"


func _ready() -> void:
	stage = LAB_STAGE_SCRIPT.new()
	stage.name = "TacticalGrid"
	stage.z_index = 0
	add_child(stage)
	vfx_layer = Node2D.new()
	vfx_layer.name = "VFXLayer"
	vfx_layer.z_index = 2
	add_child(vfx_layer)
	light_silhouette = _make_silhouette("LightSilhouette", Color("ecf5ff"), Color("87a9c4"))
	light_silhouette.z_index = 1
	add_child(light_silhouette)
	dark_silhouette = _make_silhouette("DarkSilhouette", Color("17202b"), Color("536d80"))
	dark_silhouette.z_index = 3
	add_child(dark_silhouette)
	_build_controls()
	get_viewport().size_changed.connect(_layout)
	_layout()
	play()


func get_contract_scenarios() -> Array:
	return CONTRACT_SCENARIOS.duplicate()


func play() -> void:
	clear()
	_last_scenario = "interactive"
	_spawn_instances(current_count, current_seed, current_quality, current_blend, current_anchor, "empty", false, true)


func pause() -> void:
	for instance in current_instances:
		if is_instance_valid(instance):
			instance.set_process(false)
	_update_overlay()


func resume() -> void:
	for instance in current_instances:
		if is_instance_valid(instance) and instance.lifecycle_state == &"PLAYING":
			instance.set_process(true)
	_update_overlay()


func replay() -> void:
	play()


func scrub_to(normalized_time: float) -> void:
	clear()
	_last_scenario = "interactive_scrub"
	_spawn_instances(current_count, current_seed, current_quality, current_blend, current_anchor)
	advance_to(normalized_time)


func clear() -> void:
	for instance in current_instances:
		if is_instance_valid(instance):
			instance.clear()
			instance.free()
	current_instances.clear()
	for child in vfx_layer.get_children():
		child.free()
	_update_overlay()


func advance_to(normalized_time: float) -> void:
	var target := clampf(normalized_time, 0.0, 0.99)
	for instance in current_instances:
		if not is_instance_valid(instance) or instance.lifecycle_state != &"PLAYING":
			continue
		instance.advance_simulation(target * instance.sequence.duration() / current_speed)
	_update_overlay()


func prepare_capture(scenario: Dictionary) -> Dictionary:
	clear()
	_last_scenario = str(scenario.get("name", "capture"))
	current_quality = int(scenario.get("quality", 2))
	current_blend = StringName(scenario.get("blend", "ADD"))
	current_speed = float(scenario.get("speed", 1.0))
	current_light_background = bool(scenario.get("light_background", false))
	current_count = int(scenario.get("instances", 1))
	current_anchor = StringName(scenario.get("anchor", "TARGET_WORLD"))
	current_seed = int(scenario.get("seed", 200))
	stage.configure(_stage_center, current_light_background)
	var target_mode := str(scenario.get("target_mode", "empty"))
	_spawn_instances(
		current_count, current_seed, current_quality, current_blend, current_anchor, target_mode,
		bool(scenario.get("loop", false))
	)
	advance_to(float(scenario.get("progress", 0.5)))
	if bool(scenario.get("cancel", false)):
		for instance in current_instances:
			if is_instance_valid(instance):
				instance.cancel()
	_update_overlay()
	var snapshot := inspection_snapshot()
	if bool(scenario.get("cancel", false)):
		snapshot["ok"] = snapshot.visuals.is_empty() and _all_instances_in_state(&"CANCELLED")
	else:
		snapshot["ok"] = snapshot.runtime_nodes == current_count \
				and snapshot.visuals.size() == current_count
	return snapshot


func run_contract_scenario(index: int) -> Dictionary:
	var scenario_name: String = str(CONTRACT_SCENARIOS[clampi(index, 0, CONTRACT_SCENARIOS.size() - 1)])
	match scenario_name:
		"target_empty_cell":
			return prepare_capture({"name": scenario_name, "target_mode": "empty"})
		"target_in_front_of_silhouette":
			return prepare_capture({"name": scenario_name, "target_mode": "light"})
		"target_behind_silhouette":
			return prepare_capture({"name": scenario_name, "target_mode": "dark"})
		"origin_anchor":
			return prepare_capture({"name": scenario_name, "anchor": "ORIGIN_WORLD"})
		"first_impact_anchor":
			return prepare_capture({"name": scenario_name, "anchor": "FIRST_IMPACT_WORLD"})
		"four_instances":
			return prepare_capture({"name": scenario_name, "instances": 4})
		"ten_instances":
			return prepare_capture({"name": scenario_name, "instances": 10})
		"cancel_at_half":
			return prepare_capture({"name": scenario_name, "progress": 0.5, "cancel": true})
		"parent_freed":
			var holder := Node2D.new()
			add_child(holder)
			var result := VFXProfileRunner.play(_profile(), _context_for(Vector2.ZERO, 8, 2, holder), &"play", holder, false)
			var runtime_instance: VFXRuntimeInstance = result.get("instance") as VFXRuntimeInstance
			holder.free()
			var freed := not is_instance_valid(holder) and not is_instance_valid(runtime_instance)
			return {
				"ok": bool(result.ok) and freed,
				"parent_freed": freed,
				"residual": vfx_layer.get_child_count(),
			}
		"quality_change":
			return prepare_capture({"name": scenario_name, "quality": posmod(current_quality + 1, 3)})
		"variant_change_by_seed":
			return prepare_capture({"name": scenario_name, "seed": current_seed + 1})
		"loop_explicitly_stopped":
			prepare_capture({"name": scenario_name, "loop": true, "progress": 0.8})
			for instance in current_instances:
				instance.cancel()
			var report := inspection_snapshot()
			report["ok"] = report.visuals.is_empty() and _all_instances_in_state(&"CANCELLED")
			report["stopped"] = true
			return report
		"incomplete_context_refused":
			clear()
			var result := VFXProfileRunner.play(
				_profile(), VFXExecutionContext.create({"seed": 5}), &"play", vfx_layer, false
			)
			return {"ok": not bool(result.ok), "errors": result.errors, "residual": vfx_layer.get_child_count()}
		_:
			return prepare_capture({"name": scenario_name})


func inspection_snapshot() -> Dictionary:
	var visuals: Array = []
	var lifecycle_states: Array[String] = []
	for instance in current_instances:
		if not is_instance_valid(instance):
			continue
		lifecycle_states.append(str(instance.lifecycle_state))
		for visual in instance._visuals:
			if visual is VFXFlipbookVisual:
				visuals.append({
					"frame": visual.get_current_frame(),
					"variant": str(visual.get_selected_variant_id()),
					"quality": visual.get_selected_quality_tier(),
					"texture": visual.get_selected_texture_path(),
				})
	return {
		"scenario": _last_scenario,
		"profile": "test.synthetic.flipbook.foundation",
		"sequence": "play",
		"seed": current_seed,
		"quality": current_quality,
		"blend": str(current_blend),
		"instances": current_count,
		"runtime_nodes": current_instances.size(),
		"layer_children": vfx_layer.get_child_count() if vfx_layer != null else 0,
		"lifecycle_states": lifecycle_states,
		"visuals": visuals,
	}


func _all_instances_in_state(expected: StringName) -> bool:
	if current_instances.is_empty():
		return false
	for instance in current_instances:
		if not is_instance_valid(instance) or instance.lifecycle_state != expected:
			return false
	return true


func seed_for_variant(variant_id: StringName) -> int:
	var profile := _profile()
	var module := profile.get_sequence(&"play").modules[0] as VFXFlipbookModuleData
	var identity := "%s|%s|%s|0" % [profile.profile_id, &"play", module.module_id]
	for candidate in 8:
		var local_seed := candidate + module.seed_offset + int(identity.hash())
		if module.asset.select_variant(local_seed).variant_id == variant_id:
			return candidate
	return 0


func _spawn_instances(
		count: int,
		base_seed: int,
		quality: int,
		blend: StringName,
		anchor: StringName,
		target_mode := "empty",
		looping := false,
		auto_process := false
	) -> void:
	for index in count:
		var profile := _profile()
		var module := profile.get_sequence(&"play").modules[0] as VFXFlipbookModuleData
		module.anchor = anchor
		module.asset = module.asset.duplicate(true) as VFXFlipbookAsset
		module.asset.blend_mode = blend
		module.asset.loop = looping
		if looping:
			module.asset.playback_mode = &"SOURCE_FPS"
			module.asset.frames_per_second = 18.0
		var target := _target_for(index, count, target_mode)
		var context := _context_for(target, base_seed + index, quality, vfx_layer)
		var result := VFXProfileRunner.play(profile, context, &"play", vfx_layer, auto_process)
		if bool(result.ok):
			current_instances.append(result.instance as VFXRuntimeInstance)
	_update_overlay()


func _target_for(index: int, count: int, target_mode: String) -> Vector2:
	if target_mode == "light":
		return light_silhouette.position + Vector2(0, -52)
	if target_mode == "dark":
		return dark_silhouette.position + Vector2(0, -52)
	if count == 1:
		return _stage_center + Vector2(0, 12)
	var column := index % 5
	var row := index / 5
	return _stage_center + Vector2((column - 2) * 118, (row - 0.5) * 110)


func _context_for(target: Vector2, seed_value: int, quality: int, layer: Node) -> VFXExecutionContext:
	return VFXExecutionContext.create({
		"target_world": target,
		"origin_world": _stage_center + Vector2(-280, 100),
		"impact_world_points": PackedVector2Array([target + Vector2(34, -12)]),
		"cell_visual_size": Vector2(96, 48),
		"quality_tier": quality,
		"speed_scale": current_speed,
		"seed": seed_value,
		"target_layer": layer,
	})


func _profile() -> VFXProfile:
	var source := ResourceLoader.load(PROFILE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as VFXProfile
	return VFXProfileCopyService.new().duplicate_profile(source)


func _make_silhouette(node_name: String, body_color: Color, rim_color: Color) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	var torso := Polygon2D.new()
	torso.polygon = PackedVector2Array([
		Vector2(-32, 24), Vector2(-22, -34), Vector2(0, -52),
		Vector2(22, -34), Vector2(32, 24), Vector2(18, 42), Vector2(-18, 42),
	])
	torso.color = body_color
	root.add_child(torso)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(0, -86), Vector2(18, -74), Vector2(15, -54),
		Vector2(0, -44), Vector2(-15, -54), Vector2(-18, -74),
	])
	head.color = rim_color
	root.add_child(head)
	return root


func _build_controls() -> void:
	var panel := PanelContainer.new()
	panel.name = "Controls"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 14
	panel.offset_top = 14
	panel.offset_right = -14
	panel.offset_bottom = 164
	panel.z_index = 20
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var title := Label.new()
	title.text = "VFX FLIPBOOK FOUNDATION V1  |  SYNTHETIC TEST ATLAS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var buttons := HFlowContainer.new()
	buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	buttons.custom_minimum_size.y = 68
	rows.add_child(buttons)
	_add_button(buttons, "Play", play)
	_add_button(buttons, "Pause", pause)
	_add_button(buttons, "Resume", resume)
	_add_button(buttons, "Replay", replay)
	_add_button(buttons, "Clear", clear)
	for speed in [0.25, 0.5, 1.0]:
		_add_button(buttons, "%sx" % speed, func(): current_speed = speed; replay())
	for quality in [0, 1, 2]:
		_add_button(buttons, ["LOW", "MEDIUM", "HIGH"][quality], func(): current_quality = quality; replay())
	for blend in [&"MIX", &"ADD", &"PREMULTIPLIED"]:
		_add_button(buttons, str(blend), func(): current_blend = blend; replay())
	_add_button(buttons, "Light/Dark", func(): current_light_background = not current_light_background; _layout(); replay())
	for amount in [1, 4, 10]:
		_add_button(buttons, "%d instance%s" % [amount, "s" if amount > 1 else ""], func(): current_count = amount; replay())
	var scrub_row := HBoxContainer.new()
	rows.add_child(scrub_row)
	var scrub_label := Label.new()
	scrub_label.text = "Scrub"
	scrub_row.add_child(scrub_label)
	scrub_slider = HSlider.new()
	scrub_slider.min_value = 0.0
	scrub_slider.max_value = 0.99
	scrub_slider.step = 0.01
	scrub_slider.value = 0.48
	scrub_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrub_slider.value_changed.connect(scrub_to)
	scrub_row.add_child(scrub_slider)
	overlay_label = Label.new()
	overlay_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	overlay_label.offset_left = 18
	overlay_label.offset_right = -18
	overlay_label.offset_top = -54
	overlay_label.offset_bottom = -14
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.z_index = 20
	add_child(overlay_label)


func _add_button(parent: Control, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	parent.add_child(button)


func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	_stage_center = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.58)
	stage.configure(_stage_center, current_light_background)
	light_silhouette.position = _stage_center + Vector2(-240, 72)
	dark_silhouette.position = _stage_center + Vector2(240, 72)


func _update_overlay() -> void:
	if overlay_label == null:
		return
	var snapshot := inspection_snapshot()
	var frame_text := "none"
	var variant_text := "none"
	if not snapshot.visuals.is_empty():
		frame_text = str(snapshot.visuals[0].frame)
		variant_text = str(snapshot.visuals[0].variant)
	overlay_label.text = "%s | seed %d | Q%d | %s | %d instance(s) | frame %s | %s | active visuals %d" % [
		_last_scenario, current_seed, current_quality, current_blend, current_count,
		frame_text, variant_text, snapshot.visuals.size(),
	]
