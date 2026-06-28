# battle/unit_view.gd
extends Node2D

const Glossary = preload("res://ui/combat_glossary.gd")

const UNIT_SIZE = 48

var unit: Unit
var _sprite: AnimatedSprite2D
var _facing_row: int = 0
var _hp_bar: ProgressBar
var _shield_bar: ProgressBar
var _elan_bar: ProgressBar
var _fervor_bar: ProgressBar
var _status_row: HBoxContainer
var _is_active: bool = false
var _flash_tween: Tween = null
var _last_threshold_active: bool = false

func setup(p_unit: Unit) -> void:
	unit = p_unit
	_last_threshold_active = unit.charge_threshold_active
	_build_visual()
	unit.hp_changed.connect(_on_hp_changed)
	unit.died.connect(_on_died)
	unit.moved.connect(_on_unit_moved)
	unit.shield_changed.connect(_on_shield_changed)
	unit.elan_changed.connect(_on_resource_changed)
	unit.energy_changed.connect(_on_resource_changed)
	unit.stats_changed.connect(_on_stats_changed)
	EventBus.basic_attack_performed.connect(_on_attack_performed)
	EventBus.turn_started.connect(_on_any_turn_started)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.unit_healed.connect(_on_unit_healed)
	EventBus.energy_generated.connect(_on_energy_generated)
	EventBus.elan_generated.connect(_on_elan_generated)
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

	_elan_bar = _make_bar(Vector2(UNIT_SIZE, 4), Vector2(-UNIT_SIZE / 2.0, 35), Color(0.42, 0.84, 1.0))
	add_child(_elan_bar)

	_fervor_bar = _make_bar(Vector2(UNIT_SIZE, 4), Vector2(-UNIT_SIZE / 2.0, 41), Color(0.86, 0.74, 1.0))
	add_child(_fervor_bar)

	_status_row = HBoxContainer.new()
	_status_row.position = Vector2(-UNIT_SIZE / 2.0, -66)
	_status_row.add_theme_constant_override("separation", 2)
	add_child(_status_row)

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
	if _elan_bar == null or _fervor_bar == null:
		return
	if unit.team != 0 and not unit.has_energy():
		_elan_bar.visible = false
		_fervor_bar.visible = false
		return
	_elan_bar.visible = true
	_elan_bar.max_value = maxf(1.0, unit.max_elan)
	_elan_bar.value = unit.current_elan
	if not unit.has_energy():
		_fervor_bar.visible = false
		return
	_fervor_bar.visible = true
	_fervor_bar.max_value = maxf(1.0, unit.energy_type.max_energy)
	_fervor_bar.value = unit.current_energy
	var fill := StyleBoxFlat.new()
	fill.bg_color = unit.energy_type.color
	_fervor_bar.add_theme_stylebox_override("fill", fill)
	if not _last_threshold_active and unit.charge_threshold_active:
		_flash(unit.energy_type.color, 0.35)
		_show_floating_number(unit.energy_type.threshold_name, unit.energy_type.color)
	_last_threshold_active = unit.charge_threshold_active

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
	_show_floating_number("-%d" % amount, Color(1.0, 0.28, 0.22))

func _on_unit_healed(u: Unit, amount: int) -> void:
	if u != unit or amount <= 0:
		return
	_flash(Color(0.42, 1.0, 0.52), 0.16)
	_show_floating_number("+%d" % amount, Color(0.42, 1.0, 0.52))

func _on_energy_generated(u: Unit, _energy_id: String, amount: float) -> void:
	if u != unit or amount <= 0.0:
		return
	var color := unit.energy_type.color if unit.has_energy() else Color(0.86, 0.74, 1.0)
	_show_floating_number("+%d" % int(round(amount)), color)

func _on_elan_generated(u: Unit, amount: float) -> void:
	if u != unit or amount <= 0.0:
		return
	_show_floating_number("+%d Elan" % int(round(amount)), Color(0.42, 0.84, 1.0))

func _on_shield_gained(u: Unit, amount: int) -> void:
	if u != unit:
		return
	_flash(Color(0.95, 0.78, 0.24), 0.18)
	_show_floating_number("+%d" % amount, Color(1.0, 0.82, 0.30))

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

func _show_floating_number(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.position = Vector2(-20, -UNIT_SIZE - 4)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", -UNIT_SIZE - 28, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)

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
	if unit != null and unit.current_shield > 0:
		var ratio := float(unit.current_shield) / float(max(unit.current_shield, unit.max_hp.get_int()))
		var arc_end := TAU * ratio
		draw_arc(Vector2.ZERO, UNIT_SIZE * 0.82, -PI / 2.0, -PI / 2.0 + arc_end, 32, Color(0.35, 0.65, 1.0, 0.75), 4.0)
	if _is_active:
		draw_arc(Vector2.ZERO, UNIT_SIZE * 0.75, 0, TAU, 32, Color(1.0, 0.9, 0.2), 3.0)