extends GutTest

const HUD_SCENE := "res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn"
const FIRST_ROOM_SCENE := "res://data/rooms/maps/painted_battle.tscn"
const PROCESSED_DIR := "res://asset/ui/recraft_hud_v1/processed"
const PARTY := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]

func after_each() -> void:
	GameManager.cleanup_run_state()

func test_recraft_components_and_processed_assets_load() -> void:
	for path in [
		"%s/spell_slot_base.png" % PROCESSED_DIR,
		"%s/spellbar_panel.png" % PROCESSED_DIR,
		"%s/resource_bar_frame.png" % PROCESSED_DIR,
		"%s/portrait_frame.png" % PROCESSED_DIR,
		HUD_SCENE,
	]:
		assert_true(ResourceLoader.exists(path), path)
		assert_not_null(load(path), path)

func test_first_room_binds_the_persistent_recraft_hud() -> void:
	var run := load("res://data/runs/first_run.tres") as RunData
	assert_true(GameManager._prepare_preconfigured_run(run, PARTY))
	GameManager.current_room_index = 0
	var battle := (load(FIRST_ROOM_SCENE) as PackedScene).instantiate()
	add_child_autofree(battle)
	assert_not_null(battle.action_bar)
	assert_eq(battle.action_bar.scene_file_path, HUD_SCENE)
	assert_same(battle.action_bar, GameManager.get_persistent_run_ui().get_combat_hud())
	assert_true(battle.action_bar.end_turn_pressed.is_connected(
		Callable(battle, "_on_end_turn_pressed")
	))
	assert_not_null(battle.turn_order_timeline)
	assert_false(battle.units.is_empty())
	var inspected_unit := battle.units[0] as Unit
	battle._on_turn_order_unit_selected(inspected_unit)
	assert_true(battle.inspect_panel.visible)
	assert_same(battle.inspect_panel.get("_displayed_unit"), inspected_unit)
	assert_true(battle.inspect_panel.is_locked())
	battle.inspect_panel.release_lock()
	await get_tree().process_frame

func test_hud_builds_four_real_slots_for_every_fixed_hero() -> void:
	var run := load("res://data/runs/first_run.tres") as RunData
	assert_true(GameManager._prepare_preconfigured_run(run, PARTY))
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	for hero in GameManager.get_ordered_heroes():
		hud.update_info(hero)
		hud.build_spell_buttons(hero)
		assert_eq(hud.get("_spell_buttons").size(), 4)
		assert_eq(hud.get("_current_unit"), hero)

func test_hud_switch_disconnects_hp_and_stats_signals() -> void:
	var first := Unit.from_data(load(PARTY[0]) as UnitData)
	var second := Unit.from_data(load(PARTY[1]) as UnitData)
	var hud := (load(HUD_SCENE) as PackedScene).instantiate()
	add_child_autofree(hud)
	var callback := Callable(hud, "_on_resource_changed")
	await get_tree().process_frame
	hud.update_info(first)
	assert_true(first.hp_changed.is_connected(callback))
	assert_true(first.stats_changed.is_connected(callback))
	hud.update_info(second)
	assert_false(first.hp_changed.is_connected(callback))
	assert_false(first.stats_changed.is_connected(callback))
	assert_true(second.hp_changed.is_connected(callback))
	assert_true(second.stats_changed.is_connected(callback))
