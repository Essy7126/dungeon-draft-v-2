extends "res://tests/expedition/battle_flow_probe.gd"
## Preparation -> real battle with enemy AI -> victory receipt -> disk resume.
const Cards := preload("res://core/expedition/class_card_catalog.gd")
var checked_backend := false
var resumed := false
var directional_views: Dictionary = { }


func _ready() -> void:
	get_tree().current_scene = null
	_save_path = "user://passe_rive_s19_flow.json"
	GameManager.expedition_save_path = _save_path
	var selection := Cards.preset("thaumaturge")
	GameManager._cards_departure_selection = selection.duplicate(true)
	if not GameManager.start_expedition(
		2401,
		{ "achilles": "passe_rive" },
		false,
		true,
		"normal",
		true,
	):
		_finish(false, "Cards preparation could not start")
		return
	for frame in 3:
		await get_tree().process_frame
	if not GameManager.confirm_catabase_preparation(selection).get("success", false):
		_finish(false, "Canonical preparation could not be confirmed")
		return
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 180000:
		await get_tree().create_timer(0.08).timeout
		if not GameManager.run_active:
			_finish(false, "Hero lost the actual battle")
			return
		if GameManager.expedition.route.phase == "reward":
			var report := GameManager.get_current_combat_report()
			if (
				report == null or not report.victory or not checked_backend
				or _spell_casts.is_empty() or directional_views.is_empty()
			):
				_finish(false, "Missing real victory, casts or S19 backend")
				return
			if not GameManager.save_expedition(_save_path):
				_finish(false, "Receipt save failed")
				return
			# Resume the real disk snapshot; no synthesized victory or injected HP/AP.
			GameManager.cleanup_run_state()
			resumed = GameManager.resume_expedition(_save_path)
			for frame in 4:
				await get_tree().process_frame
			resumed = (
				resumed and GameManager.expedition.cards != null
				and GameManager.expedition.route.phase == "reward"
			)
			resumed = (
				resumed
				and GameManager.get_active_run_data().hero_visual_variants.get("achilles", "") == "passe_rive"
			)
			_finish(
				resumed,
				"Cards preparation, real AI victory, receipt and disk resume with Passe-Rive",
			)
			return
		# SceneTree.current_scene can still reference a freed scene during the
		# deferred victory transition. Resolve a live battle from the tree itself.
		var battle: Node = _live_battle(get_tree().root)
		if battle == null or not battle.get("runtime_ready_state"):
			continue
		for view: Node in battle._unit_views.values():
			var actor: Node = view.get_optional_visual()
			if actor is PasseRiveAutoSpriteView and actor.sprite_backend.cards_mode:
				var state: Dictionary = actor.sprite_backend.get_runtime_state()
				var source := str(state.get("directional_source", ""))
				if not source.is_empty():
					directional_views[source] = true
		var deployment = battle.get("_deployment")
		if deployment != null and deployment.is_active():
			deployment.on_cell_clicked(GameManager.get_current_room().hero_spawn_zone[0])
			continue
		if not battle.call("_can_accept_player_intent"):
			continue
		var hero: Unit = battle.call("get_active_unit")
		if hero == null or hero.team != 0:
			continue
		var visual: Node = battle._unit_views[hero].get_optional_visual()
		checked_backend = visual is PasseRiveAutoSpriteView and visual.sprite_backend.cards_mode
		if not _try_spell(battle, hero) and not _try_move(battle, hero):
			battle.set("_skip_end_turn_confirmation", true)
			battle.call("_on_end_turn_pressed")
			_turns += 1
	_finish(false, "Real battle timed out")


func _live_battle(parent: Node) -> Node:
	for child in parent.get_children():
		# Production rooms can attach scripts derived from battle.gd.
		if child.has_signal("runtime_ready") and child.has_method("_on_request_move_to"):
			return child
		var found := _live_battle(child)
		if found != null:
			return found
	return null


func _try_spell(battle: Node, hero: Unit) -> bool:
	var cards = GameManager.expedition.cards
	var spells: Array[Spell] = []
	for id in cards.hand:
		spells.append_array(cards.spells_for(id))
	spells.append_array(cards.weapon_spells())
	for spell in spells:
		if spell.get_scaled_damage(hero) <= 0 or hero.get_spell_availability_reason(spell) != &"":
			continue
		for enemy: Unit in battle.units:
			if not enemy.is_alive or enemy.team == hero.team or not battle.spell_caster.can_cast(
					hero,
					spell,
					enemy.grid_pos,
				):
				continue
			battle._on_spell_pressed(spell)
			battle._on_cell_clicked(enemy.grid_pos)
			if battle._spell_resolution_pending:
				var key := str(spell.get_effective_spell_id())
				_spell_casts[key] = int(_spell_casts.get(key, 0)) + 1
				return true
	return false


func _finish(success: bool, detail: String) -> void:
	var path := OS.get_environment("APPDATA").path_join("s19_flow_report.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(
		JSON.stringify(
			{
				"passed": success,
				"detail": detail,
				"casts": _spell_casts,
				"moves": _moves,
				"end_turns": _turns,
				"s19_backend": checked_backend,
				"disk_resume": resumed,
				"s20_directional_views": directional_views.keys(),
			},
			"\t",
		)
	)
	super._finish(success, detail)
