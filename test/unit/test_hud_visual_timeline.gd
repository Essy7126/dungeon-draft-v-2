extends GutTest

const TIMELINE_SCENE := preload("res://ui/combat/turn_order_timeline.tscn")
const FACTORY := preload("res://test/support/factory.gd")
const PREMIUM_SKIN: HudVisualSkinData = preload(
	"res://data/ui/hud_visual_skin_achilles_v1.tres"
)


func test_timeline_uses_visual_skin_and_honors_reduced_motion() -> void:
	var first: Unit = FACTORY.make_unit("Premier", 0)
	var second: Unit = FACTORY.make_unit("Second", 1)
	var third: Unit = FACTORY.make_unit("Troisième", 0)
	var queue := TurnQueue.new()
	queue.setup([first, second, third])
	var timeline := TIMELINE_SCENE.instantiate() as TurnOrderTimeline
	add_child_autofree(timeline)
	await get_tree().process_frame
	timeline.set_reduced_motion(true)
	timeline.bind_queue(queue)
	queue.start()
	await get_tree().process_frame

	assert_eq(timeline.layer, 24)
	assert_true(timeline.is_reduced_motion_enabled())
	assert_eq(timeline.get_card_count(), 3)
	var first_card := timeline.cards_layer.get_child(0) as TurnOrderCard
	assert_not_null(first_card)
	assert_eq(first_card.theme_type_variation, &"HudSpellSlot")
	assert_true(first_card.active_marker.visible)
	assert_almost_eq(
		first_card.team_accent.color.r,
		first_card.team_accent.color.g,
		0.001,
	)
	assert_almost_eq(
		first_card.team_accent.color.g,
		first_card.team_accent.color.b,
		0.001,
	)

	queue.advance()
	await get_tree().process_frame
	assert_false(timeline.is_animating())
	assert_eq(timeline.get_display_order(), [third, second, first])


func test_premium_timeline_exposes_compact_cards_and_persistent_turn_plate() -> void:
	var achilles: Unit = FACTORY.make_unit("Achille", 0)
	var queue := TurnQueue.new()
	queue.setup([achilles])
	var timeline := TIMELINE_SCENE.instantiate() as TurnOrderTimeline
	add_child_autofree(timeline)
	await get_tree().process_frame
	timeline.apply_visual_skin(PREMIUM_SKIN)
	timeline.bind_queue(queue)
	queue.start()
	await get_tree().process_frame

	assert_true(timeline.turn_header.visible)
	assert_eq(timeline.turn_header_title.text, "TOUR D’ACHILLE")
	var card := timeline.cards_layer.get_child(0) as TurnOrderCard
	assert_not_null(card)
	assert_true(card.premium_frame.visible)
	assert_lt(card.custom_minimum_size.x, 90.0)
	assert_lt(timeline.cards_layer.offset_top, 24.0)
