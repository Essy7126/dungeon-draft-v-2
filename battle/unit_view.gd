# battle/unit_view.gd
extends Node2D

const Glossary = preload("res://ui/combat_glossary.gd")

const UNIT_SIZE = 48

var unit: Unit
var _sprite: AnimatedSprite2D
var _facing_row: int = 0
var _hp_bar: ProgressBar
var _shield_bar: ProgressBar
var _status_row: HBoxContainer
var _is_active: bool = false
var _flash_tween: Tween = null
var _optional_visual: Node2D = null
var _optional_visual_cast_pending := false
var _optional_visual_cast_generation := 0
var _optional_visual_action_pending := false
var _optional_visual_action_finished := false
var _suppress_next_attack_event_visual := false
var _lifecycle_generation := 0
var _closing := false
var _active_release_callables: Array[Callable] = []
var _active_death_callables: Array[Callable] = []
var _painted_presentation: BattlePresentationProfile = null
var _painted_family_profile: UnitVisualProfile = null
var _painted_optional_base_scale := Vector2.ONE
var _painted_visual_scale := 1.0
var _painted_readability_enabled := false

func setup(p_unit: Unit) -> void:
	unit = p_unit
	add_to_group("unit_views")
	_build_visual()
	unit.hp_changed.connect(_on_hp_changed)
	unit.died.connect(_on_died)
	unit.moved.connect(_on_unit_moved)
	unit.shield_changed.connect(_on_shield_changed)
	unit.stats_changed.connect(_on_stats_changed)
	EventBus.basic_attack_performed.connect(_on_attack_performed)
	EventBus.turn_started.connect(_on_any_turn_started)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.unit_healed.connect(_on_unit_healed)
	EventBus.shield_absorbed.connect(_on_shield_absorbed)
	EventBus.shield_broken.connect(_on_shield_broken)
	EventBus.shield_gained.connect(_on_shield_gained)
	EventBus.status_applied.connect(_on_status_changed)
	EventBus.status_refreshed.connect(_on_status_changed)
	EventBus.status_expired.connect(_on_status_expired)
	_update_all_bars()
	_update_status_icons()


func _exit_tree() -> void:
	_closing = true
	_lifecycle_generation += 1
	cancel_pending_visual_actions()
	_disconnect_optional_visual_waits()
	_disconnect_runtime_signals()


func cancel_pending_visual_actions() -> void:
	_optional_visual_cast_generation += 1
	_optional_visual_cast_pending = false
	_optional_visual_action_pending = false
	_optional_visual_action_finished = false
	_suppress_next_attack_event_visual = false
	_disconnect_release_callables()


func _is_async_context_valid(generation: int) -> bool:
	return generation == _lifecycle_generation \
		and not _closing \
		and is_inside_tree()


func _wait_one_safe_process_frame(generation: int) -> bool:
	if not _is_async_context_valid(generation):
		return false
	var tree := get_tree()
	if tree == null:
		return false
	await tree.process_frame
	return _is_async_context_valid(generation)


func _disconnect_release_callable(callback: Callable) -> void:
	if is_instance_valid(_optional_visual) \
			and _optional_visual.has_signal("cast_release_reached") \
			and _optional_visual.is_connected("cast_release_reached", callback):
		_optional_visual.disconnect("cast_release_reached", callback)
	_active_release_callables.erase(callback)


func _disconnect_release_callables() -> void:
	for callback in _active_release_callables.duplicate():
		_disconnect_release_callable(callback)
	_active_release_callables.clear()


func _disconnect_death_callable(callback: Callable) -> void:
	if is_instance_valid(_optional_visual) \
			and _optional_visual.has_signal("death_animation_finished") \
			and _optional_visual.is_connected("death_animation_finished", callback):
		_optional_visual.disconnect("death_animation_finished", callback)
	_active_death_callables.erase(callback)


func _disconnect_optional_visual_waits() -> void:
	_disconnect_release_callables()
	for callback in _active_death_callables.duplicate():
		_disconnect_death_callable(callback)
	_active_death_callables.clear()
	if is_instance_valid(_optional_visual) \
			and _optional_visual.has_signal("animation_finished") \
			and _optional_visual.animation_finished.is_connected(
				_on_optional_visual_action_finished
			):
		_optional_visual.animation_finished.disconnect(
			_on_optional_visual_action_finished
		)


func _disconnect_runtime_signals() -> void:
	if is_instance_valid(unit):
		var unit_connections := [
			[unit.hp_changed, _on_hp_changed],
			[unit.died, _on_died],
			[unit.moved, _on_unit_moved],
			[unit.shield_changed, _on_shield_changed],
			[unit.stats_changed, _on_stats_changed],
		]
		for connection in unit_connections:
			if connection[0].is_connected(connection[1]):
				connection[0].disconnect(connection[1])
	var event_connections := [
		[EventBus.basic_attack_performed, _on_attack_performed],
		[EventBus.turn_started, _on_any_turn_started],
		[EventBus.damage_dealt, _on_damage_dealt],
		[EventBus.unit_healed, _on_unit_healed],
		[EventBus.shield_absorbed, _on_shield_absorbed],
		[EventBus.shield_broken, _on_shield_broken],
		[EventBus.shield_gained, _on_shield_gained],
		[EventBus.status_applied, _on_status_changed],
		[EventBus.status_refreshed, _on_status_changed],
		[EventBus.status_expired, _on_status_expired],
	]
	for connection in event_connections:
		if connection[0].is_connected(connection[1]):
			connection[0].disconnect(connection[1])

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
	_painted_optional_base_scale = _optional_visual.scale
	add_child(_optional_visual)
	_optional_visual.add_to_group("optional_unit_visuals")
	if is_instance_valid(_sprite):
		_sprite.visible = false
	if _optional_visual.has_method("bind_unit"):
		_optional_visual.bind_unit(unit)
	if _optional_visual.has_signal("animation_finished"):
		_optional_visual.animation_finished.connect(_on_optional_visual_action_finished)

func has_optional_visual() -> bool:
	return is_instance_valid(_optional_visual)

func get_optional_visual() -> Node2D:
	return _optional_visual if is_instance_valid(_optional_visual) else null


## Ne touche qu'au rendu enfant. La position, l'echelle historique et l'ordre
## Y-sort de la racine UnitView restent strictement inchanges.
func apply_painted_presentation(
		profile: BattlePresentationProfile,
		apply_visual_scale: bool = true,
		apply_readability: bool = true
	) -> void:
	_painted_presentation = profile
	_painted_family_profile = (
		profile.profile_for_unit(unit.unit_id)
		if profile != null and unit != null else null
	)
	_painted_visual_scale = (
		profile.final_visual_scale(unit.unit_id)
		if apply_visual_scale and profile != null and unit != null else 1.0
	)
	_painted_readability_enabled = apply_readability and profile != null
	if is_instance_valid(_optional_visual):
		_optional_visual.scale = _painted_optional_base_scale * _painted_visual_scale
		_apply_optional_readability()
	for child in get_children():
		if child.is_in_group("iso_ground_shadow"):
			# Le polygone est conserve pour le contour de selection, mais la grande
			# dalle sombre est remplacee par l'ellipse courte du personnage.
			child.visible = not _painted_readability_enabled
	queue_redraw()


func get_painted_visual_scale() -> float:
	return _painted_visual_scale


func get_logical_foot_position() -> Vector2:
	return Vector2.ZERO


func _apply_optional_readability() -> void:
	if not is_instance_valid(_optional_visual) \
			or not _optional_visual.has_method("set_painted_readability"):
		return
	var outline_color := Color.TRANSPARENT
	var shadow_scale := 1.0
	var shadow_opacity := 0.28
	if _painted_presentation != null:
		outline_color = (
			_painted_presentation.active_outline_color
			if _is_active else (
				_painted_presentation.ally_outline_color
				if unit.team == 0 else _painted_presentation.enemy_outline_color
			)
		)
	if _painted_family_profile != null:
		shadow_scale = _painted_family_profile.contact_shadow_scale
		shadow_opacity = _painted_family_profile.contact_shadow_opacity
	_optional_visual.set_painted_readability(
		_painted_readability_enabled and _painted_presentation.outlines_enabled,
		outline_color,
		_painted_presentation.outline_width_px if _painted_presentation != null else 0.0,
		_painted_presentation.contact_shadows_enabled if _painted_presentation != null else false,
		shadow_scale,
		shadow_opacity
	)

func get_cast_effect_origin_global() -> Vector2:
	if is_instance_valid(_optional_visual) \
			and _optional_visual.has_method("get_default_cast_effect_origin"):
		var local_origin: Vector2 = _optional_visual.get_default_cast_effect_origin()
		return _optional_visual.to_global(local_origin)
	return global_position

## Synchronisation visuelle seulement : le calcul du sort reste dans
## SpellCaster. Le bool false ignore un second clic pendant le meme wind-up.
func prepare_spell_visual(target_cell: Vector2i, spell: Spell = null) -> bool:
	if _closing or not is_inside_tree() or not is_instance_valid(unit):
		return false
	face_grid_direction(target_cell - unit.grid_pos)
	if not is_instance_valid(_optional_visual):
		return true
	var has_spell_action := _optional_visual.has_method("play_spell_action")
	if not has_spell_action and not _optional_visual.has_method("play_cast"):
		return true
	if _optional_visual_cast_pending:
		return false
	_optional_visual_cast_pending = true
	_optional_visual_action_pending = true
	_optional_visual_action_finished = false
	_optional_visual_cast_generation += 1
	var cast_generation := _optional_visual_cast_generation
	var started = (
		_optional_visual.play_spell_action(spell)
		if has_spell_action
		else _optional_visual.play_cast()
	)
	if started is bool and not started:
		_optional_visual_cast_pending = false
		_optional_visual_action_pending = false
		return false
	if not _optional_visual.has_signal("cast_release_reached"):
		_optional_visual_cast_pending = false
		_optional_visual_action_pending = false
		return true
	var release_state := {"released": false}
	var mark_released := func() -> void:
		if cast_generation == _optional_visual_cast_generation \
				and not _closing:
			release_state["released"] = true
	_optional_visual.connect("cast_release_reached", mark_released, CONNECT_ONE_SHOT)
	_active_release_callables.append(mark_released)
	var deadline := Time.get_ticks_msec() + 5000
	var lifecycle_generation := _lifecycle_generation
	while cast_generation == _optional_visual_cast_generation \
			and not release_state["released"] \
			and is_instance_valid(unit) and unit.is_alive \
			and is_instance_valid(_optional_visual) \
			and Time.get_ticks_msec() < deadline:
		if not await _wait_one_safe_process_frame(lifecycle_generation):
			break
	_disconnect_release_callable(mark_released)
	var context_active := _is_async_context_valid(lifecycle_generation) \
		and cast_generation == _optional_visual_cast_generation
	if context_active:
		_optional_visual_cast_pending = false
	if context_active and not release_state["released"] \
			and is_instance_valid(_optional_visual) \
			and _optional_visual.has_method("cancel_spell_action"):
		_optional_visual.cancel_spell_action()
	if context_active and not release_state["released"]:
		_optional_visual_action_pending = false
	if context_active and not release_state["released"] \
			and is_instance_valid(unit) and unit.is_alive \
			and Time.get_ticks_msec() >= deadline:
		push_warning("UnitView: cast_release_reached absent apres 5 s pour %s; le cast visuel est annule." % unit.unit_name)
	return context_active \
		and is_instance_valid(unit) and unit.is_alive \
		and release_state["released"]


## Joue l'attaque jusqu'a son impact artistique. Les degats restent entierement
## dans le systeme de combat et ne sont appliques qu'apres le retour true.
func prepare_basic_attack_visual(target_cell: Vector2i) -> bool:
	if _closing or not is_inside_tree() or not is_instance_valid(unit):
		return false
	face_grid_direction(target_cell - unit.grid_pos)
	if not is_instance_valid(_optional_visual) \
			or not _optional_visual.has_method("play_basic_attack"):
		return true
	if _optional_visual_cast_pending:
		return false
	_optional_visual_cast_pending = true
	_optional_visual_action_pending = true
	_optional_visual_action_finished = false
	_optional_visual_cast_generation += 1
	var cast_generation := _optional_visual_cast_generation
	var started = _optional_visual.play_basic_attack()
	if started is bool and not started:
		_optional_visual_cast_pending = false
		_optional_visual_action_pending = false
		return false
	if not _optional_visual.has_signal("cast_release_reached"):
		_optional_visual_cast_pending = false
		_optional_visual_action_pending = false
		return true
	var release_state := {"released": false}
	var mark_released := func() -> void:
		if cast_generation == _optional_visual_cast_generation \
				and not _closing:
			release_state["released"] = true
	_optional_visual.connect("cast_release_reached", mark_released, CONNECT_ONE_SHOT)
	_active_release_callables.append(mark_released)
	var deadline := Time.get_ticks_msec() + 5000
	var lifecycle_generation := _lifecycle_generation
	while cast_generation == _optional_visual_cast_generation \
			and not release_state["released"] \
			and is_instance_valid(unit) and unit.is_alive \
			and is_instance_valid(_optional_visual) \
			and Time.get_ticks_msec() < deadline:
		if not await _wait_one_safe_process_frame(lifecycle_generation):
			break
	_disconnect_release_callable(mark_released)
	var context_active := _is_async_context_valid(lifecycle_generation) \
		and cast_generation == _optional_visual_cast_generation
	if context_active:
		_optional_visual_cast_pending = false
	if context_active and not release_state["released"]:
		_optional_visual_action_pending = false
	if context_active and not release_state["released"] \
			and is_instance_valid(unit) and unit.is_alive \
			and Time.get_ticks_msec() >= deadline:
		push_warning("UnitView: impact d'attaque absent apres 5 s pour %s." % unit.unit_name)
	var released: bool = context_active \
		and is_instance_valid(unit) and unit.is_alive \
		and release_state["released"]
	if released:
		_suppress_next_attack_event_visual = true
	return released


## Attend la recuperation de l'Action deja declenchee, sans rejouer d'animation.
func wait_for_action_visual_finished(timeout_msec: int = 8000) -> void:
	if not _optional_visual_action_pending:
		_suppress_next_attack_event_visual = false
		return
	var lifecycle_generation := _lifecycle_generation
	var cast_generation := _optional_visual_cast_generation
	var deadline := Time.get_ticks_msec() + maxi(timeout_msec, 1)
	while not _optional_visual_action_finished \
			and cast_generation == _optional_visual_cast_generation \
			and is_instance_valid(_optional_visual) \
			and Time.get_ticks_msec() < deadline:
		if not await _wait_one_safe_process_frame(lifecycle_generation):
			return
	if not _is_async_context_valid(lifecycle_generation) \
			or cast_generation != _optional_visual_cast_generation:
		return
	if not _optional_visual_action_finished \
			and is_instance_valid(_optional_visual) \
			and Time.get_ticks_msec() >= deadline:
		push_warning("UnitView: recuperation visuelle incomplete pour %s." % unit.unit_name)
	_optional_visual_action_pending = false
	_optional_visual_action_finished = false
	_suppress_next_attack_event_visual = false


func _on_optional_visual_action_finished(_animation_name: StringName) -> void:
	if _optional_visual_action_pending:
		_optional_visual_action_finished = true

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
	_apply_optional_readability()
	queue_redraw()

## Applique un materiau lumiere (golden hour) aux visuels du perso pour qu'il se
## fonde dans le decor. Parcourt TOUT le sous-arbre et vise les sprites
## (Sprite2D / AnimatedSprite2D) + le placeholder iso, peu importe la profondeur.
## pas des sprites, donc naturellement epargnees.
func set_light_material(mat: Material) -> void:
	# On pose le materiau sur la racine de l'UnitView, puis on force TOUS les
	# visuels descendants (Node2D) a utiliser CE materiau via use_parent_material.
	# Robuste : meme si un visuel (ex : elfe 3D) reassigne son propre material,
	# use_parent_material le fait ignorer et rendre avec la lumiere golden hour.
	material = mat
	_use_parent_light_recursive(self)


## Teinte chaude appliquee aux visuels 3D via modulate (multiplication simple,
## sans shader canvas -> aucun artefact sur les rendus SubViewport).
const _VISUAL_3D_WARM := Color(1.0, 0.95, 0.82)


func _use_parent_light_recursive(node: Node) -> void:
	for child in node.get_children():
		if child.is_in_group("iso_ground_shadow"):
			continue  # l'ombre au sol conserve son propre rendu
		if child.is_in_group("optional_unit_visuals"):
			# Visuel 3D (elfe/mage) : le shader canvas cree des artefacts sur le
			# rendu SubViewport. On ne l'y applique PAS ; teinte chaude via
			# modulate a la place, et on NE descend PAS dans son sous-arbre.
			if child is CanvasItem:
				(child as CanvasItem).modulate = _VISUAL_3D_WARM
			continue
		if child is Node2D:
			(child as CanvasItem).use_parent_material = true
		_use_parent_light_recursive(child)

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
	if _suppress_next_attack_event_visual:
		_suppress_next_attack_event_visual = false
	elif is_instance_valid(_optional_visual) \
			and _optional_visual.has_method("play_basic_attack"):
		_optional_visual.play_basic_attack()
	_play_anim("attack")

func _on_any_turn_started(_u) -> void:
	_play_idle()

func _on_died(_unit: Unit) -> void:
	cancel_pending_visual_actions()
	var lifecycle_generation := _lifecycle_generation
	if is_instance_valid(_optional_visual):
		if not _optional_visual.has_signal("death_animation_finished"):
			push_warning("UnitView: visuel optionnel sans death_animation_finished pour %s; il reste affiche." % unit.unit_name)
			return
		var death_state := {"finished": false}
		var mark_finished := func() -> void: death_state["finished"] = true
		_optional_visual.connect("death_animation_finished", mark_finished, CONNECT_ONE_SHOT)
		_active_death_callables.append(mark_finished)
		var deadline := Time.get_ticks_msec() + 8000
		while not death_state["finished"] and Time.get_ticks_msec() < deadline:
			if not await _wait_one_safe_process_frame(lifecycle_generation):
				break
		_disconnect_death_callable(mark_finished)
		if not _is_async_context_valid(lifecycle_generation):
			return
		if death_state["finished"]:
			queue_free()
		elif Time.get_ticks_msec() >= deadline:
			push_warning("UnitView: Death n'a pas termine en 8 s pour %s; le visuel est conserve." % unit.unit_name)
		return
	if _sprite != null and unit.sprite_frames != null \
			and "death" in unit.sprite_frames.get_animation_names():
		_sprite.play("death")
		await _sprite.animation_finished
	if _is_async_context_valid(lifecycle_generation):
		queue_free()

func _on_shield_changed(u: Unit) -> void:
	if u != unit:
		return
	_update_shield_bar()

func _on_stats_changed(_unit: Unit) -> void:
	_update_all_bars()
	_update_status_icons()

func _on_status_changed(u: Unit, _status_data) -> void:
	if u == unit:
		_update_status_icons()

func _on_status_expired(u: Unit, _status_id: StringName) -> void:
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
	if unit != null and unit.current_shield > 0:
		var ratio := float(unit.current_shield) / float(max(unit.current_shield, unit.max_hp.get_int()))
		var arc_end := TAU * ratio
		draw_arc(Vector2.ZERO, UNIT_SIZE * 0.82, -PI / 2.0, -PI / 2.0 + arc_end, 32, Color(0.35, 0.65, 1.0, 0.75), 4.0)
	if _is_active:
		# Si une ombre skewee epouse la case (salles iso), on cale la surbrillance
		# d'unite active dessus : meme forme, meme taille, meme inclinaison que la
		# case du TerrainLayer. Sinon, rendu historique (losange fixe / arc).
		var footprint := _active_cell_footprint()
		if footprint.size() >= 3:
			var outline := PackedVector2Array(footprint)
			outline.append(footprint[0])
			draw_polyline(outline, Color(1.0, 0.9, 0.2, 0.9), 2.0, true)
		elif has_optional_visual():
			var diamond := PackedVector2Array([
				Vector2(0.0, -16.0), Vector2(32.0, 0.0),
				Vector2(0.0, 16.0), Vector2(-32.0, 0.0),
				Vector2(0.0, -16.0),
			])
			draw_polyline(diamond, Color(1.0, 0.9, 0.2, 0.62), 1.5, true)
		else:
			draw_arc(Vector2.ZERO, UNIT_SIZE * 0.75, 0, TAU, 32, Color(1.0, 0.9, 0.2), 3.0)


## Contour de la case skewee, recupere aupres de l'ombre au sol (iso). Vide dans
## les salles carrees classiques (aucune ombre iso) -> rendu historique.
func _active_cell_footprint() -> PackedVector2Array:
	for child in get_children():
		if child.is_in_group("iso_ground_shadow") and child.has_method("get_footprint"):
			return child.get_footprint()
	return PackedVector2Array()
