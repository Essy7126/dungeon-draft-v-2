extends GutTest

const BATTLE_SCRIPT := preload("res://battle/battle.gd")


func test_dead_active_unit_ends_its_turn_exactly_once() -> void:
	var active := Unit.new("Unité active", 0, 100)
	var next_unit := Unit.new("Unité suivante", 0, 100)
	var queue := TurnQueue.new()
	queue.setup([active, next_unit])
	queue.start()
	assert_same(queue.get_current_unit(), active)
	var battle = BATTLE_SCRIPT.new()
	battle.turn_queue = queue
	active.is_alive = false
	assert_true(battle._end_active_turn_if_dead(active))
	assert_same(queue.get_current_unit(), next_unit)
	assert_false(battle._end_active_turn_if_dead(active))
	battle.free()


func test_all_dead_queue_stops_without_emitting_false_rounds() -> void:
	var active := Unit.new("Dernière unité", 0, 100)
	var queue := TurnQueue.new()
	queue.setup([active])
	queue.start()
	assert_eq(queue.round_number, 1)
	var rounds: Array[int] = []
	queue.round_started.connect(func(number: int): rounds.append(number))
	active.is_alive = false

	assert_false(queue.advance())

	assert_eq(rounds, [])
	assert_eq(queue.round_number, 1)
	assert_same(queue.get_current_unit(), active)
