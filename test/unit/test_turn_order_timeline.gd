extends GutTest

const TIMELINE_SCENE := preload("res://ui/combat/turn_order_timeline.tscn")
const ACHILLES_DATA: UnitData = preload("res://data/units/allies/achilles.tres")
const Factory := preload("res://test/support/factory.gd")


func test_timeline_rotates_scales_animates_and_selects_units() -> void:
	var first: Unit = Factory.make_unit("Premier", 0)
	var second: Unit = Factory.make_unit("Deuxième", 1)
	var third: Unit = Factory.make_unit("Troisième", 0)
	var queue := TurnQueue.new()
	queue.setup([first, second, third])
	var timeline = TIMELINE_SCENE.instantiate()
	add_child_autofree(timeline)
	await get_tree().process_frame
	timeline.bind_queue(queue)
	queue.start()
	await get_tree().process_frame
	assert_eq(timeline.get_card_count(), 3)
	assert_eq(timeline.get_display_order(), [first, third, second])
	var cards: Array[Node] = timeline.cards_layer.get_children()
	var first_card: Control = _find_card(cards, first)
	var third_card: Control = _find_card(cards, third)
	assert_not_null(first_card)
	assert_not_null(third_card)
	# Control layout can clamp the live size by sub-pixel amounts; the timeline's
	# authored minimum sizes are the deterministic rank contract.
	assert_gt(
		first_card.custom_minimum_size.x,
		third_card.custom_minimum_size.x,
	)
	assert_gt(
		first_card.custom_minimum_size.y,
		third_card.custom_minimum_size.y,
	)
	var selected: Array[Unit] = []
	timeline.unit_selected.connect(func(unit: Unit): selected.append(unit))
	first_card.pressed.emit()
	assert_eq(selected, [first])
	queue.advance()
	assert_true(timeline.is_animating())
	assert_eq(timeline.get_display_order(), [third, second, first])
	timeline.finish_animation_for_test()
	await get_tree().process_frame
	assert_gt(first_card.position.y, third_card.position.y)
	second.is_alive = false
	queue.on_unit_died(second)
	assert_eq(timeline.get_card_count(), 2)
	assert_eq(timeline.get_display_order(), [third, first])


func test_achilles_card_uses_same_sprite_preview_without_3d_model() -> void:
	assert_null(ACHILLES_DATA.preview_visual_scene)
	assert_not_null(ACHILLES_DATA.preview_sprite_frames)
	var achilles := Unit.from_data(ACHILLES_DATA)
	assert_null(achilles.sprite_frames)
	var queue := TurnQueue.new()
	queue.setup([achilles])
	var timeline = TIMELINE_SCENE.instantiate()
	add_child_autofree(timeline)
	await get_tree().process_frame
	timeline.bind_queue(queue)
	queue.start()
	await get_tree().process_frame
	var cards: Array[Node] = timeline.cards_layer.get_children()
	var achilles_card := _find_card(cards, achilles) as TurnOrderCard
	assert_not_null(achilles_card)
	if achilles_card == null:
		return
	assert_true(achilles_card.preview.visible)
	assert_false(achilles_card.fallback_portrait.visible)
	assert_true(achilles_card.preview.is_using_sprite_preview())
	assert_false(achilles_card.preview.is_using_fallback())
	assert_null(achilles_card.preview.get_visual_instance())
	assert_false(achilles_card.preview.viewport_container.visible)
	assert_eq(achilles_card.preview.preview_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	assert_eq(achilles_card.preview.visual_root.get_child_count(), 0)
	var sprite := achilles_card.preview.get_sprite_instance()
	assert_not_null(sprite)
	if sprite == null:
		return
	assert_eq(sprite.sprite_frames, ACHILLES_DATA.preview_sprite_frames)
	assert_eq(sprite.animation, ACHILLES_DATA.preview_sprite_animation)
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())
	assert_false(sprite.flip_h)


func _find_card(cards: Array[Node], unit: Unit) -> Control:
	for node in cards:
		if node.get("unit") == unit:
			return node
	return null
