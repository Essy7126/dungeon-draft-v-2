extends Node2D
## Follows the body clock and confirmed displacement. Never changes combat state.
const HOOK := preload("res://vfx/class_cards/approved/hook.png")
var backend: Node2D
var caster: Unit
var target: Unit
var target_view: Node2D
var cell_world: Callable
var hook: Sprite2D
var width := 60.0
var closed := false
var started := false
var confirmed := false
var moving := false
var moved := false
var source_point := Vector2.ZERO
var tip := Vector2.ZERO
var target_offset := Vector2.ZERO
var movement_from := Vector2.ZERO
var movement_to := Vector2.ZERO
var last_position := Vector2.ZERO
var destination_cell := Vector2i.ZERO
var clock := 0.0
var alpha := 0.0
var waiting := 0.0


func configure(
	body: Node2D,
	owner_unit: Unit,
	victim: Unit,
	view: Node2D,
	world_for_cell: Callable,
	cell_width: float,
) -> void:
	backend = body
	caster = owner_unit
	target = victim
	target_view = view
	cell_world = world_for_cell
	width = cell_width
	target_offset = (
		target_view.get_cast_effect_origin_global() - target_view.global_position
		if target_view.has_method("get_cast_effect_origin_global")
		else Vector2.ZERO
	)
	if target_offset.length() < 1.0:
		target_offset = Vector2(0, -width * .42)
	hook = Sprite2D.new()
	hook.texture = HOOK
	hook.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hook.scale = Vector2.ONE * width * .32 / 256.0 / global_transform.x.length()
	add_child(hook)
	hook.hide()
	z_index = 5
	process_priority = 50
	EventBus.unit_pushed.connect(_displacement)
	EventBus.spell_cast.connect(_resolved)


func _process(delta: float) -> void:
	if closed:
		return
	if (
		(
			not is_instance_valid(backend) or not is_instance_valid(target_view) \
					or not is_instance_valid(caster)
			or not caster.is_alive
		) \
				or not is_instance_valid(target)
		or not target.is_alive
	):
		cancel()
		return
	var state: Dictionary = backend.get_runtime_state()
	if not state.get("pull_visible", false):
		waiting += delta
		if started or waiting > 1.0:
			cancel()
		return
	started = true
	sample(float(state.action_elapsed))


func sample(seconds: float) -> void:
	if closed:
		return
	clock = seconds
	if moving:
		if target.grid_pos != destination_cell or not target_view.global_position.is_equal_approx(
				last_position
			):
			moving = false # Another presentation now owns this actor.
		else:
			var u := clampf((clock - .4) / .20, 0.0, 1.0)
			target_view.global_position = movement_from.lerp(movement_to, 1.0 - pow(1.0 - u, 3.0))
			last_position = target_view.global_position
			if u >= 1.0:
				moving = false
	source_point = backend.to_global(backend.get_vfx_origin())
	var finish := target_view.global_position + target_offset
	tip = source_point.lerp(finish, smoothstep(.16, .32, clock))
	alpha = smoothstep(.14, .18, clock) * (1.0 - smoothstep(.64, .78, clock))
	# The hook flies before release; only confirmed facts can pull an actor.
	hook.visible = alpha > .001
	hook.global_position = tip
	hook.global_rotation = (tip - source_point).angle()
	hook.modulate = Color(.84, .98, .92, alpha * .85)
	queue_redraw()


func _displacement(unit: Unit, from: Vector2i, to: Vector2i, _collision: bool) -> void:
	if closed or unit != target or from == to or not is_instance_valid(backend):
		return
	var state: Dictionary = backend.get_runtime_state()
	if not state.get("pull_visible", false) or not state.release_emitted:
		return
	moved = true
	movement_from = cell_world.call(from)
	movement_to = cell_world.call(to)
	destination_cell = to


func _resolved(unit: Unit, spell: Spell, report: Dictionary) -> void:
	if closed or unit != caster or spell.spell_id != &"cc2_g04":
		return
	if report.get("failed", false) or not is_instance_valid(target) or not target.is_alive:
		cancel()
		return
	if not moved and target not in report.get("damaged_enemies", []):
		cancel()
		return
	confirmed = true
	if moved and is_instance_valid(target_view) and target.grid_pos == destination_cell:
		# Replay only the visual translation whose final logical cell is already committed.
		target_view.global_position = movement_from
		last_position = movement_from
		moving = true


func _draw() -> void:
	if closed or alpha <= .001:
		return
	var points := PackedVector2Array()
	var sag := width * .09 * (1.0 - smoothstep(.25, .39, clock))
	sag += width * .07 * smoothstep(.59, .76, clock)
	for i in 17:
		var u := float(i) / 16.0
		points.append(to_local(source_point.lerp(tip, u) + Vector2(0, sin(u * PI) * sag)))
	var factor := maxf(.01, global_transform.x.length())
	draw_polyline(points, Color(.16, .28, .29, alpha * .9), width * .032 / factor, true)
	draw_polyline(points, Color(.61, .84, .77, alpha), width * .012 / factor, true)
	if confirmed and clock < .53:
		var p := to_local(tip)
		for angle in [-.8, .1, .9]:
			var axis := Vector2.from_angle(angle)
			draw_line(
				p + axis * width * .05 / factor,
				p + axis * width * .12 / factor,
				Color(.9, .94, .73, alpha * (1.0 - smoothstep(.4, .53, clock))),
				width * .018 / factor,
				true,
			)


func cancel() -> void:
	if closed:
		return
	closed = true
	if (
		moving and is_instance_valid(target_view) and is_instance_valid(target) \
				and target.grid_pos == destination_cell
		and target_view.global_position.is_equal_approx(last_position)
	):
		target_view.global_position = movement_to
	moving = false
	hide()
	queue_free()
