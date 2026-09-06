extends RefCounted

const TIMEOUT_USEC := 5000000
const STABLE_USEC := 300000
const CANVAS_EPSILON_PX := 0.001


## Camera2D can publish its fitted canvas one frame after deployment/input
## becomes ready. Observe that transition without moving or forcing a camera.
## World/local unit transforms remain under test throughout this wait.
static func wait_for_settled_canvas(
		observer: Node,
		battle: Node,
		visual: Node2D,
		unit_view: Node2D,
		sprite: AnimatedSprite2D
	) -> Dictionary:
	var viewport: Viewport = observer.get_viewport()
	var start: int = Time.get_ticks_usec()
	var stable_since: int = start
	var first_canvas: Transform2D = viewport.get_canvas_transform()
	var stable_canvas: Transform2D = first_canvas
	var last_canvas: Transform2D = first_canvas
	var initial_sprite: Transform2D = sprite.transform
	var initial_sprite_world: Transform2D = sprite.global_transform
	var initial_unit: Transform2D = unit_view.transform
	var initial_unit_world: Transform2D = unit_view.global_transform
	var initial_visual: Transform2D = visual.transform
	var initial_visual_world: Transform2D = visual.global_transform
	var initial_offset: Vector2 = sprite.offset
	var initial_centered: bool = sprite.centered
	var initial_mirrored: bool = sprite.flip_h
	var initial_animation: StringName = sprite.animation
	var maximum_canvas_change: float = 0.0
	var unstable_model_samples: int = 0
	var samples: int = 0
	var canvas_changes: int = 0
	var camera_was_current: bool = false
	var settled: bool = false
	while Time.get_ticks_usec() - start < TIMEOUT_USEC:
		await observer.get_tree().process_frame
		if not is_instance_valid(visual) or not is_instance_valid(unit_view) or not is_instance_valid(sprite):
			return {"ok": false, "reason": "unit_view_removed_while_waiting_for_canvas", "sample_count": samples}
		var now: int = Time.get_ticks_usec()
		var canvas: Transform2D = viewport.get_canvas_transform()
		var camera: Camera2D = viewport.get_camera_2d()
		var current: bool = is_instance_valid(camera) and camera == battle.get("camera") and camera.is_current()
		maximum_canvas_change = maxf(maximum_canvas_change, transform_distance(first_canvas, canvas))
		if transform_distance(last_canvas, canvas) > CANVAS_EPSILON_PX:
			canvas_changes += 1
		last_canvas = canvas
		if not current or not camera_was_current or transform_distance(stable_canvas, canvas) > CANVAS_EPSILON_PX:
			stable_since = now
			stable_canvas = canvas
		camera_was_current = current
		if not str(sprite.animation).begins_with("idle_") or sprite.animation != initial_animation or sprite.frame != 0 \
				or sprite.is_playing() or sprite.transform != initial_sprite or sprite.global_transform != initial_sprite_world \
				or unit_view.transform != initial_unit or unit_view.global_transform != initial_unit_world \
				or visual.transform != initial_visual or visual.global_transform != initial_visual_world \
				or sprite.offset != initial_offset or sprite.centered != initial_centered or sprite.flip_h != initial_mirrored:
			unstable_model_samples += 1
		samples += 1
		if current and now - stable_since >= STABLE_USEC and samples >= 3:
			settled = true
			break
	var end: int = Time.get_ticks_usec()
	var final_camera: Camera2D = viewport.get_camera_2d()
	return {"ok": settled and unstable_model_samples == 0,
		"reason": "model_moved_during_canvas_settling" if unstable_model_samples > 0 else ("settled" if settled else "canvas_stabilization_timeout"),
		"sample_count": samples, "waited_seconds": float(end - start) / 1000000.0,
		"stable_seconds": float(end - stable_since) / 1000000.0,
		"required_stable_seconds": float(STABLE_USEC) / 1000000.0,
		"timeout_seconds": float(TIMEOUT_USEC) / 1000000.0,
		"maximum_canvas_change_px": maximum_canvas_change, "observed_canvas_changes": canvas_changes,
		"unexpected_model_samples": unstable_model_samples, "camera_is_current": camera_was_current,
		"initial_canvas": transform_snapshot(first_canvas), "final_canvas": transform_snapshot(last_canvas),
		"camera_position": final_camera.position if is_instance_valid(final_camera) else Vector2.ZERO,
		"camera_zoom": final_camera.zoom if is_instance_valid(final_camera) else Vector2.ZERO,
		"camera_offset": final_camera.offset if is_instance_valid(final_camera) else Vector2.ZERO,
		"scope": "Read-only canvas/camera settling. Unit local and world transforms, idle frame, offset and mirroring monitored throughout. No camera, model, animation clock or game-state writes."}


static func transform_distance(first: Transform2D, second: Transform2D) -> float:
	var maximum: float = 0.0
	for point: Vector2 in [Vector2.ZERO, Vector2(1024, 0), Vector2(0, 1024)]:
		maximum = maxf(maximum, (first * point).distance_to(second * point))
	return maximum


static func transform_snapshot(value: Transform2D) -> Dictionary:
	return {"x": [value.x.x, value.x.y], "y": [value.y.x, value.y.y],
		"origin": [value.origin.x, value.origin.y]}
