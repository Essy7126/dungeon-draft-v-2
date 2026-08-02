extends Node

const INTRO_PATH := "res://cinematics/intro/intro_cinematic.tscn"
const ROOM_TRANSITION_PATH := "res://ui/Transitionsalle.tscn"

var _failures: Array[String] = []
var _run_scene_requests: Array[String] = []


func start(hub: Node) -> void:
	print("START_HUB_INTRO_FLOW_VERIFY: hub")
	GameManager.cleanup_run_state()
	var scene_callback := func(path: String): _run_scene_requests.append(path)
	GameManager.scene_change_requested.connect(scene_callback)
	var controller: StartHubController = hub.get_node("HubController")
	controller.movement.movement_speed = 2400.0
	controller.transition_fade_duration = 0.0
	var panel_ref: WeakRef = weakref(controller.archivist_panel)
	var trade_ref: WeakRef = weakref(controller.trade_panel)
	_check(not GameManager.run_active, "Une run est active a l'entree du hub.")
	# Le verifier peut etre attache avant le _ready complet de la scene. Le
	# NavigationServer publie la region lors d'un tick physique ulterieur :
	# attendre un chemin reel evite de confondre cette latence avec un refus.
	var interaction_intent: InteractionIntent = null
	for _frame in range(60):
		var approaches := controller.archivist.get_approach_world_positions()
		if approaches.size() == 4 \
			and controller.navigation_region.navigation_polygon != null \
			and not controller.navigation_region.get_world_path(
				controller.player.global_position, approaches[0]
			).is_empty():
			interaction_intent = controller.request_interaction(controller.archivist)
			if interaction_intent != null:
				break
		await get_tree().physics_frame
	_check(interaction_intent != null, "Interaction refusee.")
	for _frame in range(160):
		await get_tree().process_frame
		if controller.archivist_panel.visible:
			break
	_check(controller.archivist_panel.visible, "Le panneau Archiviste ne s'ouvre pas.")
	if not controller.archivist_panel.visible:
		_finish(scene_callback)
		return
	controller.archivist_panel.get_node("%RunButton").pressed.emit()
	controller.archivist_panel.get_node("%RunButton").pressed.emit()

	var intro: IntroCinematic = null
	for _frame in range(30):
		await get_tree().process_frame
		if get_tree().current_scene is IntroCinematic:
			intro = get_tree().current_scene as IntroCinematic
			break
	_check(intro != null, "Commencer la run n'ouvre pas la scene d'introduction.")
	print("START_HUB_INTRO_FLOW_VERIFY: intro=%s" % (intro != null))
	_check(not GameManager.run_active, "La run demarre avant la fin de l'introduction.")
	_check(panel_ref.get_ref() == null, "ArchivistPanel survit au changement de scene.")
	_check(trade_ref.get_ref() == null, "TradePanel survit au changement de scene.")
	if intro == null:
		_finish(scene_callback)
		return
	_check(intro.scene_file_path == INTRO_PATH, "Mauvaise scene d'introduction.")
	intro.exit_fade_duration = 0.0
	intro.music_fade_out_duration = 0.0
	var music_player_ref: WeakRef = weakref(intro.music_player)
	_check(intro.music_player.playing, "La musique d'introduction ne joue pas.")
	intro.request_skip()
	intro.finish_cinematic()
	for _frame in range(30):
		await get_tree().process_frame
		if get_tree().current_scene != null \
			and get_tree().current_scene.scene_file_path == ROOM_TRANSITION_PATH:
			break
	_check(GameManager.run_active, "Le skip ne demarre pas la run.")
	_check(music_player_ref.get_ref() == null, "MusicPlayer survit a la cinematique.")
	print("START_HUB_INTRO_FLOW_VERIFY: run=%s" % GameManager.run_active)
	_check(GameManager.current_room_index == 0, "La premiere salle n'est pas selectionnee.")
	_check(_run_scene_requests == [ROOM_TRANSITION_PATH], "La run a ete lancee plusieurs fois.")
	_check(GameManager.get_ordered_heroes().map(
		func(hero): return hero.unit_name
	) == ["Elfe", "Mage", "Guerrier"], "Composition de depart incorrecte.")
	_check(GameManager.rooms.size() == 4, "first_run.tres ne contient pas quatre salles.")
	_finish(scene_callback)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(scene_callback: Callable) -> void:
	if GameManager.scene_change_requested.is_connected(scene_callback):
		GameManager.scene_change_requested.disconnect(scene_callback)
	GameManager.cleanup_run_state()
	if _failures.is_empty():
		print("START_HUB_INTRO_FLOW_VERIFY: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("START_HUB_INTRO_FLOW_VERIFY: %s" % failure)
	print("START_HUB_INTRO_FLOW_VERIFY: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
