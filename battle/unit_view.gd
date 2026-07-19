# battle/unit_view.gd
extends Node2D

const Glossary = preload("res://ui/combat_glossary.gd")

const UNIT_SIZE = 48

var unit: Unit
var _sprite: AnimatedSprite2D
var _facing_row: int = 0
var _hp_bar: ProgressBar
var _shield_bar: ProgressBar
var _fervor_bar: ProgressBar
var _status_row: HBoxContainer
var _is_active: bool = false
var _flash_tween: Tween = null
var _last_threshold_active: bool = false
var _threshold_notch: ColorRect
var _pulse_tween: Tween = null
var _optional_visual: Node2D = null
var _optional_visual_cast_pending := false

func setup(p_unit: Unit) -> void:
	unit = p_unit
	add_to_group("unit_views")
	_last_threshold_active = unit.charge_threshold_active
	_build_visual()
	unit.hp_changed.connect(_on_hp_changed)
	unit.died.connect(_on_died)
	unit.moved.connect(_on_unit_moved)
	unit.shield_changed.connect(_on_shield_changed)
	unit.energy_changed.connect(_on_resource_changed)
	unit.stats_changed.connect(_on_stats_changed)
	EventBus.basic_attack_performed.connect(_on_attack_performed)
	EventBus.turn_started.connect(_on_any_turn_started)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.unit_healed.connect(_on_unit_healed)
	EventBus.shield_absorbed.connect(_on_shield_absorbed)
	EventBus.shield_broken.connect(_on_shield_broken)
	EventBus.shield_gained.connect(_on_shield_gained)
	EventBus.status_applied.connect(_on_status_changed)
	EventBus.status_expired.connect(_on_status_expired)
	_update_all_bars()
	_update_status_icons()

func _build_visual() -> void:
	_sprite = AnimatedSprite2D.new()
	if unit.sprite_frames != null:
		_sprite.sprite_frames = unit.sprite_frames.duplicate(true)
		_sprite.scale = Vector2(unit.sprite_scale, unit.sprite_scale)
		var anims = unit.sprite_frames.get_animation_names()
		if unit.idle_animation in anims:
			_sprite.play(unit.idle_animation)
		elif anims.size() > 0:
			_sprite.play(anims[0])
	add_child(_sprite)

	_hp_bar = _make_bar(Vector2(UNIT_SIZE, 6), Vector2(-UNIT_SIZE / 2.0, -45), Color(0.3, 0.8, 0.3))
	add_child(_hp_bar)

	_shield_bar = _make_bar(Vector2(UNIT_SIZE, 4), Vector2(-UNIT_SIZE / 2.0, -51), Color(1.0, 0.82, 0.30))
	_shield_bar.visible = false
	add_child(_shield_bar)

	_fervor_bar = _make_bar(Vector2(UNIT_SIZE, 4), Vector2(-UNIT_SIZE / 2.0, 35), Color(0.86, 0.74, 1.0))
	add_child(_fervor_bar)

	# Encoche du seuil d'eveil : un trait vertical sur la barre d'ecole,
	# positionne a awakening_cost / max_energy. Cachee sans energie.
	_threshold_notch = ColorRect.new()
	_threshold_notch.size = Vector2(2, 8)
	_threshold_notch.color = Color(1, 1, 1, 0.9)
	_threshold_notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_threshold_notch.visible = false
	add_child(_threshold_notch)

	_status_row = HBoxContainer.new()
	_status_row.position = Vector2(-UNIT_SIZE / 2.0, -66)
	_status_row.add_theme_constant_override("separation", 2)
	add_child(_status_row)

	_instantiate_optional_visual()

func _instantiate_optional_visual() -> void:
	if unit.visual_scene == null:
		return
	var candidate := unit.visual_scene.instantiate()
	if not candidate is Node2D:
		push_warning("UnitView: la scene visuelle optionnelle de %s doit avoir une racine Node2D." % unit.unit_name)
		candidate.queue_free()
		return
	_optional_visual = candidate as Node2D
	add_child(_optional_visual)
	_optional_visual.add_to_group("optional_unit_visuals")
	if is_instance_valid(_sprite):
		_sprite.visible = false
	if _optional_visual.has_method("bind_unit"):
		_optional_visual.bind_unit(unit)

func has_optional_visual() -> bool:
	return is_instance_valid(_optional_visual)

func get_optional_visual() -> Node2D:
	return _optional_visual if is_instance_valid(_optional_visual) else null

func get_cast_effect_origin_global() -> Vector2:
	if is_instance_valid(_optional_visual) \
			and _optional_visual.has_method("get_default_cast_effect_origin"):
		var local_origin: Vector2 = _optional_visual.get_default_cast_effect_origin()
		return _optional_visual.to_global(local_origin)
	return global_position

## Synchronisation visuelle seulement : le calcul du sort reste dans
## SpellCaster. Le bool false ignore un second clic pendant le meme wind-up.
func prepare_spell_visual(target_cell: Vector2i) -> bool:
	face_grid_direction(target_cell - unit.grid_pos)
	if not is_instance_valid(_optional_visual) or not _optional_visual.has_method("play_cast"):
		return true
	if _optional_visual_cast_pending:
		return false
	_optional_visual_cast_pending = true
	var started = _optional_visual.play_cast()
	if started is bool and not started:
		_optional_visual_cast_pending = false
		return false
	if not _optional_visual.has_signal("cast_release_reached"):
		_optional_visual_cast_pending = false
		return true
	var release_state := {"released": false}
	var mark_released := func() -> void: release_state["released"] = true
	_optional_visual.connect("cast_release_reached", mark_released, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + 5000
	while not release_state["released"] and unit.is_alive and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if is_instance_valid(_optional_visual) \
			and _optional_visual.is_connected("cast_release_reached", mark_released):
		_optional_visual.disconnect("cast_release_reached", mark_released)
	_optional_visual_cast_pending = false
	if not release_state["released"] and unit.is_alive:
		push_warning("UnitView: cast_release_reached absent apres 5 s pour %s; le gameplay reprend sans blocage." % unit.unit_name)
	return unit.is_alive

func _make_bar(size: Vector2, pos: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.size = size
	bar.position = pos
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _update_all_bars() -> void:
	_update_hp_bar()
	_update_shield_bar()
	_update_resource_bars()

func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = unit.max_hp.get_int()
	_hp_bar.value = unit.current_hp
	var ratio = unit.get_hp_ratio()
	var bar_color: Color
	if ratio > 0.5:
		bar_color = Color(0.3, 0.8, 0.3)
	elif ratio > 0.25:
		bar_color = Color(0.9, 0.8, 0.2)
	else:
		bar_color = Color(0.9, 0.3, 0.2)
	var style = StyleBoxFlat.new()
	style.bg_color = bar_color
	_hp_bar.add_theme_stylebox_override("fill", style)

func _update_shield_bar() -> void:
	if _shield_bar == null:
		return
	var shield := unit.current_shield
	_shield_bar.visible = shield > 0
	if shield > 0:
		_shield_bar.max_value = max(shield, unit.max_hp.get_int())
		_shield_bar.value = shield
	queue_redraw()

func _update_resource_bars() -> void:
	if _fervor_bar == null:
		return
	if not unit.has_energy():
		_fervor_bar.visible = false
		_threshold_notch.visible = false
		_set_pulse(false)
		return
	var school := unit.energy_type.get_school_color()
	_fervor_bar.visible = true
	_fervor_bar.max_value = maxf(1.0, unit.energy_type.max_energy)
	_fervor_bar.value = unit.current_energy
	var fill := StyleBoxFlat.new()
	fill.bg_color = school
	_fervor_bar.add_theme_stylebox_override("fill", fill)
	# Encoche du seuil d'eveil, posee a awakening_cost / max_energy.
	var ratio := clampf(unit.energy_type.awakening_cost / maxf(1.0, unit.energy_type.max_energy), 0.0, 1.0)
	_threshold_notch.visible = true
	_threshold_notch.position = Vector2(-UNIT_SIZE / 2.0 + ratio * UNIT_SIZE - 1.0, 33)
	# "Tu peux t'eveiller" : la barre pulse doucement tant que l'Eveil est
	# activable (jauge au seuil, pas encore en eveil).
	_set_pulse(unit.can_activate_awakening())
	if not _last_threshold_active and unit.charge_threshold_active:
		_flash(school, 0.35)
	_last_threshold_active = unit.charge_threshold_active
	queue_redraw() # le lisere d'eveil vit dans _draw()

# Pulse de luminosite de la barre d'ecole (~1 s de cycle, subtil).
func _set_pulse(active: bool) -> void:
	if active:
		if _pulse_tween != null and _pulse_tween.is_valid():
			return
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_fervor_bar, "modulate", Color(1.35, 1.35, 1.35), 0.5).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(_fervor_bar, "modulate", Color(1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	else:
		if _pulse_tween != null and _pulse_tween.is_valid():
			_pulse_tween.kill()
			_pulse_tween = null
		_fervor_bar.modulate = Color(1, 1, 1)

func _update_status_icons() -> void:
	if _status_row == null:
		return
	for child in _status_row.get_children():
		_status_row.remove_child(child)
		child.queue_free()
	for entry in unit.get_active_statuses():
		var data: StatusData = entry.get("data")
		if data == null:
			continue
		var chip := Label.new()
		chip.text = data.status_name.substr(0, min(2, data.status_name.length())).to_upper()
		chip.custom_minimum_size = Vector2(20, 16)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_theme_font_size_override("font_size", 10)
		chip.add_theme_color_override("font_color", Color.WHITE)
		chip.modulate = data.color
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.tooltip_text = "%s (%d tour(s))" % [data.status_name, int(entry.get("remaining", data.duration))]
		chip.mouse_entered.connect(func(): _show_status_tooltip(data))
		chip.mouse_exited.connect(_hide_keyword_tooltip)
		_status_row.add_child(chip)

func set_active(active: bool) -> void:
	_is_active = active
	queue_redraw()

func face_direction(from: Vector2, to: Vector2) -> void:
	if _sprite == null:
		return
	var dx := to.x - from.x
	var dy := to.y - from.y
	var row: int
	if abs(dx) >= abs(dy):
		row = 2 if dx >= 0.0 else 6  # E ou O
	else:
		row = 0 if dy >= 0.0 else 4  # S ou N
	_set_facing_row(row)

## Oriente les sprites depuis la direction logique de GridData. Cette API ne
## depend pas de la projection a l'ecran et reste donc stable en isometrique.
func face_grid_direction(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	if is_instance_valid(_optional_visual) and _optional_visual.has_method("set_facing"):
		_optional_visual.set_facing(direction)
	if _sprite == null:
		return
	var row: int
	if abs(direction.x) >= abs(direction.y):
		row = 2 if direction.x >= 0 else 6  # +X / -X
	else:
		row = 0 if direction.y >= 0 else 4  # +Y / -Y
	_set_facing_row(row)

func _set_facing_row(row: int) -> void:
	if _facing_row == row or _sprite == null or _sprite.sprite_frames == null:
		return
	_facing_row = row
	var sf := _sprite.sprite_frames
	for anim_name in sf.get_animation_names():
		for i in sf.get_frame_count(anim_name):
			var tex = sf.get_frame_texture(anim_name, i)
			if not tex is AtlasTexture:
				continue
			if tex.atlas == null:
				continue
			var frame_h := int(tex.region.size.y)
			if frame_h <= 0:
				continue
			# N'applique que si le spritesheet a assez de rangées
			if tex.atlas.get_height() < (row + 1) * frame_h:
				continue
			tex.region = Rect2(tex.region.position.x, float(row * frame_h), tex.region.size.x, tex.region.size.y)

func _on_hp_changed(_unit: Unit) -> void:
	_update_hp_bar()

func _play_anim(anim_name: String) -> void:
	if _sprite == null or unit.sprite_frames == null:
		return
	if anim_name in unit.sprite_frames.get_animation_names():
		_sprite.play(anim_name)

func _play_idle() -> void:
	if is_instance_valid(_optional_visual) and _optional_visual.has_method("play_idle"):
		_optional_visual.play_idle()
	if _sprite == null or unit.sprite_frames == null:
		return
	_sprite.play(unit.idle_animation)

func _on_unit_moved(_from: Vector2i, _to: Vector2i) -> void:
	_play_anim("walk")

func _on_attack_performed(attacker, _target) -> void:
	if attacker != unit:
		return
	_play_anim("attack")

func _on_any_turn_started(_u) -> void:
	_play_idle()

func _on_died(_unit: Unit) -> void:
	if is_instance_valid(_optional_visual):
		if not _optional_visual.has_signal("death_animation_finished"):
			push_warning("UnitView: visuel optionnel sans death_animation_finished pour %s; il reste affiche." % unit.unit_name)
			return
		var death_state := {"finished": false}
		var mark_finished := func() -> void: death_state["finished"] = true
		_optional_visual.connect("death_animation_finished", mark_finished, CONNECT_ONE_SHOT)
		var deadline := Time.get_ticks_msec() + 8000
		while not death_state["finished"] and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if is_instance_valid(_optional_visual) \
				and _optional_visual.is_connected("death_animation_finished", mark_finished):
			_optional_visual.disconnect("death_animation_finished", mark_finished)
		if death_state["finished"]:
			queue_free()
		else:
			push_warning("UnitView: Death n'a pas termine en 8 s pour %s; le visuel est conserve." % unit.unit_name)
		return
	if _sprite != null and unit.sprite_frames != null \
			and "death" in unit.sprite_frames.get_animation_names():
		_sprite.play("death")
		await _sprite.animation_finished
	queue_free()

func _on_shield_changed(u: Unit) -> void:
	if u != unit:
		return
	_update_shield_bar()

func _on_resource_changed(_unit: Unit) -> void:
	_update_resource_bars()

func _on_stats_changed(_unit: Unit) -> void:
	_update_all_bars()
	_update_status_icons()

func _on_status_changed(u: Unit, _status_data) -> void:
	if u == unit:
		_update_status_icons()

func _on_status_expired(u: Unit, _status_name: String) -> void:
	if u == unit:
		_update_status_icons()

func _on_damage_dealt(target, _attacker, amount: int, _category: int, _element: int, _is_crit: bool) -> void:
	if target != unit:
		return
	_flash(Color(1.0, 0.35, 0.28), 0.14)

func _on_unit_healed(u: Unit, amount: int) -> void:
	if u != unit or amount <= 0:
		return
	_flash(Color(0.42, 1.0, 0.52), 0.16)

func _on_shield_gained(u: Unit, amount: int) -> void:
	if u != unit:
		return
	_flash(Color(0.95, 0.78, 0.24), 0.18)

func _on_shield_absorbed(u: Unit, amount: int) -> void:
	if u != unit:
		return
	_flash(Color(0.4, 0.65, 1.0), 0.15)

func _on_shield_broken(u: Unit) -> void:
	if u != unit:
		return
	_flash(Color(1.0, 0.45, 0.1), 0.25)

func _flash(color: Color, duration: float) -> void:
	if _sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, duration)

func _show_status_tooltip(status_data: StatusData) -> void:
	var layer = _tooltip_layer()
	if layer == null or status_data == null:
		return
	var id := Glossary.keyword_id_for_name(status_data.status_name)
	if id != "":
		layer.show_keyword(id, get_viewport().get_mouse_position())
	else:
		layer.show_text(status_data.status_name, status_data.description, get_viewport().get_mouse_position())

func _hide_keyword_tooltip() -> void:
	var layer = _tooltip_layer()
	if layer != null:
		layer.request_hide()

func _tooltip_layer():
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group("keyword_tooltip_layer")

func _draw() -> void:
	# Lisere d'eveil : fin cadre de la couleur d'ecole autour du sprite tant
	# que l'etat est actif ; disparait a l'expiration (stats_changed relaye).
	if unit != null and unit.has_energy() and unit.charge_threshold_active:
		var school := unit.energy_type.get_school_color()
		draw_rect(Rect2(-UNIT_SIZE / 2.0, -UNIT_SIZE / 2.0, UNIT_SIZE, UNIT_SIZE), Color(school.r, school.g, school.b, 0.9), false, 2.0)
	if unit != null and unit.current_shield > 0:
		var ratio := float(unit.current_shield) / float(max(unit.current_shield, unit.max_hp.get_int()))
		var arc_end := TAU * ratio
		draw_arc(Vector2.ZERO, UNIT_SIZE * 0.82, -PI / 2.0, -PI / 2.0 + arc_end, 32, Color(0.35, 0.65, 1.0, 0.75), 4.0)
	if _is_active:
		if has_optional_visual():
			var diamond := PackedVector2Array([
				Vector2(0.0, -16.0), Vector2(32.0, 0.0),
				Vector2(0.0, 16.0), Vector2(-32.0, 0.0),
				Vector2(0.0, -16.0),
			])
			draw_polyline(diamond, Color(1.0, 0.9, 0.2, 0.62), 1.5, true)
		else:
			draw_arc(Vector2.ZERO, UNIT_SIZE * 0.75, 0, TAU, 32, Color(1.0, 0.9, 0.2), 3.0)
