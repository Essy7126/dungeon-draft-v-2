extends RefCounted

const BASE := "res://tools/registered_terrain_validation/"
const GEOMETRY := preload(BASE + "geometry_checks.gd")
const SUPPORT := preload(BASE + "terrain_support_checks.gd")
const MATERIAL := preload(BASE + "terrain_material_checks.gd")
const BAND := preload(BASE + "combat_band_checks.gd")
const FRAMING := preload(BASE + "framing_proportion_checks.gd")
const INTERACTIONS := preload(BASE + "interaction_checks.gd")


static func run(battle: Node, capture_path: String, requested: Vector2i) -> Dictionary:
	var arena := battle.get("room_data") as ArenaDefinition
	var grid := battle.get("grid") as GridData
	var view := battle.get("grid_view") as Node2D
	var assembly: Dictionary = battle.get("arena_assembly")
	var renderer := assembly.get("renderer") as ArenaTerrainVisualRenderer
	var checks := {
		"geometry": GEOMETRY.run(battle, arena, grid, view, renderer),
		"support": SUPPORT.run(battle, arena, view, renderer),
		"materials": MATERIAL.run(battle, arena, renderer),
		"band": BAND.run(battle, arena, renderer),
		"framing_before": await FRAMING.run(battle),
	}
	var heroes: Array = battle.get("units").filter(
		func(unit: Unit) -> bool:
			return unit.team == 0,
	)
	var probe := INTERACTIONS.new()
	battle.add_child(probe)
	checks["interactions"] = await probe.run(
		battle,
		heroes[0] as Unit,
		grid,
		battle.get("pathfinder") as Pathfinder,
		view,
		renderer,
	)
	probe.queue_free()
	# Interaction probes can leave transient hover inspection over the playfield.
	var inspection := battle.get("inspect_panel") as CanvasLayer
	if inspection != null:
		inspection.hide()
	view.set("_hovered_cell", Vector2i(-999, -999))
	view.queue_redraw()
	await battle.get_tree().process_frame
	checks["framing_after"] = await FRAMING.run(battle)
	await RenderingServer.frame_post_draw
	var shot := battle.get_viewport().get_texture().get_image()
	checks["resolution"] = {
		"ok": shot.get_size() == requested,
		"actual": [shot.get_width(), shot.get_height()],
		"expected": [requested.x, requested.y],
	}
	checks["after_capture"] = {
		"ok": shot.save_png(capture_path.get_basename() + "_after_move_guard.png") == OK
	}
	var errors: Array[String] = []
	for name: String in checks:
		if not checks[name].get("ok", false):
			errors.append(name + ": " + str(checks[name].get("errors", [])))
	checks["ok"] = errors.is_empty()
	checks["errors"] = errors
	return checks
