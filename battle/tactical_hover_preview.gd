extends CanvasLayer
## Inspection passive. Aucun changement de sélection, de PM ou d'unité active.
const PALETTE := preload("res://ui/combat/tactical_palette.gd")
var battle: Node2D
var hovered_unit: Unit
var _signature := ""
var _pointer_position := Vector2.ZERO
var _texture_bounds: Dictionary = { }
var _panel: PanelContainer
var _title: Label
var _resources: RichTextLabel
var _hint: Label


func _ready() -> void:
	layer = 8
	_pointer_position = get_viewport().get_mouse_position()
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172623f5")
	style.border_color = PALETTE.MOVEMENT.darkened(0.25)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	_panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 17)
	_title.add_theme_color_override("font_color", Color("f4f0e5"))
	column.add_child(_title)
	_resources = RichTextLabel.new()
	_resources.bbcode_enabled = true
	_resources.fit_content = true
	_resources.scroll_active = false
	_resources.custom_minimum_size.x = 236
	_resources.add_theme_font_size_override("normal_font_size", 16)
	column.add_child(_resources)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", PALETTE.MOVEMENT)
	column.add_child(_hint)
	for child in column.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer_position = event.position


func _process(_delta: float) -> void:
	if not is_instance_valid(battle) or battle.grid == null:
		return
	var unit: Unit = null
	if can_preview() and get_viewport().gui_get_hovered_control() == null:
		unit = pick_unit(_pointer_position)
	show_unit(unit)
	if _panel.visible:
		var pointer := _pointer_position
		var bounds := get_viewport().get_visible_rect().size
		_panel.position = Vector2(
			clampf(pointer.x + 24, 12, maxf(12, bounds.x - _panel.size.x - 12)),
			clampf(pointer.y - _panel.size.y - 20, 12, maxf(12, bounds.y - _panel.size.y - 12)),
		)


func can_preview() -> bool:
	return (
		battle.turn_state != null
		and battle.turn_state.current in [TurnState.State.IDLE, TurnState.State.MOVE]
		and not battle._battle_over and not battle._closing and battle._can_accept_player_intent()
		and (battle._deployment == null or not battle._deployment.is_active())
	)


func pick_unit(pointer: Vector2) -> Unit:
	# Inclut la tête et le corps réellement affichés, malgré les échelles et les
	# marges transparentes des sprites. Départage par profondeur si superposés.
	var picked: Unit = null
	var depth := -INF
	for actor: Unit in battle._unit_views:
		if (
			not is_instance_valid(actor) or not actor.is_alive
			or not is_instance_valid(battle._unit_views[actor])
		):
			continue
		# A death animation may free its view before the registry entry is removed.
		# Validate before assigning to a typed variable: a freed object cannot be cast.
		var view: Node2D = battle._unit_views[actor]
		if not view.is_visible_in_tree():
			continue
		var transform := view.get_global_transform_with_canvas()
		if transform.origin.y > depth and _view_contains_pointer(view, pointer):
			picked = actor
			depth = transform.origin.y
	if picked != null:
		return picked
	var grid_view: Node2D = battle.grid_view
	var local := grid_view.get_global_transform_with_canvas().affine_inverse() * pointer
	var cell: Vector2i
	if grid_view.has_method("local_to_grid"):
		cell = grid_view.local_to_grid(local)
	else:
		cell = grid_view.world_to_grid(local)
	return battle.grid.get_unit(cell) as Unit


func _view_contains_pointer(view: Node2D, pointer: Vector2) -> bool:
	var visible_sprite := false
	for node in view.find_children("*", "Node2D", true, false):
		if node.get_viewport() != get_viewport() or not node.is_visible_in_tree():
			continue
		if node is AnimatedSprite2D:
			var sprite := node as AnimatedSprite2D
			if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(
					sprite.animation
				):
				continue
			var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
			if texture == null:
				continue
			visible_sprite = true
			var point: Vector2 = sprite.get_global_transform_with_canvas().affine_inverse() * pointer
			point -= sprite.offset
			var dimensions := texture.get_size()
			if sprite.centered:
				point += dimensions * 0.5
			if sprite.flip_h:
				point.x = dimensions.x - point.x
			if sprite.flip_v:
				point.y = dimensions.y - point.y
			if not Rect2(Vector2.ZERO, dimensions).has_point(point):
				continue
			var key := str(texture.get_instance_id())
			if texture is AtlasTexture:
				key += ":" + str(texture.region)
			if not _texture_bounds.has(key):
				var image := texture.get_image()
				_texture_bounds[key] = (
					Rect2(image.get_used_rect())
					if image != null
					else Rect2(Vector2.ZERO, dimensions)
				)
			if (_texture_bounds[key] as Rect2).grow(2).has_point(point):
				return true
		elif node is Sprite2D and node.texture != null:
			visible_sprite = true
			var point: Vector2 = node.get_global_transform_with_canvas().affine_inverse() * pointer
			if node.get_rect().has_point(point):
				return true
	# Les marqueurs de laboratoire n'ont pas nécessairement de sprite.
	return (
		not visible_sprite
		and Rect2(-22, -58, 44, 66).has_point(
			view.get_global_transform_with_canvas().affine_inverse() * pointer
		)
	)


func show_unit(unit: Unit) -> void:
	if not can_preview() or not is_instance_valid(unit) or not unit.is_alive:
		unit = null
	if unit != null:
		# Le pointeur peut traverser plusieurs cases derrière un grand sprite.
		# Leur chemin de déplacement ne doit pas recouvrir la portée inspectée.
		battle._clear_movement_path_preview()
		battle._clear_target_hover_feedback()
	var signature := (
		""
		if unit == null
		else "%s:%s:%s:%s:%s:%s"
		% [
			unit.get_instance_id(),
			unit.grid_pos,
			unit.current_hp,
			unit.current_ap,
			unit.current_mp,
			battle.turn_state.current,
		]
	)
	if signature == _signature:
		return
	var had_preview := not _signature.is_empty()
	_signature = signature
	hovered_unit = unit
	_panel.visible = unit != null
	if unit == null:
		if (
			had_preview and battle.turn_state != null
			and battle.turn_state.current in [TurnState.State.IDLE, TurnState.State.MOVE]
		):
			if can_preview() and battle.turn_state.current == TurnState.State.MOVE:
				battle._on_request_show_move_range()
			else:
				battle._on_request_clear_highlights()
		return
	battle._draw_movement_range(unit)
	_title.text = unit.unit_name + (" · Allié" if unit.team == 0 else " · Ennemi")
	_resources.text = "[color=#ed8092]♥ %d/%d PV[/color]   [color=#74c7ed]★ %d PA[/color]   [color=#9dd18b]◆ %d PM[/color]" % [
		unit.current_hp,
		unit.max_hp.get_int(),
		unit.current_ap,
		unit.current_mp,
	]
	_hint.text = "● Déplacement · %d PM restant%s" % [
		unit.current_mp,
		"" if unit.current_mp == 1 else "s",
	]
	if unit.current_mp <= 0:
		_hint.text = "Aucun PM restant"
	elif not battle.pathfinder.get_engaging_controllers(unit).is_empty():
		_hint.text += " · Engagement"
	_panel.reset_size()
