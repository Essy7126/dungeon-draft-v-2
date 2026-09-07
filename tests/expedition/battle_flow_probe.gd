extends Node
## A real battle driven through player intents. No injected victory, damage or AP.

var _spell_casts: Dictionary = {}
var _moves := 0
var _turns := 0
var _save_path := ""


func _ready() -> void:
	get_tree().current_scene = null
	_save_path = OS.get_environment("TEMP").path_join("expedition-battle-probe-%d.json" % Time.get_ticks_usec())
	GameManager.expedition_save_path = _save_path
	GameManager.set_reduced_motion_enabled(true)
	if not GameManager.start_expedition(2401):
		_finish(false, "start failed")
		return
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 150000:
		await get_tree().create_timer(0.08).timeout
		if not GameManager.run_active:
			_finish(false, "Achilles lost the real fight")
			return
		if GameManager.expedition.route.phase == "reward":
			var report := GameManager.get_current_combat_report()
			var success := report != null and report.victory and not _spell_casts.is_empty() and GameManager.expedition.build.unlocked_node_ids.is_empty()
			success = success and GameManager.purchase_expedition_technique("colere.root").get("success", false)
			success = success and GameManager.purchase_expedition_technique("briseur.learn_a").get("success", false)
			success = success and GameManager.equip_expedition_spell(&"exp_crochet", 3)
			var offered := GameManager.expedition.reward_options(GameManager.item_catalog)
			var reward: Dictionary = GameManager.claim_expedition_reward(str(offered[0].id))
			success = success and bool(reward.get("success", false)) and GameManager.expedition.route.phase == "map"
			_finish(success, "canonical opening victory, defense replaced by Crochet after victory, reward and map resumed")
			return
		var battle := get_tree().current_scene
		if battle == null or not battle.get("runtime_ready_state"):
			continue
		var deployment = battle.get("_deployment")
		if deployment != null and deployment.is_active():
			deployment.on_cell_clicked(GameManager.get_current_room().hero_spawn_zone[0])
			continue
		if not battle.call("_can_accept_player_intent"):
			continue
		var hero: Unit = battle.call("get_active_unit")
		if hero == null or hero.team != 0:
			continue
		var acted := _try_spell(battle, hero)
		if not acted:
			acted = _try_move(battle, hero)
		if not acted:
			battle.set("_skip_end_turn_confirmation", true)
			battle.call("_on_end_turn_pressed")
			_turns += 1
	_finish(false, "real battle timeout")


func _try_spell(battle: Node, hero: Unit) -> bool:
	var caster: SpellCaster = battle.get("spell_caster")
	# New control goes first when affordable, then existing attacks.
	var spells := hero.spells.duplicate()
	spells.reverse()
	for spell in spells:
		if spell.get_scaled_damage(hero) <= 0 or hero.get_spell_availability_reason(spell) != &"":
			continue
		for enemy in battle.get("units"):
			if not enemy.is_alive or enemy.team == hero.team:
				continue
			if not caster.can_cast(hero, spell, enemy.grid_pos):
				continue
			var before := hero.current_ap
			battle.call("_on_spell_pressed", spell)
			battle.call("_on_cell_clicked", enemy.grid_pos)
			if hero.current_ap < before or bool(battle.get("_spell_resolution_pending")):
				var key := str(spell.get_effective_spell_id())
				_spell_casts[key] = int(_spell_casts.get(key, 0)) + 1
				return true
	return false


func _try_move(battle: Node, hero: Unit) -> bool:
	if hero.current_mp <= 0:
		return false
	var pathfinder: Pathfinder = battle.get("pathfinder")
	var reachable: Array = pathfinder.get_reachable(hero.grid_pos, hero.current_mp, hero)
	var enemies: Array = battle.get("units").filter(func(unit: Unit): return unit.team != hero.team and unit.is_alive)
	var best: Vector2i = hero.grid_pos
	var best_score := _distance(best, enemies)
	for cell in reachable:
		var score := _distance(cell, enemies)
		if score < best_score:
			best = cell
			best_score = score
	if best == hero.grid_pos:
		return false
	battle.call("_on_move_pressed")
	battle.call("_on_cell_clicked", best)
	_moves += 1
	return true


func _distance(cell: Vector2i, enemies: Array) -> int:
	var distance := 10000
	for enemy in enemies:
		distance = mini(distance, absi(cell.x - enemy.grid_pos.x) + absi(cell.y - enemy.grid_pos.y))
	return distance


func _finish(success: bool, detail: String) -> void:
	print("EXPEDITION_REAL_BATTLE %s casts=%s moves=%d end_turns=%d detail=%s" % ["PASS" if success else "FAIL", str(_spell_casts), _moves, _turns, detail])
	for frame in range(3): await get_tree().process_frame
	var scene := get_tree().current_scene
	get_tree().current_scene = null
	if scene != null: scene.queue_free()
	for frame in range(3): await get_tree().process_frame
	GameManager.cleanup_run_state()
	if FileAccess.file_exists(_save_path): DirAccess.remove_absolute(_save_path)
	# Allow queued persistent UI destruction to run before renderer shutdown.
	for frame in range(3): await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	get_tree().quit(0 if success else 1)
