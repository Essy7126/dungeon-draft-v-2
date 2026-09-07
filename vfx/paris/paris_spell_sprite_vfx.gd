class_name ParisSpellSpriteVFX
extends PhilosopherSpellSpriteVFX

const FLIGHT_ANIMATIONS := {
	&"paris_spectral_arrow": &"arrow", &"paris_fire_arrow": &"fire",
	&"paris_ice_arrow": &"frost", &"paris_vortex_arrow": &"vortex",
}


func _ready() -> void:
	add_to_group("paris_spell_sprite_vfx")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)


func start_flight(duration: float) -> void:
	_impact_reached = false
	_start(&"flight", FLIGHT_ANIMATIONS.get(_spell_id, &"arrow"), maxf(0.001, duration))


func confirm_impact(targets: Array[Vector2]) -> void:
	if _closed or _phase not in [&"flight", &"awaiting_impact"]:
		return
	_targets.assign(targets)
	if _targets.is_empty():
		cancel()
		return
	var burst: StringName = &"impact"
	if _spell_id == &"paris_fire_arrow":
		burst = &"hellfire"
	elif _spell_id == &"paris_vortex_arrow":
		burst = &"vortex"
	start_burst(burst, 0.30)


func _render() -> void:
	super._render()
	if _phase in [&"flight", &"awaiting_impact"]:
		for index in _sprites.size():
			_sprites[index].global_rotation = (_targets[index] - _origin).angle()
	elif _animation == &"whip":
		for index in _sprites.size():
			var sprite := _sprites[index]
			var target := _targets[index]
			sprite.global_position = _origin.lerp(target, 0.5)
			sprite.global_rotation = (target - _origin).angle()
			sprite.global_scale = Vector2.ONE * maxf(_width, _origin.distance_to(target)) / maxf(1, sprite.texture.get_width())
	elif _binding_kind == &"transformation":
		var count := _frames.get_frame_count(_animation)
		var frame := mini(count - 1, int(clampf(_phase_elapsed / _duration, 0, 1) * count))
		for sprite in _sprites:
			sprite.texture = _frames.get_frame_texture(_animation, frame)


func start_transformation(unit: Unit, view: Node2D, duration: float) -> void:
	_bound_unit = weakref(unit)
	_bound_view = weakref(view)
	_binding_kind = &"transformation"
	_binding_id = &"paris_infernal_form"
	if _update_binding():
		start_burst(&"transform", duration)


func _update_binding() -> bool:
	if _binding_kind != &"transformation":
		return super._update_binding()
	var unit := _bound_unit.get_ref() as Unit if _bound_unit != null else null
	var view := _bound_view.get_ref() as Node2D if _bound_view != null else null
	if not is_instance_valid(unit) or not unit.is_alive or not is_instance_valid(view) \
			or not view.is_inside_tree() or view.is_queued_for_deletion() \
			or not view.has_method("is_transformation_pending") or not view.is_transformation_pending():
		cancel()
		return false
	_targets.assign([view.global_position + Vector2(0, -32.0 * absf(view.global_scale.y))])
	return true
