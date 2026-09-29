extends "res://tools/consumable_cards/integrated_capture.gd"
## Exerce la vraie Battle du parcours public. Aucun lancement de sort factice.


func capture(label: String) -> void:
	await super.capture(label)
	if label != "03_combat_main":
		return
	var hover = scene.get_node("TacticalHoverPreview")
	var actor: Unit = scene.get_active_unit()
	var enemy: Unit = null
	for unit: Unit in scene.grid.get_units():
		if unit.team != actor.team:
			enemy = unit
			break
	check(enemy != null, "enemy present")
	if enemy == null:
		return
	for subject: Unit in [actor, enemy]:
		var view: Node2D = scene._unit_views[subject]
		var pointer := view.get_global_transform_with_canvas() * Vector2(0, -24)
		check(hover.pick_unit(pointer) == subject, "torso picking " + subject.unit_name)
		await _move_pointer(pointer)
		check(hover.hovered_unit == subject, "mouse motion opens hover " + subject.unit_name)
		for sprite in view.find_children("*", "AnimatedSprite2D", true, false):
			if not sprite.is_visible_in_tree() or sprite.sprite_frames == null:
				continue
			var texture: Texture2D = sprite.sprite_frames.get_frame_texture(
				sprite.animation,
				sprite.frame,
			)
			if texture == null:
				continue
			var bounds: Rect2 = Rect2(texture.get_image().get_used_rect())
			var head := Vector2(bounds.get_center().x, bounds.position.y + bounds.size.y * 0.12)
			if sprite.centered:
				head -= texture.get_size() * 0.5
			head += sprite.offset
			await _move_pointer(sprite.get_global_transform_with_canvas() * head)
			check(
				hover.hovered_unit == subject,
				"actual sprite head opens hover " + subject.unit_name,
			)
			break
		check(hover._panel.visible, "hover panel " + subject.unit_name)
		for cell in scene.pathfinder.get_reachable(subject.grid_pos, subject.current_mp, subject):
			check(scene.grid_view.get_highlight_snapshot().has(cell), "reachable cell shown")
		await super.capture("06_hover_hero" if subject == actor else "07_hover_enemy")
	await _move_pointer(scene.action_bar._move_btn.get_global_rect().get_center())
	check(not hover._panel.visible, "HUD hides hover panel")
	check(scene.grid_view.get_highlight_snapshot().is_empty(), "hover exit clears range")
	# Une capacité du catalogue classique fournit une portée 2–6 et une ligne de
	# vue pour la capture de lecture. On la sélectionne sans la lancer ni l'ajouter au kit.
	var spell: Spell = load("res://data/spells/achilles/pelion_shot.tres")
	scene.turn_state.on_spell_selected(spell)
	check(scene.grid_view.get_highlight_snapshot().size() > 5, "full spell range visible")
	await super.capture("08_spell_range")
	var targets: Array = scene.spell_caster.get_targetable_cells(actor, spell)
	if not targets.is_empty():
		scene._on_cell_hovered(targets[0])
		await super.capture("09_spell_target")
	scene.cancel_active_selection()
	check(scene.grid_view.get_highlight_snapshot().is_empty(), "cancel clears spell range")
	var ap := actor.current_ap
	var mp := actor.current_mp
	actor.current_ap = 0
	actor.current_mp = 0
	scene.action_bar._refresh_resource_bars(actor, false)
	await super.capture("10_resources_empty")
	actor.current_ap = ap
	actor.current_mp = mp
	scene.action_bar._refresh_resource_bars(actor, false)


func _move_pointer(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion)
	for _frame in 3:
		await get_tree().process_frame
