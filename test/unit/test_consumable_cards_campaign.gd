extends GutTest
## Boundary fixture, not a balance bot: enemies have 1 HP so all twenty route
## depths and receipts can be exercised without coupling this test to a build.
const Run := preload("res://core/expedition/consumable_cards_run.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
var runtime
var path := ""


func after_each() -> void:
	if runtime != null:
		runtime.dispose()
	if not path.is_empty():
		ExpeditionSaveService.remove_snapshot(path)


func apply(command: Dictionary) -> bool:
	var result: Dictionary = runtime.act(command)
	assert_true(result.success, JSON.stringify(command) + " : " + JSON.stringify(result))
	if not result.success:
		return false
	var next := Run.new()
	assert_true(next.resume(path), next.last_error)
	assert_eq(
		JSON.stringify(next.checkpoint.state),
		JSON.stringify(JSON.parse_string(JSON.stringify(runtime.checkpoint.state))),
	)
	runtime.dispose()
	runtime = next
	return true


func test_all_twenty_depths_transactions_and_completion_resume() -> void:
	path = "user://cc2_campaign_%d.json" % Time.get_ticks_usec()
	runtime = Run.new()
	assert_true(runtime.create(Catalog.preset("gardien"), 980, path))
	assert_true(apply({ "kind": "depart" }))
	var encounters := 0
	var halts := 0
	var shops := 0
	for _boundary in 40:
		if runtime.checkpoint.state.phase == "complete":
			break
		if runtime.checkpoint.state.phase == "combat":
			encounters += 1
			for enemy in runtime.battle.enemies:
				enemy.current_hp = 1
			runtime.battle.hero.current_hp = runtime.battle.hero.max_hp.get_int()
			runtime.checkpoint.state.combat = runtime.battle.snapshot()
			assert_true(runtime.checkpoint.retry())
			for _action in 130:
				if runtime.checkpoint.state.phase != "combat":
					break
				var battle = runtime.battle
				if battle.phase != "hero":
					if not apply({ "kind": "next_actor" }):
						return
					continue
				var hero: Unit = battle.hero
				var acted := false
				if runtime.cards.can_use_family("fallback_strike") and hero.current_ap > 0:
					var best: Array = []
					for enemy in battle.enemies:
						if not enemy.is_alive:
							continue
						if battle.grid.manhattan(hero.grid_pos, enemy.grid_pos) == 1:
							if not apply(
								{
									"kind": "fallback",
									"family": "fallback_strike",
									"cell": [enemy.grid_pos.x, enemy.grid_pos.y],
								}
							):
								return
							acted = true
							break
						for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
							var route: Array = battle.pathfinder.find_path(
								hero.grid_pos,
								enemy.grid_pos + offset,
								hero,
							)
							if route.size() > 1 and (best.is_empty() or route.size() < best.size()):
								best = route
					if not acted and hero.current_mp > 0 and best.size() > 1:
						var destination: Vector2i = best[mini(hero.current_mp, best.size() - 1)]
						if not apply({ "kind": "move", "cell": [destination.x, destination.y] }):
							return
						acted = true
				if not acted:
					for uid in runtime.cards.hand.duplicate():
						var family: String = runtime.cards.copy_for(uid).family
						var spell: Spell = runtime.cards.family_spell(family)
						if not spell.deals_damage():
							continue
						for enemy in battle.enemies:
							if enemy.is_alive and battle.caster.get_cast_failure_reason(
									hero,
									spell,
									enemy.grid_pos,
								) == &"":
								if not apply(
									{
										"kind": "card",
										"uid": uid,
										"cell": [enemy.grid_pos.x, enemy.grid_pos.y],
									}
								):
									return
								acted = true
								break
						if acted:
							break
				if not acted:
					if not apply({ "kind": "end_turn" }):
						return
			assert_ne(runtime.checkpoint.state.phase, "combat", "fight must terminate")
			if runtime.checkpoint.state.phase == "complete":
				break
		else:
			if runtime.checkpoint.state.phase == "halt":
				halts += 1
				if not str(runtime.checkpoint.state.route.get("merchant", "")).is_empty():
					shops += 1
					if not apply(
						{ "kind": "purchase", "purchase": { "kind": "bag", "id": "campaign_bag" } }
					):
						return
			if runtime.cards.level >= 4 and runtime.cards.specialization.is_empty():
				if not apply({ "kind": "specialization", "id": "bastion" }):
					return
			if runtime.cards.points() > 0:
				for family in ["n03", "g01", "g03"]:
					if family not in runtime.cards.upgraded_ids:
						if not apply({ "kind": "upgrade", "family": family }):
							return
						break
			if not apply({ "kind": "continue" }):
				return
	assert_eq(encounters, 12)
	assert_eq(halts, 8)
	assert_eq(shops, 5)
	assert_eq(runtime.cards.level, 12)
	assert_eq(runtime.checkpoint.state.phase, "complete")
	assert_eq(runtime.checkpoint.state.route.outcome, "victory")
	assert_eq(runtime.cards.upgraded_ids.size(), 3)
	assert_false(runtime.act({ "kind": "continue" }).success)
	assert_false(runtime.act({
			"kind": "purchase",
			"purchase": { "kind": "bag", "id": "after_end" },
		}).success)
