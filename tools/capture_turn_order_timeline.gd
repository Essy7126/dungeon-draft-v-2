extends Node

const OUTPUT_DIR := "res://artifacts/first_run_v2/captures/turn_order"
const RUN := preload("res://data/runs/first_run.tres")
const HERO_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(RUN, HERO_PATHS):
		push_error("Initialisation de la capture de timeline impossible.")
		get_tree().quit(1)
		return
	GameManager.current_room_index = 0
	var battle = RUN.rooms[0].battle_scene.instantiate()
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(battle)
	for _frame in 5:
		await get_tree().process_frame
	var timeline = battle.turn_order_timeline
	var units: Array = battle.units.duplicate()
	units.append_array(GameManager.get_ordered_heroes())
	var queue := TurnQueue.new()
	queue.setup(units)
	timeline.bind_queue(queue)
	queue.start()
	for _frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _capture("initial_order.png")
	queue.advance()
	await get_tree().create_timer(timeline.scroll_duration * 0.5).timeout
	await RenderingServer.frame_post_draw
	await _capture("rotation_midway.png")
	await get_tree().create_timer(timeline.scroll_duration).timeout
	var active_unit = queue.get_current_unit()
	for card in timeline.cards_layer.get_children():
		if card.get("unit") == active_unit:
			card.pressed.emit()
			break
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _capture("rotated_and_selected.png")
	print("TURN_ORDER_CAPTURE=PASS")
	battle.queue_free()
	GameManager.cleanup_run_state()
	get_tree().quit()


func _capture(file_name: String) -> void:
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(path)
	)
	if error != OK:
		push_error("Capture de timeline impossible : %s" % error_string(error))
