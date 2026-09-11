extends GutTest
const Routes := preload("res://hub/seuil_crossroads/seuil_route_choices.gd")
const Fixture := preload("res://tools/run_explorer/route_explorer_fixture.gd")


func test_legacy_routes_keep_their_existing_exit_screen() -> void:
	for revision in [2, 3]:
		var session := ExpeditionSession.new()
		session.route.initialize(2401, revision)
		assert_true(session.route.choose_node("d01_0"))
		assert_true(session.route.mark_combat_won())
		assert_false(Routes.active(session))
		assert_true(Routes.destination(session, "boat").is_empty())


class Manager extends Fixture.FixtureManager:
	var requested := ""


	func _request_scene_change(
		path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		requested = path


func test_victory_rewards_resume_and_three_physical_routes() -> void:
	for seed_value in [2401, 1]:
		var ids := { }
		for landmark in ["boat", "gate", "well"]:
			var folder := "res://artifacts/dev/seuil-unit-%d-%s/" % [
				Time.get_ticks_usec(),
				landmark,
			]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			var snapshot := Fixture.prepare(self, seed_value, "d01_0", folder + "fixture.json")
			var manager := Manager.new()
			manager.expedition_save_path = folder + "checkpoint.json"
			add_child(manager)
			assert_true(manager.restore_expedition_snapshot(snapshot))
			assert_false(Routes.active(manager.expedition))
			assert_true(Routes.destination(manager.expedition, landmark).is_empty())
			manager.begin_combat_report()
			manager.on_battle_won()
			assert_true(Routes.active(manager.expedition))
			assert_eq(manager.requested, "res://hub/seuil_crossroads/SeuilCrossroads.tscn")
			assert_false(Routes.can_depart(manager.expedition))
			var awarded := manager.expedition.gold
			manager.on_battle_won()
			assert_eq(manager.expedition.gold, awarded)
			var won := manager.get_expedition_snapshot()
			assert_true(manager.restore_expedition_snapshot(won))
			assert_eq(
				manager.get_expedition_destination_scene(),
				"res://hub/seuil_crossroads/SeuilCrossroads.tscn",
			)
			while manager.expedition.character.champion_progression.unspent_attribute_points > 0:
				assert_true(manager.spend_champion_attribute(&"achilles", &"vitality"))
			assert_true(manager.claim_expedition_reward("supplies").success)
			assert_false(manager.claim_expedition_reward("supplies").success)
			assert_true(Routes.can_depart(manager.expedition))
			var destination := Routes.destination(manager.expedition, landmark)
			assert_eq(destination.title, Routes.DESTINATIONS[landmark])
			ids[destination.id] = true
			assert_true(manager.choose_expedition_node(destination.id))
			assert_eq(manager.expedition.route.phase, "combat")
			assert_false(Routes.active(manager.expedition))
			manager.cleanup_run_state()
			remove_child(manager)
			manager.free()
		assert_eq(ids.size(), 3)
