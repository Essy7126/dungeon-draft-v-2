extends Node

const ObserverScript = preload(
	"res://tests/room_transition/room_transition_full_run_observer.gd"
)


func _ready() -> void:
	var previous := GameManager.get_node_or_null("RoomTransitionValidationObserver")
	if is_instance_valid(previous):
		previous.free()
	var observer := ObserverScript.new()
	observer.name = "RoomTransitionValidationObserver"
	observer.stop_with_room_two_open = (
		"--room-transition-stop-at-room-2" in OS.get_cmdline_user_args()
	)
	GameManager.add_child(observer)
	observer.begin()
