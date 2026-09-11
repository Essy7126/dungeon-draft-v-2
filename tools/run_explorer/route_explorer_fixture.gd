extends RefCounted
## Valid lab checkpoint built along a real path. Never invoked by the game.
const Catalog = preload("res://tools/run_explorer/route_explorer_catalog.gd")


class FixtureManager extends "res://core/game_manager.gd":
	func start_next_battle() -> void:
		_room_outcome_resolved = false


	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


static func prepare(host: Node, seed_value: int, target: String, checkpoint: String) -> Dictionary:
	var path := Catalog.path_to(ExpeditionRouteCatalog.create_nodes(seed_value), target)
	if path.is_empty() or not checkpoint.begins_with("res://artifacts/dev/"):
		return { }
	var fixture := FixtureManager.new()
	fixture.expedition_save_path = checkpoint
	host.add_child(fixture)
	var valid := fixture.start_expedition(seed_value)
	for id in path:
		if not valid:
			break
		if id != "d01_0":
			if id.ends_with("_secret"):
				fixture.expedition.route.reveal_hidden_node(id)
			valid = fixture.choose_expedition_node(id)
		if not valid:
			break
		if id != target and fixture.expedition.route.phase == "combat":
			fixture.begin_combat_report()
			fixture.on_battle_won()
		var progression := fixture.expedition.character.champion_progression
		while valid and progression.unspent_attribute_points > 0:
			valid = fixture.spend_champion_attribute(&"achilles", &"vitality")
		if (
			fixture.expedition.is_editable()
			and int(fixture.expedition.route.get_current_node().depth)
			== ExpeditionBuildState.CAPACITY_DEPTH
			and fixture.expedition.build.depth_eight_choice.is_empty()
		):
			valid = valid and bool(fixture.choose_expedition_capacity("slot").get("success", false))
		if id != target:
			var choices := fixture.expedition.reward_options(fixture.item_catalog)
			valid = valid and not choices.is_empty()
			if valid:
				valid = bool(fixture.claim_expedition_reward(str(choices.back().id)).get(
						"success",
						false,
					))
	var result := fixture.get_expedition_snapshot() if valid else { }
	fixture.cleanup_run_state()
	host.remove_child(fixture)
	fixture.free()
	return result
