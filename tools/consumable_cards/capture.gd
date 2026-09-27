extends Node
const Screen := preload("res://ui/expedition/consumable_cards_screen.gd")
const Run := preload("res://core/expedition/consumable_cards_run.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const ROOT := "res://artifacts/consumable_cards_v2"
var screen
var runtime


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	GameManager.cleanup_run_state()
	screen = Screen.new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await capture("01_departure")
	runtime = Run.new()
	var selection := Catalog.preset("thaumaturge")
	selection["visual_variant"] = { "achilles": "passe_rive" }
	if not runtime.create(selection, 631, "user://cc2_capture_only.json"):
		get_tree().quit(1)
		return
	screen.run = runtime
	screen._render()
	await capture("02_preparation")
	if not runtime.act({ "kind": "depart" }).success:
		get_tree().quit(1)
		return
	screen._render()
	await capture("03_combat")
	screen._selected = { "kind": "card", "uid": runtime.cards.hand[0] }
	screen._render()
	await capture("04_targeting")
	screen._cell_hovered(Vector2i(3, 1))
	await capture("05_preview")
	var dossier: AcceptDialog = screen._combat_dossier()
	await capture("06_dossier", dossier)
	dossier.free()
	# Authored UI fixture, not a victory or balance simulation.
	runtime.cards.finish_combat()
	runtime.cards.gold = 200
	Run.Economy.market(runtime.cards, "capture_shop", 2)
	runtime.checkpoint.state.cards = runtime.cards.snapshot()
	runtime.checkpoint.state.combat.clear()
	runtime.checkpoint.state.phase = "halt"
	runtime.checkpoint.state.route = {
		"depth": 3,
		"encounter": 2,
		"hero_hp": 90,
		"hero_max_hp": 110,
		"merchant": "capture_shop",
	}
	runtime._publish()
	screen._tab = "Marchand"
	screen._render()
	await capture("07_market")
	print(JSON.stringify({ "success": true, "captures": 7, "directory": ROOT }))
	remove_child(screen)
	screen.free()
	GameManager.cleanup_run_state()
	ExpeditionSaveService.remove_snapshot("user://cc2_capture_only.json")
	get_tree().quit()


func capture(label: String, viewport: Viewport = null) -> void:
	if "--review-720" in OS.get_cmdline_user_args(): label += "_720"
	for _frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := (get_viewport() if viewport == null else viewport).get_texture().get_image()
	var error := image.save_png(ROOT.path_join(label + ".png"))
	print("CC2_CAPTURE %s %s" % [label, error])
