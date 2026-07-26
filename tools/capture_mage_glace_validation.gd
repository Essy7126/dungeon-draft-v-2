extends Node

## Validation visuelle reproductible dans la vraie premiere salle.
## Lancer avec le renderer normal (sans --headless) :
##   Godot_v4.7.1-stable_win64_console.exe --path <projet> \
##     res://tools/CaptureMageGlaceValidation.tscn

const PARTY_SCREEN := preload("res://ui/party/PartyPresentationScreen.tscn")
const RUN_PATH := "res://data/runs/fixed_trio_prototype_run.tres"
const PARTY := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://characters/mage_glace/mage_glace.tres",
]
const DEPLOY_CELLS := [Vector2i(9, 7), Vector2i(8, 7), Vector2i(9, 6)]
const MOVE_TARGET := Vector2i(8, 6)
const CAPTURE_ROOT := "user://mage_glace_artifacts"


func _ready() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	DisplayServer.window_set_size(Vector2i(1200, 896))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_ROOT))
	await _capture_party_screen()

	GameManager.cleanup_run_state()
	var run := load(RUN_PATH) as RunData
	if not GameManager._prepare_preconfigured_run(run, PARTY):
		push_error("Capture Mage glace : construction du trio impossible.")
		get_tree().quit(1)
		return
	GameManager.current_room_index = 0
	var room := GameManager.get_current_room()
	var battle = room.battle_scene.instantiate()
	get_tree().root.add_child(battle)
	await _wait_frames(8)

	if battle._deployment == null or not battle._deployment.is_active():
		push_error("Capture Mage glace : deploiement reel indisponible.")
		get_tree().quit(1)
		return
	for cell in DEPLOY_CELLS:
		battle._deployment.on_cell_clicked(cell)
		await _wait_frames(2)
	await _wait_frames(8)

	var heroes: Array[Unit] = GameManager.get_ordered_heroes()
	var mage_glace := heroes[2]
	var unit_view = battle._unit_views.get(mage_glace)
	if not is_instance_valid(unit_view):
		push_error("Capture Mage glace : UnitView du troisieme heros absente.")
		get_tree().quit(1)
		return
	var visual := unit_view.get_optional_visual() as MageGlaceUnitView2D
	if visual == null:
		push_error("Capture Mage glace : vue 2D optionnelle absente.")
		get_tree().quit(1)
		return

	await get_tree().create_timer(0.35).timeout
	await _capture("01_idle_first_room.png")

	var old_cell: Vector2i = mage_glace.grid_pos
	battle.grid.move_unit(old_cell, MOVE_TARGET)
	mage_glace.grid_pos = MOVE_TARGET
	var target_position = battle.grid_cell_to_parent_local(
		MOVE_TARGET,
		unit_view.get_parent()
	)
	var movement_tween := battle.create_tween()
	movement_tween.tween_property(unit_view, "position", target_position, 0.58)
	await get_tree().create_timer(0.24).timeout
	await _capture("02_walk_first_room.png")
	await movement_tween.finished
	await get_tree().create_timer(0.12).timeout

	var spell := mage_glace.spells[0] as Spell
	var cast_target := Vector2i(2, 2)
	var visual_ready: bool = await unit_view.prepare_spell_visual(cast_target, spell)
	if not visual_ready:
		push_error("Capture Mage glace : protocole cast_release non termine.")
		get_tree().quit(1)
		return
	VFXManager.play_spell_vfx(mage_glace, spell, cast_target)
	await get_tree().create_timer(0.055).timeout
	await _capture("03_cast_first_room.png")

	await get_tree().create_timer(0.72).timeout
	var attacker: Unit = battle.units.filter(func(unit): return unit.team == 1)[0]
	mage_glace.take_damage(
		12,
		attacker,
		Spell.DamageType.MAGICAL,
		Spell.Element.ICE,
		{"cannot_be_dodged": true},
	)
	await get_tree().create_timer(0.115).timeout
	await _capture("04_hit_first_room.png")

	await get_tree().create_timer(0.42).timeout
	mage_glace.take_damage(
		9999,
		attacker,
		Spell.DamageType.MAGICAL,
		Spell.Element.ICE,
		{"cannot_be_dodged": true},
	)
	await get_tree().create_timer(0.77).timeout
	await _capture("05_death_first_room.png")

	print("MAGE_GLACE_CAPTURE_DIR=", ProjectSettings.globalize_path(CAPTURE_ROOT))
	print("MAGE_GLACE_VISUAL_SCALE=", visual.animated_sprite.scale)
	print("MAGE_GLACE_CAST_ORIGIN=", visual.get_default_cast_effect_origin())
	print("MAGE_GLACE_POPUP_ANCHOR=", visual.get_popup_anchor())
	await get_tree().create_timer(0.35).timeout
	VFXManager.register_battle_view(null)
	battle.queue_free()
	await _wait_frames(4)
	GameManager.cleanup_run_state()
	await _wait_frames(4)
	get_tree().quit()


func _capture_party_screen() -> void:
	var party_screen := PARTY_SCREEN.instantiate()
	get_tree().root.add_child(party_screen)
	await _wait_frames(8)
	await _capture("00_party_portrait.png")
	get_tree().root.remove_child(party_screen)
	party_screen.free()
	await _wait_frames(2)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := CAPTURE_ROOT.path_join(file_name)
	var error := image.save_png(path)
	if error != OK:
		push_error("Capture impossible %s (erreur %d)." % [path, error])
	else:
		print("CAPTURE=", ProjectSettings.globalize_path(path))


func _wait_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
