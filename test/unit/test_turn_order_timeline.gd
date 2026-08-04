extends GutTest

const TIMELINE_SCENE := preload("res://ui/combat/turn_order_timeline.tscn")
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
	assert_gt(first_card.size.x, third_card.size.x)
	assert_gt(first_card.size.y, third_card.size.y)
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


func _find_card(cards: Array[Node], unit: Unit) -> Control:
	for node in cards:
		if node.get("unit") == unit:
			return node
	return null
