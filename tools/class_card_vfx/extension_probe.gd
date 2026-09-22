extends "semantic_probe.gd"
## Actual casts for the expanded vocabulary; frame clock is fixed by the capture runner.
const SHOWCASE := [
	"a_reap",
	"g_bastion",
	"g_hook",
	"r_net",
	"r_scatter",
	"t_storm",
	"t_disrupt",
	"t_hourglass",
	"g_fault",
	"r_caltrop",
	"t_cataclysm",
	"a_phantom",
]
const Catalog := preload("res://vfx/class_cards/class_card_vfx_catalog.gd")
var showcase: Array = SHOWCASE.duplicate()


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/extension/"
	pair_distance = 2
	captured_frames = SHOWCASE.size() * 60


func _exercise() -> void:
	_overlay()
	var normal_zoom: Vector2 = battle.camera.zoom / 2.4
	var hero_cell: Vector2i = hero.grid_pos
	var target_cell: Vector2i = target.grid_pos
	for id in showcase:
		_move(hero, hero_cell)
		_move(target, target_cell)
		var entry := Catalog.recipe(id)
		heading.text = Cards.row(id)[2]
		caption.text = "%s · impact %.2f s" % [entry.motif, entry.duration]
		if id in ["t_hourglass", "a_stasis"]:
			target.apply_status(Cards.status("marked", "Marqué", 1), hero)
			caption.text = "Cible marquée · stase 1 activation · protection contre la stase 3 activations"
		elif id == "g_bastion":
			caption.text = "Érection du rempart · garde jusqu'à la prochaine activation du porteur"
		elif entry.has("ground_motif"):
			caption.text = "Dalles réelles · maintien pendant 2 tours de terrain"
		elif entry.effect in ["root", "disrupt"]:
			caption.text = "Impact puis maintien du signe · malus pendant 1 activation réelle"
		var cell: Vector2i = target.grid_pos
		if entry.effect == "guard":
			cell = hero.grid_pos
		elif entry.movement:
			for candidate in _central_cells():
				var distance: int = battle.grid.manhattan(hero.grid_pos, candidate)
				if (
					distance >= 1 and distance <= 4
					and battle.grid.is_walkable(candidate) and not battle.grid.has_unit(candidate)
				):
					cell = candidate
					break
		DirAccess.make_dir_recursive_absolute(output_path + id)
		_cast(id, cell)
		var frozen := _state()
		_check(
			not router.effects.is_empty() or not router.surface_holds.is_empty(),
			id + " emits confirmed presentation",
		)
		if entry.get("power", 0) == 2:
			_check(
				router.effects.any(
					func(fx):
						return not fx.persistent and fx.recipe.get("power", 0) == 2,
				),
				id + " emits the epic cast separately from any durable hold",
			)
		for frame in 60:
			var seconds := frame / 30.0
			clock_label.text = "Lecture native à 30 images/s · %.2f s · caméra ×2,4 · IA suspendue" % seconds
			_sample_all(seconds)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			if get_viewport().get_texture().get_image().save_png(
				output_path + id + "/%03d.png" % frame
			) != OK:
				_check(false, "Frame save failed: " + id)
		_check(_state() == frozen, id + " visual playback leaves HP and status turns unchanged")
		battle.camera.zoom = normal_zoom
		_sample_all(float(entry.duration) * .2)
		clock_label.text = "Caméra de combat normale · impact confirmé · IA suspendue"
		await _capture(id + "_normal")
		battle.camera.zoom = normal_zoom * 2.4
		_sample_all(2.0)
		if not router.holds.is_empty() or not router.surface_holds.is_empty():
			clock_label.text = "Maintien : temps graphique écoulé, durée de jeu encore active"
			await _capture(id + "_hold")
		if id == "g_bastion":
			hero.start_turn()
			router._process(.2)
			_check(hero.current_shield == 0, "Bastion expires on the real owner activation")
		if entry.has("ground_motif"):
			_check(_ground_order_correct(), id + " overlay follows actual cells and layer order")
			battle.terrain_effects.tick_all_effects()
			_check(not router.surface_holds.is_empty(), id + " remains after terrain round one")
			battle.terrain_effects.tick_all_effects()
			_check(router.surface_holds.is_empty(), id + " ends after terrain round two")
		# Real status clocks: witness the longer ward outliving stasis before cleanup.
		for turn in 3:
			target.tick_statuses()
			if id in ["t_hourglass", "a_stasis"] and turn == 0:
				_check(
					not target.has_status(&"ecosystem_stasis")
					and target.has_status(&"ecosystem_stasis_ward"),
					"Stasis ends before its three-activation ward",
				)
		for state in target.get_active_statuses().duplicate():
			target.remove_status(state.data.get_effective_status_id())
		hero.clear_shield()
		router._process(.2)
		_check(
			router.holds.is_empty() and router.surface_holds.is_empty(),
			id + " clears all durable presentation on actual expiry",
		)
		for fx in router.effects + router.ground_effects + router.echoes:
			if is_instance_valid(fx):
				fx.manual = false
		await get_tree().create_timer(.8).timeout
		clock_label.text = "Expiration réelle · maintien retiré · fin de la rémanence"
		await _capture(id + "_expired")
		router.clear()
		router.bind_terrain(battle.terrain_effects)
	_finish()
