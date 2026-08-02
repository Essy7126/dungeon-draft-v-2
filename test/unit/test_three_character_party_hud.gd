extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const ActionBarScript = preload("res://ui/action_bar.gd")

const PARTY := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]

var manager

func before_each() -> void:
	manager = GameManagerScript.new()
	var run := RunData.new()
	run.rooms.append(RoomData.new())
	assert_true(manager._prepare_preconfigured_run(run, PARTY))

func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager.free()

func test_hud_cycles_fixed_party_with_exactly_four_spells_each() -> void:
	var bar = ActionBarScript.new()
	add_child_autofree(bar)
	for hero in manager.get_ordered_heroes():
		bar.update_info(hero)
		bar.build_spell_buttons(hero)
		assert_eq(bar.get("_spell_buttons").size(), 4)
		assert_true(bar.get("_info_label").text.contains(hero.unit_name))

func test_switch_disconnects_previous_unit_stats_signal() -> void:
	var heroes: Array[Unit] = manager.get_ordered_heroes()
	var bar = ActionBarScript.new()
	add_child_autofree(bar)
	var callback := Callable(bar, "_on_resource_changed")
	bar.update_info(heroes[0])
	assert_true(heroes[0].stats_changed.is_connected(callback))
	bar.update_info(heroes[1])
	assert_false(heroes[0].stats_changed.is_connected(callback))
	assert_true(heroes[1].stats_changed.is_connected(callback))

func test_spell_signal_emits_one_spell_argument() -> void:
	var hero: Unit = manager.get_ordered_heroes()[0]
	var bar = ActionBarScript.new()
	add_child_autofree(bar)
	bar.update_info(hero)
	bar.build_spell_buttons(hero)
	var received: Array = []
	bar.spell_pressed.connect(func(spell): received.append(spell))
	bar.get("_spell_buttons")[0].pressed.emit()
	assert_eq(received, [hero.spells[0]])
