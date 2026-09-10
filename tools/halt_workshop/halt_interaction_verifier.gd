extends RefCounted
## Rendered integration checks use the real viewport and the isolated visit.
var suite: Node
var hall


func run(owner_suite: Node) -> void:
	suite = owner_suite
	hall = suite.hall
	_check("interaction_preview_isolated", hall.preview_mode and hall.interactions.bridge.preview)
	if not hall.preview_mode or not hall.interactions.bridge.preview:
		return
	await _interactions()
	await _audio()
	if suite._rendered:
		await _foreground()


func _check(label: String, passed: bool, details: Variant = null) -> void:
	suite._check(label, passed, details)


func _button(id: String, by_text := false) -> Button:
	for control: Node in hall.find_children("*", "Button", true, false):
		var button := control as Button
		if (
			button.is_visible_in_tree()
			and (button.text == id if by_text else str(button.name) == id)
		):
			return button
	return null


func _click(at: Vector2, mouse_button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	suite.get_viewport().push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = mouse_button
		event.position = at
		event.global_position = at
		event.pressed = pressed
		suite.get_viewport().push_input(event, true)
		await suite.get_tree().process_frame


func _press(button: Button, label: String) -> bool:
	_check(label + "_button_visible", button != null and not button.disabled)
	if button == null or button.disabled:
		return false
	var parent: Node = button.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if parent is ScrollContainer:
		(parent as ScrollContainer).ensure_control_visible(button)
	await suite.get_tree().process_frame
	await _click(button.get_global_rect().get_center())
	return true


func _advance_until_stopped() -> void:
	for step in 2400:
		if not hall.is_player_moving():
			break
		var before: Vector2 = hall.player.position
		hall.advance_world(1.0 / 60.0)
		suite.samples += 1
		if not hall.nav.is_walkable(hall.player.position) or before.distance_to(
				hall.player.position
			) > 5.0:
			suite.unsafe += 1
	hall.advance_world(0.0)


func _interactions() -> void:
	var spawn: Vector2 = hall.point(hall.definition.world.spawn)
	await suite._walk(spawn, "interaction_start")
	var landmark: Dictionary = hall.definition.landmarks[0]
	var destination: Vector2 = hall.point(landmark.point)
	await _press(_button(str(landmark.title), true), "landmark_approach")
	_check(
		"landmark_button_queues_approach",
		hall.interactions.pending == 0 and hall.is_player_moving(),
	)
	_check("landmark_panel_waits_for_arrival", not hall.interactions.active)
	for step in 20:
		hall.advance_world(1.0 / 60.0)
	var redirected_from: Vector2 = hall.player.position
	await _click(hall.world.to_global(spawn))
	_check(
		"floor_redirect_cancels_interaction",
		hall.interactions.pending == -1 and not hall.interactions.active,
	)
	_check("floor_redirect_does_not_teleport", hall.player.position == redirected_from)
	_advance_until_stopped()
	_check(
		"floor_redirect_arrives",
		hall.player.position.distance_to(spawn) < 0.3 and not hall.interactions.active,
	)
	await _press(_button(str(landmark.title), true), "landmark_retry")
	for step in 20:
		hall.advance_world(1.0 / 60.0)
	await _click(hall.world.to_global(spawn), MOUSE_BUTTON_RIGHT)
	_check(
		"right_click_cancels_pending",
		hall.interactions.pending == -1 and not hall.is_player_moving(),
	)
	hall.advance_world(1.0)
	_check("stopped_approach_never_opens_panel", not hall.interactions.active)
	await _press(_button(str(landmark.title), true), "landmark_final_approach")
	_check("interaction_approach_pending", hall.interactions.pending == 0)
	var paused_at: Vector2 = hall.player.position
	hall.set_paused(true)
	hall.advance_world(1.0)
	_check(
		"paused_approach_waits",
		hall.interactions.pending == 0 and not hall.interactions.active
		and hall.player.position == paused_at,
	)
	_check("paused_new_interaction_rejected", not hall.interactions.request(0))
	hall.set_paused(false)
	_advance_until_stopped()
	_check(
		"interaction_opens_on_arrival",
		hall.interactions.active and hall.interactions.pending == -1
		and hall.player.position.distance_to(destination) < 0.3,
	)
	if not hall.interactions.active:
		return
	await suite._capture("interaction_panel")
	var modal_at: Vector2 = hall.player.position
	await _click(hall.world.to_global(spawn))
	hall.advance_world(1.0)
	_check(
		"modal_blocks_floor_input",
		hall.player.position == modal_at
		and not hall.is_player_moving() and hall.interactions.active,
	)
	_check("modal_blocks_direct_path_requests", not hall.request_move(spawn))
	var before: Dictionary = hall.interactions.bridge.context()
	var offer: Dictionary = { }
	# The first displayed service is visible at the top of the real scroll view.
	for button: Node in hall.find_children("Service_*", "Button", true, false):
		if not (button as Button).is_visible_in_tree() or (button as Button).disabled:
			continue
		for service: Dictionary in before.services:
			if "Service_" + str(service.id).replace(":", "_") == str(button.name):
				offer = service
				break
		if not offer.is_empty():
			break
	_check("preview_has_available_service", not offer.is_empty())
	if not offer.is_empty():
		var service_id := str(offer.id)
		hall.set_paused(true)
		var refused: Dictionary = hall.interactions.activate(service_id)
		_check(
			"pause_blocks_service_purchase",
			not bool(refused.get("success", false))
			and int(hall.interactions.bridge.context().balance) == int(before.balance),
		)
		hall.set_paused(false)
		await _press(_button("Service_" + service_id.replace(":", "_")), "purchase")
		var after: Dictionary = hall.interactions.bridge.context()
		_check(
			"service_button_debits_exact_cost",
			int(after.balance) == int(before.balance) - int(offer.cost),
			{ "before": before.balance, "after": after.balance, "cost": offer.cost },
		)
		var used := false
		for service: Dictionary in after.services:
			if str(service.id) == service_id:
				used = bool(service.used) and not bool(service.available)
		_check("service_receipt_retained", used)
		var receipt := _button("Service_" + service_id.replace(":", "_"))
		_check("used_service_button_disabled", receipt != null and receipt.disabled)
		var repeated: Dictionary = hall.interactions.activate(service_id)
		_check(
			"duplicate_service_rejected",
			not bool(repeated.get("success", false))
			and int(hall.interactions.bridge.context().balance) == int(after.balance),
		)
		_check("landmark_reacts_once_used", bool(hall.interactions.awakened.get(
					str(landmark.id),
					false,
				)))
		await suite._capture("interaction_receipt")
	await _press(_button("CloseHaltInteraction"), "close_interaction")
	_check(
		"close_button_restores_exploration",
		not hall.interactions.active and not hall.interactions.blocked(),
	)
	await suite._walk(spawn, "interaction_return")


func _audio_peak(stream: AudioStreamWAV) -> float:
	if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.data.is_empty():
		return -1.0
	var peak := 0
	var bytes := stream.data
	for offset in range(0, bytes.size() - 1, 2):
		peak = maxi(peak, absi(bytes.decode_s16(offset)))
	return float(peak) / 32768.0


func _audio() -> void:
	var authored: Array = hall.definition.get("ambience", { }).get("sources", [])
	_check("audio_emitter_count", hall.ambience.sources.size() == authored.size())
	var listeners: Array[Node] = hall.player.find_children("*", "AudioListener2D", true, false)
	_check(
		"audio_listener_follows_actor",
		listeners.size() == 1 and (listeners[0] as AudioListener2D).is_current(),
	)
	var bound := 0.0
	for index in hall.ambience.sources.size():
		var source: AudioStreamPlayer2D = hall.ambience.sources[index]
		var stream := source.stream as AudioStreamWAV
		var peak := _audio_peak(stream)
		_check("audio_source_position_" + str(index), source.position.distance_to(
				hall.point(authored[index].point)
			) < 0.01)
		_check(
			"audio_source_attenuation_" + str(index),
			source.max_distance > 0.0 and source.attenuation > 0.0 and source.volume_db <= -6.0,
		)
		_check(
			"audio_source_loop_" + str(index),
			stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and stream.loop_end > 0,
		)
		_check("audio_source_pcm_headroom_" + str(index), peak > 0.0 and peak < 0.99, peak)
		_check("audio_source_playing_" + str(index), source.playing and not source.stream_paused)
		bound += maxf(peak, 0.0) * db_to_linear(source.volume_db)
	var steps: AudioStreamPlayer2D = hall.ambience.steps
	var step_peak := _audio_peak(steps.stream as AudioStreamWAV)
	_check("footstep_pcm_headroom", step_peak > 0.0 and step_peak < 0.99, step_peak)
	bound += maxf(step_peak, 0.0) * db_to_linear(steps.volume_db)
	_check("audio_combined_peak_bound", bound > 0.0 and bound < 0.99, bound)
	# An idle one-shot is already silent. Godot need not keep its pause flag set.
	steps.stop()
	await suite.get_tree().physics_frame
	await suite.get_tree().process_frame
	hall.set_paused(true)
	hall.advance_world(0.0)
	await suite.get_tree().process_frame
	var all_paused: bool = not steps.playing or steps.stream_paused
	for source: AudioStreamPlayer2D in hall.ambience.sources:
		all_paused = all_paused and (not source.playing or source.stream_paused)
	_check("pause_mutes_spatial_audio", all_paused)
	hall.set_paused(false)
	hall.audio_enabled = false
	hall.advance_world(0.0)
	await suite.get_tree().process_frame
	var all_muted: bool = not steps.playing or steps.stream_paused
	for source: AudioStreamPlayer2D in hall.ambience.sources:
		all_muted = all_muted and (not source.playing or source.stream_paused)
	_check("audio_toggle_mutes_sources_and_steps", all_muted)
	# Exercise the actual distance-triggered sound, including movement while muted.
	hall.ambience.advance(38.0, false, false)
	await suite.get_tree().physics_frame
	await suite.get_tree().process_frame
	_check("muted_movement_does_not_play_footstep", not steps.playing)
	hall.audio_enabled = true
	hall.advance_world(0.0)
	await suite.get_tree().process_frame
	var all_resumed := true
	for source: AudioStreamPlayer2D in hall.ambience.sources:
		all_resumed = all_resumed and source.playing and not source.stream_paused
	_check("audio_resumes_after_unmute", all_resumed)
	hall.ambience.advance(38.0, false, true)
	# AudioStreamPlayer2D starts pending playback on a physics tick.
	# Wait for that tick before exercising pause on a live one-shot.
	await suite.get_tree().physics_frame
	await suite.get_tree().process_frame
	_check("footstep_replays_after_unmute", steps.playing and not steps.stream_paused)
	hall.set_paused(true)
	hall.advance_world(0.0)
	await suite.get_tree().process_frame
	_check("pause_mutes_playing_footstep", not steps.playing or steps.stream_paused)
	hall.set_paused(false)
	hall.advance_world(0.0)
	await suite.get_tree().process_frame
	_check("footstep_resumes_after_pause", steps.playing and not steps.stream_paused)
	steps.stop()
	await suite.get_tree().physics_frame
	await suite.get_tree().process_frame


func _interior_point(shape: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for at: Vector2 in shape:
		center += at
	center /= shape.size()
	if Geometry2D.is_point_in_polygon(center, shape):
		return center
	for at: Vector2 in shape:
		var candidate := at.lerp(center, 0.2)
		if Geometry2D.is_point_in_polygon(candidate, shape):
			return candidate
	return shape[0]


func _foreground() -> void:
	var authored: Array = hall.definition.get("foreground", [])
	var actors: Node2D = hall.player.get_parent()
	_check("foreground_actor_depth_sort", actors.y_sort_enabled)
	var meshes: Array[Polygon2D] = []
	for child: Node in actors.get_children():
		if child is Polygon2D:
			meshes.append(child)
	_check("foreground_cutout_count", meshes.size() == authored.size())
	if meshes.is_empty():
		return
	hall.set_chrome_visible(false)
	hall.player.hide()
	hall.set_original(true)
	for index in mini(authored.size(), meshes.size()):
		var cutout := meshes[index]
		var anchor: Vector2 = hall.point(authored[index].anchor)
		_check("foreground_anchor_" + str(index), cutout.position.distance_to(anchor) < 0.01)
		_check(
			"foreground_source_texture_" + str(index),
			cutout.texture != null and cutout.polygon.size() >= 3
			and cutout.uv.size() == cutout.polygon.size(),
		)
		var sample: Vector2 = _interior_point(cutout.polygon) + anchor
		var normalized: Array = [sample.x / hall.world_size.x, sample.y / hall.world_size.y]
		var baseline: Image = await suite._image_at(1.0)
		var probe := Polygon2D.new()
		probe.color = Color(1.0, 0.0, 1.0, 1.0)
		probe.position = anchor - Vector2(0.0, 1.0)
		var offset := sample - probe.position
		probe.polygon = PackedVector2Array(
			[
				offset + Vector2(-12, -12),
				offset + Vector2(12, -12),
				offset + Vector2(12, 12),
				offset + Vector2(-12, 12),
			]
		)
		actors.add_child(probe)
		var behind: Image = await suite._image_at(1.0)
		var delta: float = suite._difference(baseline, behind, normalized, 2)
		_check("foreground_hides_behind_" + str(index), delta < 0.001, delta)
		probe.position += Vector2(0.0, 2.0)
		var front: Image = await suite._image_at(1.0)
		delta = suite._difference(behind, front, normalized, 2)
		_check("foreground_reveals_front_" + str(index), delta > 0.1, delta)
		probe.queue_free()
		await suite.get_tree().process_frame
	hall.set_original(false)
	hall.player.show()
	hall.set_chrome_visible(true)
